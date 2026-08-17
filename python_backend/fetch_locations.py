import requests
from math import radians, sin, cos, sqrt, atan2

def haversine_distance(coord1, coord2):
    R = 6371  # Earth radius in km
    lat1, lon1 = radians(coord1[0]), radians(coord1[1])
    lat2, lon2 = radians(coord2[0]), radians(coord2[1])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c  # Distance in km

def get_service_locations(lat, lon, service_type, radius=10000):
    overpass_url = "http://overpass-api.de/api/interpreter"
    amenity_map = {
        "ambulance": "hospital",
        "policeman": "police",
        "firefighter": "fire_station",  # Explicitly map "firefighter" to "fire_station"
        "firestation": "fire_station",  # Keep for consistency, but prioritize "firefighter"
        "sewage": None,
        "garbage": None,
        "illegalparking": None
    }
    amenity = amenity_map.get(service_type)

    if amenity == "fire_station":  # Special handling for fire stations (firefighter/firestation)
        query = f"""
        [out:json];
        (
          node["amenity"="fire_station"](around:{radius},{lat},{lon});
          node["amenity"~"Damkal|दमकल|बारुन सेवा|Barun Sewa|Fire Department|Fire Station"]
          (around:{radius},{lat},{lon});
          node["amenity"="fire_station"]["emergency"="fire_service"](around:{radius},{lat},{lon});
          node["amenity"="fire_station"]["emergency"="fire_brigade"](around:{radius},{lat},{lon});
          node["amenity"="fire_station"]["fire_station:type"="station"](around:{radius},{lat},{lon});
          node["amenity"="fire_station"]["operator"!~"private|company"](around:{radius},{lat},{lon});
          node["amenity"="fire_station"]["fire_station:type"!~"training|equipment"](around:{radius},{lat},{lon});
          way["amenity"="fire_station"]["name"~"Damkal|दमकल|बारुन सेवा|Barun Sewa|Fire Department|Fire Station"](around:{radius},{lat},{lon});
          way["amenity"="fire_station"]["emergency"="fire_service"](around:{radius},{lat},{lon});
          way["amenity"="fire_station"]["emergency"="fire_brigade"](around:{radius},{lat},{lon});
          way["amenity"="fire_station"]["fire_station:type"="station"](around:{radius},{lat},{lon});
          way["amenity"="fire_station"]["operator"!~"private|company"](around:{radius},{lat},{lon});
          way["amenity"="fire_station"]["fire_station:type"!~"training|equipment"](around:{radius},{lat},{lon});
          node["amenity"="fire_station"]["fire_station:type"="training"](around:{radius},{lat},{lon})->.training;
          node["amenity"="fire_station"]["fire_station:type"="equipment"](around:{radius},{lat},{lon})->.equipment;
          node["amenity"="fire_station"]["operator"~"private|company"](around:{radius},{lat},{lon})->.private;
          way["amenity"="fire_station"]["fire_station:type"="training"](around:{radius},{lat},{lon})->.training;
          way["amenity"="fire_station"]["fire_station:type"="equipment"](around:{radius},{lat},{lon})->.equipment;
          way["amenity"="fire_station"]["operator"~"private|company"](around:{radius},{lat},{lon})->.private;
          (.training; .equipment; .private;)->.to_remove;
          (.to_remove;);<;out body qt .to_remove;>;
        );
        out center;
        """

    elif amenity == "hospital":  # Special handling for ambulance/hospitals
        query = f"""
        [out:json];
        (
          node["amenity"="hospital"]["emergency"="ambulance"](around:{radius},{lat},{lon});
          node["amenity"="hospital"]["ambulance"="yes"](around:{radius},{lat},{lon});
          way["amenity"="hospital"]["emergency"="ambulance"](around:{radius},{lat},{lon});
          way["amenity"="hospital"]["ambulance"="yes"](around:{radius},{lat},{lon});
          node["amenity"="hospital"]["healthcare:speciality"!~"dental"](around:{radius},{lat},{lon});
          node["amenity"="hospital"]["healthcare"!~"dentist"](around:{radius},{lat},{lon});
          way["amenity"="hospital"]["healthcare:speciality"!~"dentistry"](around:{radius},{lat},{lon});
          way["amenity"="hospital"]["healthcare"!~"dentist"](around:{radius},{lat},{lon});
          way["amenity"="hospital"]["healthcare"!~"dental"](around:{radius},{lat},{lon});
        );
        out center;
        """
    elif amenity == "police":
        query = f"""
        [out:json];
        node["amenity"="police"](around:{radius},{lat},{lon});
        out;
        """
    elif amenity:
        query = f"""
        [out:json];
        node["amenity"="{amenity}"](around:{radius},{lat},{lon});
        out;
        """
    else:
        # Use KMC Office location for non-emergency services
        print(f"Using KMC Office location for {service_type}")
        kmc_location = (27.69878035444752, 85.31206794082158, "KMC Office")
        return [kmc_location]

    print(f"Querying Overpass API for {service_type}: {query}")
    try:
        response = requests.get(overpass_url, params={"data": query}, timeout=10)
        response.raise_for_status()
        data = response.json()
        locations = []
        for element in data["elements"]:
            # Handle nodes and ways (ways use "center" for lat/lon)
            if element["type"] == "node":
                lat = element["lat"]
                lon = element["lon"]
            elif element["type"] == "way" and "center" in element:
                lat = element["center"]["lat"]
                lon = element["center"]["lon"]
            else:
                continue

            # Include the name for better identification
            name = element["tags"].get("name", f"{service_type.capitalize()} {element['id']}")
            locations.append((lat, lon, name))  # Return tuples with latitude, longitude, and name

        if not locations and service_type in ["firefighter", "firestation"]:
            print(f"No real locations found for {service_type}, using mock fire station location")
            return [(27.693790475692595, 85.30630198734741, "NEPAL FIRE AND SAFETY SOLUTIONS PVT.LTD")]

        if not locations and service_type in ["sewage", "garbage", "illegalparking"]:
            print(f"No real locations found for {service_type}, using KMC Office location")
            return [(27.69878035444752, 85.31206794082158, "KMC Office")]

        print(f"Found {len(locations)} {service_type} locations: {locations}")
        return locations

    except requests.exceptions.RequestException as e:
        print(f"Failed to fetch {service_type} locations: {str(e)}")
        if service_type in ["firefighter", "firestation"]:
            print(f"Using mock fire station location as fallback for {service_type}")
            return [(27.693790475692595, 85.30630198734741, "NEPAL FIRE AND SAFETY SOLUTIONS PVT.LTD")]
        if service_type in ["sewage", "garbage", "illegalparking"]:
            print(f"Using KMC Office location as fallback for {service_type}")
            return [(27.69878035444752, 85.31206794082158, "KMC Office")]
        return []

# Example usage (optional, for testing)
if __name__ == "__main__":
    # Test with Kathmandu coordinates and a service type
    lat, lon = 27.7172, 85.3240  # Kathmandu Durbar Square
    services = get_service_locations(lat, lon, "firefighter", radius=30000)
    print(services)


