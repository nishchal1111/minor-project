
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart'; // Import AuthService

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.serviceName,
    required this.isNepali,
  });

  final double latitude;
  final double longitude;
  final String serviceName;
  final bool isNepali;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late MapController controller;
  double? currentLatitude;
  double? currentLongitude;
  String currentAddress = "Fetching address...";
  GeoPoint? nearestServiceLocation;
  File? _selectedImage;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    controller = MapController(
      initPosition: GeoPoint(latitude: widget.latitude, longitude: widget.longitude),
    );
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => currentAddress = widget.isNepali ? "स्थान सेवा बन्द छ" : "Location services disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        setState(() => currentAddress = widget.isNepali ? "स्थान अनुमति सधैंको लागि अस्वीकृत" : "Location permission denied forever");
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentLatitude = position.latitude;
      currentLongitude = position.longitude;
    });

    GeoPoint currentPosition = GeoPoint(latitude: currentLatitude!, longitude: currentLongitude!);
    await controller.changeLocation(currentPosition);
    await controller.addMarker(
      currentPosition,
      markerIcon: const MarkerIcon(icon: Icon(Icons.person_pin_circle, color: Colors.blue, size: 32)),
    );
    _getAddressFromCoordinates();
  }

  Future<void> _getAddressFromCoordinates() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(currentLatitude!, currentLongitude!);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        String formattedAddress = "${placemark.street}, ${placemark.locality}".trim();
        if (widget.isNepali) {
          formattedAddress = formattedAddress.replaceAll("Street", "सडक").replaceAll("Locality", "इलाका");
        }
        setState(() => currentAddress = formattedAddress);
      }
    } catch (e) {
      setState(() => currentAddress = widget.isNepali ? "ठेगाना लिन सकिएन: $e" : "Unable to fetch address: $e");
    }
  }

  Future<void> _drawPathToNearestService(GeoPoint start, GeoPoint end, List<dynamic>? path) async {
    await controller.removeLastRoad();

    if (path != null && path.isNotEmpty) {
      List<GeoPoint> pathPoints = path.map((coord) => GeoPoint(latitude: coord[0], longitude: coord[1])).toList();
      try {
        await controller.drawRoadManually(
          pathPoints,
          const RoadOption(roadWidth: 20, roadColor: Colors.redAccent),
        );
      } catch (e) {
        print("Error drawing road manually: $e");
        await controller.drawRoad(
          start,
          end,
          roadType: RoadType.car,
          roadOption: const RoadOption(roadWidth: 8, roadColor: Colors.redAccent),
        );
      }
    } else {
      await controller.drawRoad(
        start,
        end,
        roadType: RoadType.car,
        roadOption: const RoadOption(roadWidth: 8, roadColor: Colors.redAccent),
      );
    }

    await controller.addMarker(
      end,
      markerIcon: const MarkerIcon(icon: Icon(Icons.location_on, color: Colors.red, size: 32)),
    );

    if (path != null && path.isNotEmpty) {
      await controller.zoomToBoundingBox(
        BoundingBox.fromGeoPoints(path.map((coord) => GeoPoint(latitude: coord[0], longitude: coord[1])).toList()),
        paddinInPixel: 50,
      );
    } else {
      await controller.zoomToBoundingBox(
        BoundingBox.fromGeoPoints([start, end]),
        paddinInPixel: 50,
      );
    }
  }

  Future<void> _findNearestServiceAndSendAlert() async {
    if (currentLatitude == null || currentLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isNepali ? "हालको स्थान उपलब्ध छैन" : "Current location not available")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      const String backendUrl = "http://172.16.31.2:5001/send_alert";
      var request = http.MultipartRequest("POST", Uri.parse(backendUrl));

      String? token = await _authService.getToken();
      if (token == null) {
        throw Exception(widget.isNepali ? "प्रमाणीकरण टोकन उपलब्ध छैन। कृपया फेरि लगइन गर्नुहोस्।" : "No authentication token available. Please log in again.");
      }

      request.headers['Authorization'] = 'Bearer $token';
      request.fields["latitude"] = currentLatitude!.toString();
      request.fields["longitude"] = currentLongitude!.toString();
      request.fields["service_type"] = widget.serviceName.toLowerCase();

      final prefs = await SharedPreferences.getInstance();
      String? phoneNumber = prefs.getString('phone');
      if (phoneNumber != null) {
        request.fields["phone_number"] = phoneNumber;
      }

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath("photo", _selectedImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Send alert response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 200) {
          if (["ambulance", "firefighter", "policeman"].contains(widget.serviceName.toLowerCase())) {
            final nearestService = data["nearest_ambulance"] as List<dynamic>? ?? [];
            if (nearestService.isNotEmpty && nearestService.length >= 2) {
              nearestServiceLocation = GeoPoint(latitude: nearestService[0], longitude: nearestService[1]);
              GeoPoint userLocation = GeoPoint(latitude: currentLatitude!, longitude: currentLongitude!);
              const String pathUrl = "http://172.16.31.2:5000/shortest-path";
              final pathResponse = await http.post(
                Uri.parse(pathUrl),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "latitude": currentLatitude,
                  "longitude": currentLongitude,
                  "service_type": widget.serviceName.toLowerCase(),
                }),
              );

              if (pathResponse.statusCode == 200) {
                final pathData = jsonDecode(pathResponse.body) as Map<String, dynamic>;
                if (pathData["status"] == 200 && pathData["path"] != null && pathData["path"].isNotEmpty) {
                  List<dynamic> path = pathData["path"];
                  await _drawPathToNearestService(userLocation, nearestServiceLocation!, path);
                } else {
                  await _drawPathToNearestService(userLocation, nearestServiceLocation!, null);
                  print("No path data or invalid path from A*, using straight line");
                }
              } else {
                await _drawPathToNearestService(userLocation, nearestServiceLocation!, null);
                print("Path server error: ${pathResponse.statusCode}, ${pathResponse.body}");
              }

              double distance = _haversineDistance(userLocation, nearestServiceLocation!);
              _showConfirmationDialog(distance);
            } else {
              throw Exception("Invalid nearest service location");
            }
          } else {
            nearestServiceLocation = GeoPoint(latitude: 27.69878035444752, longitude: 85.31206794082158);
            GeoPoint userLocation = GeoPoint(latitude: currentLatitude!, longitude: currentLongitude!);
            await _drawPathToNearestService(userLocation, nearestServiceLocation!, null);

            double distance = _haversineDistance(userLocation, nearestServiceLocation!);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.isNepali ? "केएमसी कार्यालयलाई सूचना पठाइयो, दूरी: ${distance.toStringAsFixed(2)} किमी" : "Alert sent to KMC Office, Distance: ${distance.toStringAsFixed(2)} km")),
            );
          }
        } else {
          throw Exception(data['error'] ?? "Unknown error");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}, ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isNepali ? "त्रुटि: $e" : "Exception: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _haversineDistance(GeoPoint a, GeoPoint b) {
    const double R = 6371;
    double lat1 = a.latitude * pi / 180;
    double lat2 = b.latitude * pi / 180;
    double deltaLat = (b.latitude - a.latitude) * pi / 180;
    double deltaLon = (b.longitude - a.longitude) * pi / 180;

    double x = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    double c = 2 * atan2(sqrt(x), sqrt(1 - x));
    return R * c;
  }

  void _showConfirmationDialog(double distance) {
    String serviceLabel = widget.isNepali
        ? (widget.serviceName == "प्रहरी" ? "प्रहरी" : widget.serviceName == "एम्बुलेन्स" ? "एम्बुलेन्स" : widget.serviceName == "दमकल" ? "दमकल" : widget.serviceName)
        : widget.serviceName;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.isNepali ? "सन्देश पठाउनुहोस्?" : "Send Alert?"),
          content: Text(widget.isNepali
              ? "नजिकको $serviceLabel: ${distance.toStringAsFixed(2)} किमी। सन्देश पठाउनुहुन्छ?"
              : "Nearest $serviceLabel: ${distance.toStringAsFixed(2)} km. Send alert?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isNepali ? "होइन" : "No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(widget.isNepali ? "सन्देश पठाइयो!" : "Alert Sent!")),
                );
              },
              child: Text(widget.isNepali ? "हो" : "Yes"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPhotoUploadOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.redAccent),
                title: Text(widget.isNepali ? "क्यामेरा" : "Camera"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.redAccent),
                title: Text(widget.isNepali ? "ग्यालरी" : "Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isNepali ? "फोटो चयन गरियो!" : "Photo selected!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseFontSize = (screenWidth * 0.035).clamp(12.0, 16.0);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.serviceName.toUpperCase(),
          style: TextStyle(color: Colors.white, fontSize: baseFontSize * 1.2, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: OSMFlutter(
              controller: controller,
              osmOption: const OSMOption(
                zoomOption: ZoomOption(initZoom: 14, minZoomLevel: 10, maxZoomLevel: 19),
                userTrackingOption: UserTrackingOption(enableTracking: true),
              ),
            ),
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Image.file(_selectedImage!, height: 100, width: double.infinity, fit: BoxFit.cover),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.isNepali ? "ठेगाना: $currentAddress" : "Address: $currentAddress",
                          style: TextStyle(fontSize: baseFontSize, color: Colors.grey.shade800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Aesthetic Photo Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.redAccent, Colors.orangeAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _showPhotoUploadOptions,
                          icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          label: Text(
                            widget.isNepali ? "फोटो" : "Photo",
                            style: TextStyle(fontSize: baseFontSize, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      // Aesthetic Alert Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.red, Colors.redAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _findNearestServiceAndSendAlert,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send, size: 20, color: Colors.white),
                          label: Text(
                            widget.isNepali ? "सन्देश" : "Alert",
                            style: TextStyle(fontSize: baseFontSize, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Warning Message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      widget.isNepali
                          ? "नक्कली सन्देश पठाउन निषेध छ र यसको परिणाम हुनेछ।"
                          : "Sending fake alerts is prohibited and will have consequences.",
                      style: TextStyle(
                        fontSize: baseFontSize * 0.9,
                        color: Colors.redAccent.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}





