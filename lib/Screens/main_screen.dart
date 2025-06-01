import 'dart:async';
import 'dart:convert';
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiEndpoint/image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      final multipartFile = http.MultipartFile.fromBytes(
        'file', // Changed from 'image' to 'file' to match backend
        imageBytes,
        filename: fileName,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      _log.info('Image API response status: ${response.statusCode}');
      _log.info('Image API response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Image API call failed with status ${response.statusCode}: ${response.body}',
        );
      }

      // Parse JSON response
      final jsonResponse = json.decode(response.body);
      return jsonResponse['response'] ?? 'No response received';
    } catch (e) {
      _log.severe('Error in processImage: $e');
      rethrow;
    }
  }

  Future<String> processAudio({
    required List<int> audioBytes,
    String fileName = 'audio.wav',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiEndpoint/voice'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      final multipartFile = http.MultipartFile.fromBytes(
        'file', // Changed from 'audio' to 'file' to match backend
        audioBytes,
        filename: fileName,
        contentType: MediaType('audio', 'wav'),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      _log.info('Audio API response status: ${response.statusCode}');
      _log.info('Audio API response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Audio API call failed with status ${response.statusCode}: ${response.body}',
        );
      }

      // Parse JSON response
      final jsonResponse = json.decode(response.body);
      final transcription = jsonResponse['transcription'] ?? '';
      final aiResponse = jsonResponse['response'] ?? '';

      return 'Transcription: $transcription\n\nResponse: $aiResponse';
    } catch (e) {
      _log.severe('Error in processAudio: $e');
      rethrow;
    }
  }

  static const String _apiEndpoint = 'http://192.168.1.251:8000';

  // Audio Recording State
  StreamSubscription<Uint8List>? audioClipStreamSubs;
  bool _isRecordingAudio = false;
  List<Uint8List> _audioChunks = [];
  Timer? _recordingTimer;

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
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> asyncInit() async {
    await tryScanAndConnectAndStart(andRun: false);
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
    try {
      await tryScanAndConnectAndStart(andRun: true);
      setState(() {
        isConnected = currentState == ApplicationState.connected;
      });
    } catch (e) {
      _log.severe('Error connecting to frame: $e');
      setState(() {
        isConnected = false;
      });
    }
  }

  @override
  Future<void> onRun() async {
    setState(() {
      isConnected = true;
    });

    await audioClipStreamSubs?.cancel();
    audioClipStreamSubs = RxAudio()
        .attach(frame!.dataResponse)
        .listen(
          (audioData) {
            _log.info('Audio clip received: ${audioData.length} bytes');
            _handleAudioChunk(audioData);
          },
          onError: (error) {
            _log.severe('Audio stream error: $error');
            _handleAudioError(error);
          },
          onDone: () {
            _log.info('Audio stream completed');
            _handleAudioComplete();
          },
        );

    // Enable tap subscription
    await frame!.sendMessage(0x10, TxCode(value: 1).pack());

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
    _recordingTimer?.cancel();
    _pagination.clear();
    _clearTimer?.cancel();

    // Disable tap subscription
    if (frame != null) {
      await frame!.sendMessage(0x10, TxCode(value: 0).pack());
    }

    setState(() {
      isConnected = false;
      _isRecordingAudio = false;
      _isProcessingImage = false;
    });
  }

  @override
  Future<void> onTap(int taps) async {
    _log.info('Received $taps tap(s)');

    try {
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
    } catch (e) {
      _log.severe('Error handling tap: $e');
      await _handleResponseText('Error: $e');
    }
  }

  Future<void> _handleAudioRecording() async {
    if (_isProcessingImage) {
      _log.info('Image processing in progress, ignoring audio request');
      return;
    }

    if (_isRecordingAudio) {
      // Stop recording
      _log.info('Stopping audio recording');
      await _stopAudioRecording();
    } else {
      // Start recording
      _log.info('Starting audio recording');
      await _startAudioRecording();
    }
  }

  Future<void> _startAudioRecording() async {
    setState(() {
      _isRecordingAudio = true;
    });

    _clearTimer?.cancel();
    _audioChunks.clear();

    await frame!.sendMessage(
      0x0a,
      TxPlainText(
        text: '🎤 Recording...\nTap again to stop',
        paletteOffset: 8,
      ).pack(),
    );

    // Start audio recording
    await frame!.sendMessage(0x30, TxCode().pack());

    // Auto-stop after 10 seconds
    _recordingTimer = Timer(const Duration(seconds: 10), () async {
      if (_isRecordingAudio) {
        _log.info('Auto-stopping recording after 10 seconds');
        await _stopAudioRecording();
      }
    });
  }

  Future<void> _stopAudioRecording() async {
    if (!_isRecordingAudio) return;

    _recordingTimer?.cancel();

    // Send stop message to frame
    await frame!.sendMessage(0x31, TxCode().pack());

    await frame!.sendMessage(
      0x0a,
      TxPlainText(text: '⏹️ Stopping...', paletteOffset: 6).pack(),
    );

    // Give some time for final audio chunks to arrive
    await Future.delayed(const Duration(milliseconds: 500));

    // Process collected audio
    if (_audioChunks.isNotEmpty) {
      await _processCollectedAudio();
    } else {
      _log.warning('No audio chunks collected');
      await _handleResponseText('No audio recorded. Please try again.');
    }

    setState(() {
      _isRecordingAudio = false;
    });
  }

  void _handleAudioChunk(Uint8List audioData) {
    if (_isRecordingAudio) {
      _audioChunks.add(audioData);
      _log.info(
        'Added audio chunk: ${audioData.length} bytes, total chunks: ${_audioChunks.length}',
      );
    }
  }

  void _handleAudioError(dynamic error) {
    _log.severe('Audio recording error: $error');
    setState(() {
      _isRecordingAudio = false;
    });
    _recordingTimer?.cancel();
    _handleResponseText('Audio recording error: $error');
  }

  void _handleAudioComplete() {
    _log.info('Audio recording completed');
    if (_isRecordingAudio) {
      _processCollectedAudio();
    }
  }

  Future<void> _processCollectedAudio() async {
    try {
      await frame!.sendMessage(
        0x0a,
        TxPlainText(text: '🔄 Processing audio...', paletteOffset: 6).pack(),
      );

      // Combine all audio chunks
      final totalLength = _audioChunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.length,
      );
      final combinedAudio = Uint8List(totalLength);
      int offset = 0;

      for (final chunk in _audioChunks) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      _log.info('Combined audio length: ${combinedAudio.length} bytes');

      if (combinedAudio.isEmpty) {
        throw Exception('No audio data to process');
      }

      final wavData = _convertToWav(combinedAudio);
      final response = await processAudio(audioBytes: wavData);
      await _handleResponseText(response);
    } catch (e) {
      _log.severe('Error processing audio: $e');
      await _handleResponseText('Error processing audio: $e');
    } finally {
      _audioChunks.clear();
    }
  }

  Future<void> _handleImageCapture() async {
    if (_isProcessingImage || _isRecordingAudio) {
      _log.info('Another operation in progress, ignoring image request');
      return;
    }

    setState(() {
      _isProcessingImage = true;
    });
    _clearTimer?.cancel();

    await frame!.sendMessage(
      0x0a,
      TxPlainText(text: '📸 Capturing...', paletteOffset: 8).pack(),
    );

    try {
      final photo = await capture();
      await _processImageData(photo);
    } catch (e) {
      _log.severe('Error capturing image: $e');
      await _handleResponseText('Error capturing image: $e');
    } finally {
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

      if (imageData.isEmpty) {
        throw Exception('No image data captured');
      }

      _log.info('Processing image of size: ${imageData.length} bytes');
      final response = await processImage(imageBytes: imageData);
      await _handleResponseText(response);
    } catch (e) {
      _log.severe('Error processing image: $e');
      await _handleResponseText('Error processing image: $e');
    }
  }

  Future<void> _handleResponseText(String text) async {
    try {
      _pagination.clear();

      // Split text into lines and add to pagination
      final lines = text.split('\n');
      for (var line in lines) {
        if (line.trim().isNotEmpty) {
          _pagination.appendLine(line.trim());
        }
      }

      // Display first page
      final currentPage = _pagination.getCurrentPage();
      if (currentPage.isNotEmpty) {
        await frame!.sendMessage(
          0x0a,
          TxPlainText(text: currentPage.join('\n')).pack(),
        );
      } else {
        await frame!.sendMessage(
          0x0a,
          TxPlainText(text: 'No response received').pack(),
        );
      }

      // Auto-clear after 15 seconds
      _clearTimer?.cancel();
      _clearTimer = Timer(const Duration(seconds: 15), () async {
        try {
          await frame!.sendMessage(
            0x0a,
            TxPlainText(
              text:
                  '1-Tap: Record Audio\n2-Tap: Take Photo\n_______________\nReady to use!',
            ).pack(),
          );
        } catch (e) {
          _log.severe('Error clearing display: $e');
        }
      });
    } catch (e) {
      _log.severe('Error handling response text: $e');
    }
  }

  Uint8List _convertToWav(
    Uint8List rawAudio, {
    int sampleRate = 8000,
    int channels = 1,
    int bitDepth = 16,
  }) {
    try {
      int dataSize = rawAudio.length;
      int headerSize = 44;
      int fileSize = headerSize + dataSize - 8;

      final wavData = BytesBuilder();

      // RIFF Header
      wavData.add(Uint8List.fromList('RIFF'.codeUnits));
      wavData.add(_intToBytes(fileSize, 4));
      wavData.add(Uint8List.fromList('WAVE'.codeUnits));

      // Format chunk
      wavData.add(Uint8List.fromList('fmt '.codeUnits));
      wavData.add(_intToBytes(16, 4)); // PCM chunk size
      wavData.add(_intToBytes(1, 2)); // PCM format
      wavData.add(_intToBytes(channels, 2));
      wavData.add(_intToBytes(sampleRate, 4));
      wavData.add(
        _intToBytes(sampleRate * channels * (bitDepth ~/ 8), 4),
      ); // Byte rate
      wavData.add(_intToBytes(channels * (bitDepth ~/ 8), 2)); // Block align
      wavData.add(_intToBytes(bitDepth, 2));

      // Data chunk
      wavData.add(Uint8List.fromList('data'.codeUnits));
      wavData.add(_intToBytes(dataSize, 4));
      wavData.add(rawAudio);

      return wavData.toBytes();
    } catch (e) {
      _log.severe('Error converting to WAV: $e');
      rethrow;
    }
  }

  Uint8List _intToBytes(int value, int length) {
    final result = Uint8List(length);
    for (int i = 0; i < length; i++) {
      result[i] = (value >> (8 * i)) & 0xFF;
    }
    return result;
  }

  Future<void> logout() async {
    try {
      await onCancel();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
    } catch (e) {
      _log.severe('Error during logout: $e');
    }
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
                isConnected
                    ? (_isRecordingAudio
                        ? 'Recording Audio...'
                        : _isProcessingImage
                        ? 'Processing Image...'
                        : 'Connected to Frame')
                    : 'Tap to connect',
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
