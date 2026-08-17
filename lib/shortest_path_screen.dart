// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// class ShortestPathScreen extends StatefulWidget {
//   const ShortestPathScreen({super.key});

//   @override
//   _ShortestPathScreenState createState() => _ShortestPathScreenState();
// }

// class _ShortestPathScreenState extends State<ShortestPathScreen> {
//   GoogleMapController? _mapController;
//   Set<Marker> _markers = {};
//   Set<Polyline> _polylines = {};
//   LatLng _currentLocation = const LatLng(27.7172, 85.3240); // Default Kathmandu
//   bool _isLoading = false;

//   Future<void> findNearestAmbulance() async {
//     setState(() => _isLoading = true);
//     try {
//       // Fetch user's current location
//       Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//       LatLng userLocation = LatLng(position.latitude, position.longitude);

//       // Replace with your backend's IP or hosted URL
//       const String backendUrl = "http://192.168.1.69:5001/send_alert"; // Use app.py endpoint
//       final response = await http.post(
//         Uri.parse(backendUrl),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "latitude": position.latitude,
//           "longitude": position.longitude,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final ambulanceLat = data["nearest_ambulance"][0]; // Tuple from backend
//         final ambulanceLon = data["nearest_ambulance"][1];
//         LatLng ambulanceLocation = LatLng(ambulanceLat, ambulanceLon);

//         setState(() {
//           _currentLocation = userLocation;
//           _markers.clear();
//           _markers.add(Marker(
//             markerId: const MarkerId("user_location"),
//             position: userLocation,
//             infoWindow: const InfoWindow(title: "Your Location"),
//           ));
//           _markers.add(Marker(
//             markerId: const MarkerId("ambulance_location"),
//             position: ambulanceLocation,
//             infoWindow: const InfoWindow(title: "Nearest Ambulance"),
//             icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//           ));

//           _polylines.clear();
//           _polylines.add(Polyline(
//             polylineId: const PolylineId("path_to_ambulance"),
//             points: [userLocation, ambulanceLocation],
//             color: Colors.blue,
//             width: 5,
//           ));
//         });

//         _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLocation, 14));
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Alert sent successfully!")),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Error: ${response.body}")),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Exception: $e")),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Nearest Ambulance")),
//       body: Stack(
//         children: [
//           GoogleMap(
//             initialCameraPosition: CameraPosition(
//               target: _currentLocation,
//               zoom: 14,
//             ),
//             onMapCreated: (GoogleMapController controller) {
//               _mapController = controller;
//             },
//             markers: _markers,
//             polylines: _polylines,
//             myLocationEnabled: true,
//           ),
//           Positioned(
//             bottom: 20,
//             left: 20,
//             child: ElevatedButton(
//               onPressed: _isLoading ? null : findNearestAmbulance,
//               child: _isLoading
//                   ? const CircularProgressIndicator(color: Colors.white)
//                   : const Text("Find Nearest Ambulance"),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }