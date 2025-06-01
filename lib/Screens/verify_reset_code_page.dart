import 'package:flutter/material.dart';
import 'create_new_password_page.dart';

class VerifyResetCodePage extends StatefulWidget {
  const VerifyResetCodePage({super.key});

  @override
  State<VerifyResetCodePage> createState() => _VerifyResetCodePageState();
}

class _VerifyResetCodePageState extends State<VerifyResetCodePage> {
  final codeController = TextEditingController();
  final emailController = TextEditingController();
  String errorMessage = '';

  void submitCode() {
    final code = codeController.text.trim();
    final email = emailController.text.trim();

    if (code.isEmpty || email.isEmpty) {
      setState(() => errorMessage = 'Both fields are required');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CreateNewPasswordPage(email: email, token: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000E1A),
        elevation: 0,
        title: const Text('Enter Reset Code'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
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
              controller: codeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Reset Code',
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
                onPressed: submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C6F4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
