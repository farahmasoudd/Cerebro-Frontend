import 'package:cerebro_app/localhost.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateNewPasswordPage extends StatefulWidget {
  final String email;
  final String token;

  const CreateNewPasswordPage({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<CreateNewPasswordPage> createState() => _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState extends State<CreateNewPasswordPage> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String errorMessage = '';
  bool isLoading = false;

  Future<void> resetPassword() async {
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (password != confirm) {
      setState(() {
        errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      errorMessage = '';
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$url/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": widget.email,
          "new_password": password,
          "token": widget.token,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      } else {
        final json = jsonDecode(response.body);
        setState(() {
          if (json is Map<String, dynamic>) {
            errorMessage = json['detail'] ?? 'Failed to reset password.';
          } else if (json is List && json.isNotEmpty) {
            errorMessage = json.first.toString();
          } else {
            errorMessage = 'Unexpected response from server.';
          }
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000E1A),
        elevation: 0,
        title: const Text('Create New Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.redAccent),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C6F4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Reset Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
