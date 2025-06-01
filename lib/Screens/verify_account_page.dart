import 'package:cerebro_app/localhost.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VerifyAccountPage extends StatefulWidget {
  const VerifyAccountPage({super.key});

  @override
  State<VerifyAccountPage> createState() => _VerifyAccountPageState();
}

class _VerifyAccountPageState extends State<VerifyAccountPage> {
  final codeController = TextEditingController();
  final emailController = TextEditingController();
  String errorMessage = '';
  bool isLoading = false;

  Future<void> verifyAccount() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$url/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text.trim(),
          'code': codeController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/');
      } else {
        final json = jsonDecode(response.body);
        setState(() {
          errorMessage = json['detail'] ?? 'Verification failed.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000E1A),
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Verification Code'),
            ),
            const SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isLoading ? null : verifyAccount,
              child:
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify Account'),
            ),
          ],
        ),
      ),
    );
  }
}
