import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://172.16.31.2:5001'; // Update if needed (e.g., 10.0.2.2 for emulator)

  Future<bool> sendOtp(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Ensure phone number includes country code (e.g., +9771234567890)
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+977$phoneNumber'; // Adjust country code as needed
      }
      print('Sending OTP to: $phoneNumber');
      final response = await http.post(
        Uri.parse('$baseUrl/api/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );
      print('Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        await prefs.setString('phone', phoneNumber);
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending OTP: $e');
      return false;
    }
  }

  Future<String?> verifyOtp(String phoneNumber, String enteredOtp) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+977$phoneNumber'; // Adjust country code as needed
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'otp': enteredOtp,
        }),
      );
      print('Verify response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await prefs.setString('jwt_token', token);
        return token;
      }
      return null;
    } catch (e) {
      print('Error verifying OTP: $e');
      return null;
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('phone');
  }
}