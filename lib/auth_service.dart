import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Check if the user is already registered
  Future<bool> isUserRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');
    return email != null;
  }

  // Register user (store email and password)
  Future<bool> registerUser(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    // Check if email is already registered
    if (prefs.getString('email') != null) {
      return false; // User already registered
    }
    // Save the email and password to SharedPreferences
    prefs.setString('email', email);
    prefs.setString('password', password);
    return true;
  }

  // Login user (authenticate with saved email and password)
  Future<bool> loginUser(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    String? storedEmail = prefs.getString('email');
    String? storedPassword = prefs.getString('password');

    // Check if the entered credentials match the saved ones
    if (storedEmail == email && storedPassword == password) {
      return true; // Login successful
    } else {
      return false; // Login failed
    }
  }
}