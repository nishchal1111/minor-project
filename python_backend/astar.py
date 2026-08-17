from flask import Flask, request, jsonify
import networkx as nx
import osmnx as ox
from math import radians, sin, cos, sqrt, atan2
from fetch_locations import get_service_locations
from functools import lru_cache
import traceback
import os
from shapely.geometry import Point
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Configure osmnx settings
ox.settings.use_cache = True
ox.settings.log_console = True

# Cache the road network for Kathmandu at startup
CACHE_FILE = "kathmandu_road_network.graphml"
print("Initializing road network...")
if os.path.exists(CACHE_FILE):
    print("Loading cached road network...")
    G_unprojected = ox.load_graphml(CACHE_FILE)
else:
    print("Fetching road network for Kathmandu...")
    G_unprojected = ox.graph_from_place("Kathmandu, Nepal", network_type="drive")
    print(f"Saving road network to {CACHE_FILE}...")
    ox.save_graphml(G_unprojected, CACHE_FILE)

# Project the graph to UTM
G = ox.project_graph(G_unprojected, to_crs="EPSG:32645")
print(f"Using cached and projected road network with {G.number_of_nodes()} nodes and {G.number_of_edges()} edges")

# Check graph connectivity
print(f"Graph is strongly connected: {nx.is_strongly_connected(G)}")
print(f"Graph is weakly connected: {nx.is_weakly_connected(G)}")
largest_component = max(nx.strongly_connected_components(G), key=len)
print(f"Number of nodes in largest strongly connected component: {len(largest_component)}")
if len(largest_component) < G.number_of_nodes():
    print("Graph is not fully connected, using largest component...")
    G_sub = G.subgraph(largest_component).copy()
    print(f"Using subgraph with {G_sub.number_of_nodes()} nodes and {G_sub.number_of_edges()} edges")
else:
    G_sub = G

@lru_cache(maxsize=None)
def haversine_distance(coord1, coord2):
    R = 6371  # Earth radius in km
    lat1, lon1 = radians(coord1[0]), radians(coord1[1])
    lat2, lon2 = radians(coord2[0]), radians(coord2[1])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c  # Distance in km

