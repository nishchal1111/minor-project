import 'package:flutter/material.dart';
import 'map_page.dart'; // Import the MapPage

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Function to navigate to the MapPage with Kathmandu's coordinates
  void _openMapPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapPage(
          latitude: 27.7172, // Latitude of Kathmandu
          longitude: 85.3240, // Longitude of Kathmandu
        ),
        
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Container(
          margin: const EdgeInsets.all(0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Image.asset(
                  "assets/images/nepal_gov.png",
                  width: 50,
                ),
              ),
              const Expanded(
                child: Text(
                  "Kathmandu Metropolitan City",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontFamily: "f1",
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Image.asset(
                  "assets/images/kmc_logo.png",
                  width: 50,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              _buildPoliceModule(),
              _buildChangeLanguage(),
              _buildGridView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String imagepath, String label) {
    return GestureDetector(
      onTap: _openMapPage, // Open the map with Kathmandu coordinates
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black26,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                imagepath,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.error, color: Colors.red, size: 50);
                },
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeLanguage() {
    return Container(
      padding: const EdgeInsets.all(15),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Send Alert Message",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: () {
              print("Language change tapped");
            },
            child: Row(
              children: [
                Image.asset(
                  "assets/images/globe.png",
                  width: 20,
                ),
                const SizedBox(width: 5),
                const Text(
                  "English",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
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
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black26,
        ),
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
                const Text(
                  "In case of any inquiry and any needs \nHotline number 1144, KMC Police",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      print("Call button tapped");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/callicon.png",
                          width: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "CALL",
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 400,
      ),
      child: GridView.count(
        shrinkWrap: true,
        primary: false,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        crossAxisCount: 3,
        children: [
          _buildButton("assets/images/ambulance.png", "ambulance"),
          _buildButton("assets/images/firefighter.png", "firefighter"),
          _buildButton("assets/images/policeman.png", "policeman"),
          _buildButton("assets/images/sewage.png", "sewage"),
          _buildButton("assets/images/garbage.png", "garbage"),
          _buildButton("assets/images/noparking.png", "noparking"),
        ],
      ),
    );
  }
}