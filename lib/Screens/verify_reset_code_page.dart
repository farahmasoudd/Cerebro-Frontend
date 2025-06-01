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
      appBar: AppBar(title: const Text('Enter Reset Code')),
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
              decoration: const InputDecoration(labelText: 'Reset Code'),
            ),
            const SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(errorMessage, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: submitCode,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
