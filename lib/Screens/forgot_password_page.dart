import 'package:cerebro_app/localhost.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  String message = '';
  bool isLoading = false;

  Future<void> sendResetCode() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$url/request-reset'),
        headers: {'Content-Type': 'application/json'},
        body: '{"email": "${emailController.text.trim()}"}',
      );

      if (response.statusCode == 200) {
        Navigator.pushNamed(context, '/verify-reset-code');
      } else {
        setState(() {
          message = 'Failed to send reset code.';
        });
      }
    } catch (e) {
      message = 'Network error.';
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000E1A),
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 15),
            if (message.isNotEmpty) Text(message),
            ElevatedButton(
              onPressed: isLoading ? null : sendResetCode,
              child:
                  isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Send Code'),
            ),
          ],
        ),
      ),
    );
  }
}
