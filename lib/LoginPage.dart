import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'HomePage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isOtpSent = false;

  void _sendOtp() async {
    String phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty || phoneNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number (e.g., 9812345678)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _authService.sendOtp(phoneNumber);

    setState(() {
      _isLoading = false;
      if (success) _isOtpSent = true;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send OTP')),
      );
    }
  }

  void _verifyOtp() async {
    String phoneNumber = _phoneController.text.trim();
    String otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid OTP')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final token = await _authService.verifyOtp(phoneNumber, otp);

    setState(() {
      _isLoading = false;
    });

    if (token != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        "assets/images/kmc_logo.png",
                        height: 100,
                        width: 100,
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "KMC ALERT",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Kathmandu Metropolitan City",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Phone Number (e.g., 9812345678)',
                      hintStyle: const TextStyle(color: Colors.blueGrey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15.0,
                        horizontal: 20.0,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  if (_isOtpSent) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Enter OTP',
                        hintStyle: const TextStyle(color: Colors.blueGrey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15.0,
                          horizontal: 20.0,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isOtpSent ? _verifyOtp : _sendOtp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 60.0,
                        vertical: 15.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isOtpSent ? 'Verify OTP' : 'Send OTP',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}