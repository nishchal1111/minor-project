import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required double latitude, required double longitude});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController controller;

  @override
  void initState() {
    super.initState();

    // Initialize the map controller with Kathmandu's coordinates.
    controller = MapController(
      initPosition: GeoPoint(
        latitude: 27.7172,  // Latitude of Kathmandu
        longitude: 85.3240, // Longitude of Kathmandu
      ),
      areaLimit: BoundingBox(
        east: 85.5,  // Right limit (Longitude)
        north: 27.8, // Top limit (Latitude)
        west: 85.2,  // Left limit (Longitude)
        south: 27.6, // Bottom limit (Latitude)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context); // Go back to the previous page
          },
        ),
        title: const Text(
          'Kathmandu Map',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: OSMFlutter(
        controller: controller,
        osmOption: OSMOption(
          zoomOption: const ZoomOption(
            initZoom: 12, // Set zoom level for Kathmandu
            minZoomLevel: 8,
            maxZoomLevel: 18,
            stepZoom: 1.0,
          ),
          userTrackingOption: UserTrackingOption(
            enableTracking: false, // Disable user tracking
            unFollowUser: true,    // Don't follow the user
          ), 
          roadConfiguration: const RoadOption(
            roadColor: Colors.yellowAccent,
          ),
        ),
      ),
    );
  }
}