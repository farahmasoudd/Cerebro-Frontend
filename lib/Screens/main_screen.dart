import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:simple_frame_app/frame_vision_app.dart';
import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:frame_msg/tx/plain_text.dart';
import 'package:frame_msg/tx/code.dart';
import 'package:frame_msg/rx/audio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'text_pagination.dart';

void main() => runApp(const MainApp());

final _log = Logger("MainScreen");

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp>
    with SimpleFrameAppState, FrameVisionAppState {
  Future<String> processImage({
    required List<int> imageBytes,
    String fileName = 'image.jpg',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_apiEndpoint/image'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: fileName,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Image API call returned status ${response.statusCode}: ${response.body}',
      );
    }

    return response.body;
  }

  Future<String> processAudio({
    required List<int> audioBytes,
    String fileName = 'audio.wav',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_apiEndpoint/voice'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: fileName,
      contentType: MediaType('audio', 'wav'),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Audio API call returned status ${response.statusCode}: ${response.body}',
      );
    }

    return response.body;
  }

  static const String _apiEndpoint = 'http://192.168.1.251:8000';
  // Audio Recording State
  StreamSubscription<Uint8List>? audioClipStreamSubs;
  bool _isRecordingAudio = false;

  // Vision Processing State
  bool _isProcessingImage = false;

  // Response Display State
  Timer? _clearTimer;
  final TextPagination _pagination = TextPagination();

  // UI State
  bool isConnected = false;
  final String frameDeviceName = 'Brilliant Frame';

  MainAppState() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '${record.level.name}: [${record.loggerName}] ${record.time}: ${record.message}',
      );
    });
  }

  @override
  void initState() {
    super.initState();
    asyncInit();
  }

  @override
  void dispose() {
    audioClipStreamSubs?.cancel();
    _clearTimer?.cancel();
    super.dispose();
  }

  Future<void> asyncInit() async {
    tryScanAndConnectAndStart(andRun: false);
  }

  Future<void> toggleConnection() async {
    if (isConnected) {
      await onCancel();
      setState(() {
        isConnected = false;
      });
      return;
    }
    await _connectToFrame();
  }

  Future<void> _connectToFrame() async {
    await tryScanAndConnectAndStart(andRun: true);
    setState(() {
      isConnected = currentState == ApplicationState.connected;
    });
  }

  @override
  Future<void> onRun() async {
    setState(() {
      isConnected = true;
    });

    await audioClipStreamSubs?.cancel();
    audioClipStreamSubs = RxAudio().attach(frame!.dataResponse).listen((
      audioData,
    ) {
      _log.info('Audio clip received: ${audioData.length} bytes');
      _processAudioData(audioData);
    });

    await frame!.sendMessage(
      0x0a,
      TxPlainText(
        text:
            '1-Tap: Record Audio\n2-Tap: Take Photo\n_______________\nReady to use!',
      ).pack(),
    );
  }

  @override
  Future<void> onCancel() async {
    await audioClipStreamSubs?.cancel();
    _pagination.clear();
    _clearTimer?.cancel();
    setState(() {
      isConnected = false;
    });
  }

  @override
  Future<void> onTap(int taps) async {
    _log.info('Received $taps tap(s)');

    switch (taps) {
      case 1:
        await _handleAudioRecording();
        break;
      case 2:
        await _handleImageCapture();
        break;
      default:
        _log.info('Unhandled tap count: $taps');
    }
  }

  Future<void> _handleAudioRecording() async {
    if (_isRecordingAudio || _isProcessingImage) return;

    setState(() {
      _isRecordingAudio = true;
    });
    _clearTimer?.cancel();

    await frame!.sendMessage(
      0x0a,
      TxPlainText(
        text: '🎤 Recording...\nTap again to stop',
        paletteOffset: 8,
      ).pack(),
    );

    await frame!.sendMessage(0x30, TxCode().pack());

    Timer(const Duration(seconds: 10), () async {
      if (_isRecordingAudio) {
        await frame!.sendMessage(0x31, TxCode().pack());
      }
    });
  }

  Future<void> _processAudioData(Uint8List audioData) async {
    if (!_isRecordingAudio) return;

    setState(() {
      _isRecordingAudio = false;
    });

    try {
      await frame!.sendMessage(
        0x0a,
        TxPlainText(text: '🔄 Processing audio...', paletteOffset: 6).pack(),
      );

      final wavData = _convertToWav(audioData);
      final response = await processAudio(audioBytes: wavData);
      await _handleResponseText(response);
    } catch (e) {
      _log.severe('Error processing audio: $e');
      await _handleResponseText('Error processing audio: $e');
    }
  }

  Future<void> _handleImageCapture() async {
    if (_isProcessingImage || _isRecordingAudio) return;

    setState(() {
      _isProcessingImage = true;
    });
    _clearTimer?.cancel();

    await frame!.sendMessage(
      0x0a,
      TxPlainText(text: '📸', paletteOffset: 8).pack(),
    );

    try {
      final photo = await capture();
      await _processImageData(photo);
    } catch (e) {
      _log.severe('Error capturing image: $e');
      await _handleResponseText('Error capturing image: $e');
      setState(() {
        _isProcessingImage = false;
      });
    }
  }

  Future<void> _processImageData((Uint8List, ImageMetadata) photo) async {
    final imageData = photo.$1;

    try {
      await frame!.sendMessage(
        0x0a,
        TxPlainText(text: '🔍 Analyzing image...', paletteOffset: 6).pack(),
      );

      final response = await processImage(imageBytes: imageData);
      await _handleResponseText(response);
    } catch (e) {
      _log.severe('Error processing image: $e');
      await _handleResponseText('Error processing image: $e');
    } finally {
      setState(() {
        _isProcessingImage = false;
      });
    }
  }

  Future<void> _handleResponseText(String text) async {
    _pagination.clear();
    for (var line in text.split('\n')) {
      _pagination.appendLine(line);
    }

    await frame!.sendMessage(
      0x0a,
      TxPlainText(text: _pagination.getCurrentPage().join('\n')).pack(),
    );

    _clearTimer = Timer(const Duration(seconds: 10), () async {
      await frame!.sendMessage(
        0x0a,
        TxPlainText(
          text:
              '1-Tap: Record Audio\n2-Tap: Take Photo\n_______________\nReady to use!',
        ).pack(),
      );
    });
  }

  Uint8List _convertToWav(
    Uint8List rawAudio, {
    int sampleRate = 8000,
    int channels = 1,
    int bitDepth = 16,
  }) {
    int dataSize = rawAudio.length;
    int headerSize = 44;
    int fileSize = headerSize + dataSize;

    final wavData = BytesBuilder();
    wavData.add(Uint8List.fromList('RIFF'.codeUnits));
    wavData.add(_intToBytes(fileSize - 8, 4));
    wavData.add(Uint8List.fromList('WAVE'.codeUnits));
    wavData.add(Uint8List.fromList('fmt '.codeUnits));
    wavData.add(_intToBytes(16, 4));
    wavData.add(_intToBytes(1, 2));
    wavData.add(_intToBytes(channels, 2));
    wavData.add(_intToBytes(sampleRate, 4));
    wavData.add(_intToBytes(sampleRate * channels * (bitDepth ~/ 8), 4));
    wavData.add(_intToBytes(channels * (bitDepth ~/ 8), 2));
    wavData.add(_intToBytes(bitDepth, 2));
    wavData.add(Uint8List.fromList('data'.codeUnits));
    wavData.add(_intToBytes(dataSize, 4));
    wavData.add(rawAudio);
    return wavData.toBytes();
  }

  Uint8List _intToBytes(int value, int length) {
    final result = Uint8List(length);
    for (int i = 0; i < length; i++) {
      result[i] = (value >> (8 * i)) & 0xFF;
    }
    return result;
  }

  Future<void> logout() async {
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Multi-Modal Assistant',
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF000E1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF000E1A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF008CFF)),
            onPressed: logout,
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF008CFF),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/chat');
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              GestureDetector(
                onTap: toggleConnection,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 4),
                    gradient: RadialGradient(
                      colors: [
                        isConnected ? const Color(0xFF008CFF) : Colors.grey,
                        Colors.transparent,
                      ],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                  ),
                  child: Center(
                    child:
                        (_isRecordingAudio || _isProcessingImage)
                            ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            )
                            : Icon(
                              isConnected ? Icons.sync : Icons.sync_disabled,
                              size: 50,
                              color: Colors.white,
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isConnected ? 'Connected to Frame' : 'Tap to connect',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A192D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Brilliant Frame',
                      style: TextStyle(
                        color: Color(0xFF008CFF),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(Icons.bluetooth, color: Colors.white70),
                        const SizedBox(width: 10),
                        const Text(
                          'Status: ',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color:
                                isConnected
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          isConnected ? Icons.link : Icons.link_off,
                          color: const Color(0xFF008CFF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(Icons.battery_full, color: Colors.white70),
                        const SizedBox(width: 10),
                        const Text(
                          'Battery: ',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          isConnected ? '$batteryLevel%' : '--',
                          style: TextStyle(
                            color:
                                (batteryLevel < 20)
                                    ? Colors.redAccent
                                    : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isConnected && batteryLevel < 20) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.warning_amber,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          const Text(
                            ' Low Battery',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
