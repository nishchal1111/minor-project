# import firebase_admin
# from firebase_admin import credentials
# from firebase_admin import firestore
# import requests
# import math

# # Initialize Firebase Admin SDK
# cred = credentials.Certificate('hello-d38dd-firebase-adminsdk-fbsvc-d114f4cf19.json')
# firebase_admin.initialize_app(cred)

# # Get Firestore client
# db = firestore.client()

# # Overpass API endpoint
# OVERPASS_URL = "http://overpass-api.de/api/interpreter"

# # Hardcoded KMC Head Office for sewage, garbage, and illegal parking
# KMC_HEAD_OFFICE = {
#     "name": "Kathmandu Metropolitan City Office",
#     "type": "kmc",  # Covers sewage, garbage, illegal parking
#     "latitude": 27.7041,
#     "longitude": 85.3141
# }

# # Function to calculate bounding box from a center point and radius (in kilometers)
# def calculate_bounding_box(lat, lon, radius_km):
#     # Earth's radius in kilometers
#     earth_radius = 6371.0

#     # Convert radius from kilometers to degrees
#     lat_delta = (radius_km / earth_radius) * (180.0 / math.pi)
#     lon_delta = (radius_km / earth_radius) * (180.0 / math.pi) / math.cos(math.radians(lat))

#     # Calculate the bounding box coordinates
#     south = lat - lat_delta
#     north = lat + lat_delta
#     west = lon - lon_delta
#     east = lon + lon_delta

#     return south, west, north, east

# # Define the Overpass QL query for emergency services based on user location
# def get_overpass_query(user_lat, user_lon, radius_km):
#     south, west, north, east = calculate_bounding_box(user_lat, user_lon, radius_km)
#     bbox = f"{south},{west},{north},{east}"
    
#     query = f"""
#     [out:json];
#     (
#       // Hospitals with ambulances
#       node["amenity"="hospital"]["emergency"="ambulance"]({bbox});
#       node["amenity"="hospital"]["ambulance"="yes"]({bbox});
#       way["amenity"="hospital"]["emergency"="ambulance"]({bbox});
#       way["amenity"="hospital"]["ambulance"="yes"]({bbox});
      
#       // Police stations
#       node["amenity"="police"]({bbox});
#       way["amenity"="police"]({bbox});
      
#       // Fire departments
#       node["amenity"="fire_station"]({bbox});
#       way["amenity"="fire_station"]({bbox});
#     );
#     out center;
#     """
#     return query

# # Fetch data from Overpass API
# def fetch_emergency_services(user_lat, user_lon, radius_km):
#     query = get_overpass_query(user_lat, user_lon, radius_km)
#     response = requests.post(OVERPASS_URL, data={"data": query})
    
#     if response.status_code != 200:
#         raise Exception(f"Overpass API error: {response.status_code}")
    
#     data = response.json()
#     services = []

#     # Process the results
#     for element in data["elements"]:
#         service = {}
        
#         # Handle nodes and ways (ways use "center" for lat/lon)
#         if element["type"] == "node":
#             service["latitude"] = element["lat"]
#             service["longitude"] = element["lon"]
#         elif element["type"] == "way" and "center" in element:
#             service["latitude"] = element["center"]["lat"]
#             service["longitude"] = element["center"]["lon"]
#         else:
#             continue
        
#         # Determine the type of service
#         amenity = element["tags"].get("amenity")
#         if amenity == "hospital":
#             # Confirm it has ambulance services
#             if element["tags"].get("emergency") == "ambulance" or element["tags"].get("ambulance") == "yes":
#                 service["type"] = "hospital"
#             else:
#                 continue
#         elif amenity == "police":
#             service["type"] = "police"
#         elif amenity == "fire_station":
#             service["type"] = "fire"
#         else:
#             continue
        
#         # Use name if available, otherwise generate a placeholder
#         service["name"] = element["tags"].get("name", f"{service['type'].capitalize()} {element['id']}")
        
#         services.append(service)
    
#     # Add the hardcoded KMC office
#     services.append(KMC_HEAD_OFFICE)
    
#     return services

# # Seed the data into Firestore
# def seed_firestore(user_lat, user_lon, radius_km):
#     emergency_services = fetch_emergency_services(user_lat, user_lon, radius_km)
#     for service in emergency_services:
#         doc_ref = db.collection('emergencyServices').document()
#         doc_ref.set(service)
#     print(f"Firestore seeded successfully with {len(emergency_services)} entries within {radius_km} km of ({user_lat}, {user_lon})")

# if __name__ == "__main__":
#     # Example: User's location (Kathmandu city center) and radius
#     user_latitude = 27.7172   # Example latitude (Kathmandu Durbar Square)
#     user_longitude = 85.3240  # Example longitude
#     radius = 10.0             # Radius in kilometers
    
#     seed_firestore(user_latitude, user_longitude, radius)