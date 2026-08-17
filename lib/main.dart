import 'package:flutter/material.dart';

import 'LoginPage.dart'; // Import LoginPage here if you want to navigate to it later

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KMC App',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const SplashScreen(), // Start with a splash screen first
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Show a splash screen for 5 seconds
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background Image - Dharahara
          Positioned.fill(
            child: Image.asset(
              'assets/images/dharahara.png', // Ensure the path is correct
              fit: BoxFit.cover, // Cover the entire screen
            ),
          ),
          // Content Overlay
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Centralized Row for both Logos
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Nepal Government logo
                      Image.asset(
                        'assets/images/nepal_gov.png', // Ensure correct path to your image
                        height: 80,
                        width: 80,
                      ),
                      const SizedBox(width: 20), // Add spacing between the logos

                      // KMC Logo
                      Image.asset(
                        'assets/images/kmc_logo.png', // KMC logo added
                        height: 80,
                        width: 80,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40), // Add some space between logos and text

                // Title of the app - Kathmandu Metropolitan City
                const Text(
                  'Kathmandu Metropolitan City',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle or additional info
                const Text(
                  'तपाईको सुरक्षा, हाम्रो प्राथमिकता',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color.fromARGB(255, 52, 51, 51),
                    fontStyle: FontStyle.italic,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(3, 3),
                        blurRadius: 3,
                      ),
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
}