@app.route("/shortest-path", methods=["POST"])
def shortest_path():
    try:
        data = request.json
        user_location = (data["latitude"], data["longitude"])
        service_type = data.get("service_type", "ambulance").lower()
        print(f"Received request: lat={user_location[0]}, lon={user_location[1]}, service_type={service_type}")

        # Validate user location
        if not (-90 <= user_location[0] <= 90) or not (-180 <= user_location[1] <= 180):
            return jsonify({"error": f"Invalid user coordinates: {user_location}"}), 400

        # Step 1: Fetch nearby service locations
        print("Fetching service locations...")
        try:
            services = get_service_locations(data["latitude"], data["longitude"], service_type, radius=20000)
        except Exception as e:
            print(f"Error fetching service locations: {str(e)}")
            return jsonify({"error": f"Failed to fetch {service_type} locations: {str(e)}"}), 500

        if not services:
            print(f"No {service_type} locations found nearby")
            return jsonify({"error": f"No {service_type}s found nearby"}), 404

        print(f"Found {len(services)} {service_type} locations: {services}")
        # nearest_service = min(services, key=lambda x: haversine_distance(user_location, x)) if services and len(services) > 1 else services[0]
        if services and len(services) > 1:
    # Find the nearest service using haversine distance
            nearest_service = min(services, key=lambda x: haversine_distance(user_location, x[:2]))
        elif services:  # Handle case where there's only one service
            nearest_service = services[0]
        else:
    # Handle case where no services are found
            nearest_service = None

        if nearest_service:
    # Safely extract latitude and longitude
            nearest_service_latlon = nearest_service[:2] if len(nearest_service) >= 2 else (None, None)
    # Safely extract the provider name
            nearest_service_name = nearest_service[2] if len(nearest_service) > 2 else "Unknown"
            print(f"Nearest service location: {nearest_service}")
        else:
            print("No services found nearby.")
        print(f"Nearest service location: {nearest_service}")
        print(f"Distance between user and service: {haversine_distance(user_location, nearest_service)} km")

        # For non-emergency services, just return the location (no path needed)
        if service_type in ["sewage", "garbage", "illegalparking"]:
            return jsonify({"nearest_ambulance": nearest_service})

        # Validate nearest service location
        if not (-90 <= nearest_service[0] <= 90) or not (-180 <= nearest_service[1] <= 180):
            return jsonify({"error": f"Invalid service coordinates: {nearest_service}"}), 400

        # Step 2: Use the road network (using the largest connected component)
        print(f"Using road network with {G_sub.number_of_nodes()} nodes and {G_sub.number_of_edges()} edges")

        # Step 3: Find the nearest nodes in the road network for the user and the service
        print("Finding nearest nodes...")
        try:
            # Project the user and service locations to UTM for nearest node search
            user_point, _ = ox.projection.project_geometry(Point(user_location[1], user_location[0]), to_crs="EPSG:32645")
            service_point, _ = ox.projection.project_geometry(Point(nearest_service[1], nearest_service[0]), to_crs="EPSG:32645")

            # Find nearest nodes using UTM coordinates
            user_node = ox.nearest_nodes(G_sub, user_point.x, user_point.y, return_dist=True)
            service_node = ox.nearest_nodes(G_sub, service_point.x, service_point.y, return_dist=True)
            print(f"User node: {user_node[0]}, Distance: {user_node[1]} meters")
            print(f"Service node: {service_node[0]}, Distance: {service_node[1]} meters")
            print(f"User node coords: ({G_sub.nodes[user_node[0]]['y']}, {G_sub.nodes[user_node[0]]['x']})")
            print(f"Service node coords: ({G_sub.nodes[service_node[0]]['y']}, {G_sub.nodes[service_node[0]]['x']})")
            user_node = user_node[0]
            service_node = service_node[0]
        except Exception as e:
            print(f"Error finding nearest nodes: {str(e)}")
            return jsonify({"error": f"Failed to find nearest nodes: {str(e)}"}), 500

        # Step 4: Use A* to find the shortest path along the road network
        print("Computing A* path...")
        try:
            def heuristic(node1, node2):
                # Use Euclidean distance in UTM coordinates for the heuristic
                coord1 = (G_sub.nodes[node1]['x'], G_sub.nodes[node1]['y'])
                coord2 = (G_sub.nodes[node2]['x'], G_sub.nodes[node2]['y'])
                return sqrt((coord1[0] - coord2[0])**2 + (coord1[1] - coord2[1])**2)

            route = nx.astar_path(G_sub, user_node, service_node, heuristic=heuristic, weight="length")
            print(f"Found path with {len(route)} nodes: {route[:5]}...")  # Log first 5 nodes

            # Convert the route back to lat/lon coordinates for the frontend
            path_coords = []
            for node in route:
                point = ox.projection.project_geometry(
                    Point(G_sub.nodes[node]['x'], G_sub.nodes[node]['y']),
                    crs="EPSG:32645",
                    to_latlong=True
                )
                # Ensure point is a shapely.geometry.Point (not a tuple)
                if isinstance(point, tuple):
                    point = point[0]  # Extract the Point object if a tuple is returned
                lon, lat = point.x, point.y
                path_coords.append((lat, lon))
            print(f"Path coordinates (first 5): {path_coords[:5]}...")
            print(f"Path coordinates (last 5): {path_coords[-5:]}...")
        except nx.NetworkXNoPath:
            print(f"No path found between user and {service_type}")
            print("Returning straight line path as fallback...")
            path_coords = [user_location, nearest_service]
        except Exception as e:
            print(f"Error computing A* path: {str(e)}")
            return jsonify({"error": f"Failed to compute path: {str(e)}"}), 500

        # Step 5: Return the path and nearest service location
        print("Returning path and nearest service...")
        return jsonify({
            "path": path_coords,
            "nearest_ambulance": nearest_service
        })

    except Exception as e:
        print(f"Unexpected error in shortest_path: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": f"Internal server error: {str(e)}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)




