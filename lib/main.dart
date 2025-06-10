import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Screens/register_page.dart';
import 'Screens/verify_account_page.dart';
import 'Screens/forgot_password_page.dart';
import 'Screens/verify_reset_code_page.dart';
import 'Screens/create_new_password_page.dart';
import 'Screens/main_screen.dart';
import 'Screens/chat_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cerebro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white10,
          hintStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34C6F4),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      routes: {
        '/register': (context) => const RegisterPage(),
        '/verify': (context) => const VerifyAccountPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/verify-reset-code': (context) => const VerifyResetCodePage(),
        '/chat': (context) => const ChatScreen(),
        '/main': (context) => const MainApp(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/create-new-password') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder:
                (context) => CreateNewPasswordPage(
                  email: args['email']!,
                  token: args['token']!,
                ),
          );
        }
        return null;
      },
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePassword = true;
  String errorMessage = '';

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Enter email and password');
      return;
    }

    final uri = Uri.parse('http://192.168.1.218:8000/login');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        if (token == null || token.toString().trim().isEmpty) {
          setState(() => errorMessage = 'Error: No access token returned');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        final data = jsonDecode(response.body);
        setState(() => errorMessage = data['detail'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => errorMessage = 'Error: $e');
    }
  }

  void showInstructionsDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF000E1A),
            title: const Text(
              'How to Use Cerebro',
              style: TextStyle(
                color: Color(0xFF34C6F4),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const SingleChildScrollView(
              child: Text('''
0- Create an account
1- Login to your account
2- Allow any permissions requested by the app
3- Remove the already charged glasses from the charging cradle
4- Put a nose piece with the right fitting for you, then wear the glasses
5- A popup will appear prompting you to pair to the glasses, click on pair
6- Click on the connect round button in the middle of the screen
7- Wait for the application to load onto the frame
8- Gently tap once on the right-hand side of Cerebro glasses for audio query
9- Double tap the same spot for an image query
10- Alternatively, you could click on the chat button on the top right corner to access the system without Cerebro

Note: Ensure Bluetooth and Internet are enabled.
            ''', style: TextStyle(color: Colors.white70, height: 1.5)),
            ),
            actions: [
              TextButton(
                child: Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF34C6F4)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_texture.png'),
            fit: BoxFit.cover,
            opacity: 0.8, // adjust for softness
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 170,
                      width: 170,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed:
                              () =>
                                  setState(() => hidePassword = !hidePassword),
                        ),
                      ),
                    ),
                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: login,
                      child: const Text('Log in'),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed:
                          () => Navigator.pushNamed(context, '/register'),
                      child: const Text('Create a new account'),
                    ),
                    TextButton(
                      onPressed:
                          () =>
                              Navigator.pushNamed(context, '/forgot-password'),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  size: 36,
                  color: Color(0xFF34C6F4),
                ),
                tooltip: 'Instructions',
                onPressed: showInstructionsDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
