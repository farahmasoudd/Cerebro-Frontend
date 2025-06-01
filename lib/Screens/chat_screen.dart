import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  File? _selectedImage;

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty && _selectedImage == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    setState(() {
      if (_selectedImage != null) {
        _messages.add({
          'role': 'user',
          'type': 'image',
          'file': _selectedImage,
          'text': message,
        });
      } else {
        _messages.add({'role': 'user', 'type': 'text', 'text': message});
      }
      _controller.clear();
    });

    try {
      http.Response response;

      if (_selectedImage != null && message.isNotEmpty) {
        final uri = Uri.parse('http://192.168.1.116:8000/multimodal');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['text'] = '<image> $message';
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
        final streamed = await request.send();
        final body = await streamed.stream.bytesToString();
        response = http.Response(body, streamed.statusCode);
      } else if (_selectedImage != null) {
        final uri = Uri.parse('http://192.168.1.116:8000/image');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(
          await http.MultipartFile.fromPath('file', _selectedImage!.path),
        );
        final streamed = await request.send();
        final body = await streamed.stream.bytesToString();
        response = http.Response(body, streamed.statusCode);
      } else {
        final uri = Uri.parse('http://192.168.1.116:8000/query');
        response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'input_type': 'text', 'content': message}),
        );
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final reply = json['response'] ?? 'No response from model.';
        setState(() {
          _messages.add({'role': 'bot', 'type': 'text', 'text': reply});
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _messages.add({
            'role': 'bot',
            'type': 'text',
            'text': 'Error: ${error['detail'] ?? response.statusCode}',
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'bot', 'type': 'text', 'text': 'Error: $e'});
      });
    }

    _selectedImage = null;
    _scrollToBottom();
  }

  Future<void> _startListening() async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) return;
    }

    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            setState(() => _isListening = false);
            _speech.stop();
            _controller.text = result.recognizedWords;
            await _sendMessage();
          }
        },
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    final type = message['type'];
    final text = message['text'];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF34C6F4) : Colors.white10,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == 'image' && message['file'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(message['file'], width: 220),
              ),
            if (text != null && text.isNotEmpty) ...[
              if (type == 'image') const SizedBox(height: 6),
              Text(
                text,
                style: TextStyle(color: isUser ? Colors.white : Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192D),
        elevation: 0,
        title: const Text("Chat"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF34C6F4)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.chat_bubble_outline, color: Color(0xFF34C6F4)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Image.file(
                        _selectedImage!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed:
                              () => setState(() => _selectedImage = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Image selected...',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF000E1A),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.white70),
                  onPressed: _pickImageFromGallery,
                ),
                IconButton(
                  icon: const Icon(Icons.photo_camera, color: Colors.white70),
                  onPressed: _pickImageFromCamera,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ask anything ..........",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    color: Colors.white70,
                  ),
                  onPressed: _startListening,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF34C6F4)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
