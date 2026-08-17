import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map_page.dart'; // Updated import to match your file name
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? phoneNumber;
  bool isNepali = false;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _getPhoneNumber();
  }

  Future<void> _getPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phoneNumber = prefs.getString('phone'); // Updated to match auth.dart key
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNepali ? "स्थान सेवा बन्द छ" : "Location services are disabled")),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isNepali ? "स्थान अनुमति अस्वीकृत" : "Location permission denied")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNepali ? "स्थान अनुमति सधैंको लागि अस्वीकृत" : "Location permissions are permanently denied")),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNepali ? "स्थान लिन सकिएन: $e" : "Error fetching location: $e")),
      );
    }
  }

  void _toggleLanguage() {
    setState(() {
      isNepali = !isNepali;
    });
  }

  void _openMapPage(String serviceName) {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNepali ? "हालको स्थान उपलब्ध छैन" : "Current location not available")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          serviceName: serviceName,
          isNepali: isNepali,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset("assets/images/nepal_gov.png", width: 50),
            Expanded(
              child: Text(
                isNepali ? "काठमाडौं महानगरपालिका" : "Kathmandu Metropolitan City",
                style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Image.asset("assets/images/kmc_logo.png", width: 50),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              _buildPoliceModule(),
              _buildLanguageToggle(),
              _buildGridView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      padding: const EdgeInsets.all(15),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isNepali ? "सन्देश पठाउनुहोस्" : "Send Alert Message",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          GestureDetector(
            onTap: _toggleLanguage,
            child: Row(
              children: [
                Image.asset("assets/images/globe.png", width: 20),
                const SizedBox(width: 5),
                Text(isNepali ? "नेपाली" : "English", style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoliceModule() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Image.asset("assets/images/policeman.png", width: 50),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNepali
                      ? "कुनै पनि सोधपुछ वा आवश्यकताका लागि हटलाइन नम्बर 1144, केएमसी प्रहरी"
                      : "In case of any inquiry and any needs Hotline number 1144, KMC Police",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    _showCallOptionsDialog();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset("assets/images/callicon.png", width: 20),
                      const SizedBox(width: 10),
                      Text(isNepali ? "कल गर्नुहोस्" : "CALL", style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCallOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isNepali ? "कल गर्नुहोस्" : "Make a Call"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  const String phoneNumber = "1144";
                  final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  } else {
                    await Clipboard.setData(const ClipboardData(text: phoneNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isNepali
                              ? "फोन कल गर्न सकिएन। नम्बर $phoneNumber क्लिपबोर्डमा कपी गरियो।"
                              : "Cannot launch phone call. Number $phoneNumber copied to clipboard.",
                        ),
                        action: SnackBarAction(
                          label: isNepali ? "ठीक छ" : "OK",
                          onPressed: () {},
                        ),
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.phone),
                label: Text(isNepali ? "फोन" : "Phone"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isNepali ? "रद्द गर्नुहोस्" : "Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      crossAxisCount: 3,
      children: [
        _buildButton("assets/images/ambulance.png", isNepali ? "एम्बुलेन्स" : "Ambulance"),
        _buildButton("assets/images/firefighter.png", isNepali ? "दमकल" : "Firefighter"),
        _buildButton("assets/images/policeman.png", isNepali ? "प्रहरी" : "Policeman"),
        _buildButton("assets/images/sewage.png", isNepali ? "फोहोर पानी" : "Sewage"),
        _buildButton("assets/images/garbage.png", isNepali ? "फोहोर" : "Garbage"),
        _buildButton("assets/images/noparking.png", isNepali ? "अवैध पार्किङ" : "Illegal Parking"),
      ],
    );
  }

  Widget _buildButton(String imagePath, String label) {
    return GestureDetector(
      onTap: () => _openMapPage(label),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 50, height: 50, fit: BoxFit.contain),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}