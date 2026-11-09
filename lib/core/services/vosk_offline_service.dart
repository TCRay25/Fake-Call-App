import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

class VoskOfflineService {
  VoskFlutterPlugin? _voskPlugin;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  VoskFlutterPlugin get _vosk {
    return _voskPlugin ??= VoskFlutterPlugin.instance();
  }

  bool _isListening = false;
  bool _isModelLoaded = false;
  DateTime? _lastTriggerTime;

  bool get isListening => _isListening;
  bool get isModelLoaded => _isModelLoaded;

  /// Default model asset path declared in pubspec.yaml
  static const String defaultModelPath = 'assets/models/vosk-model/';

  /// Default trigger phrases in English and Bengali transliteration
  final List<String> triggerWords = const [
    'tara ache',
    'amar tara ache',
    'have to go',
    'i have to go',
    'got to go',
    'need to leave',
    'emergency',
  ];

  /// Initialize and load the offline Vosk speech recognition model
  Future<bool> initModel({String modelPath = defaultModelPath}) async {
    if (_isModelLoaded && _model != null) return true;

    try {
      debugPrint("Loading Vosk offline model from: $modelPath");
      String loadedModelPath;
      try {
        loadedModelPath = await ModelLoader().loadFromAssets(modelPath);
      } catch (e) {
        debugPrint("Asset loading error (might be raw directory): $e");
        loadedModelPath = modelPath;
      }
      _model = await _vosk.createModel(loadedModelPath);
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );
      _isModelLoaded = true;
      debugPrint("Vosk offline model successfully loaded.");
      return true;
    } catch (e) {
      debugPrint("Failed to load Vosk model from $modelPath: $e");
      debugPrint(
        "Tip: Please place your offline Vosk model (e.g., small-en or small-bn) "
        "inside assets/models/vosk-model/ and ensure it is declared in pubspec.yaml.",
      );
      _isModelLoaded = false;
      return false;
    }
  }

  /// Start continuous background listening and trigger rescue call on trigger phrases
  Future<void> startListening(Function onTrigger) async {
    if (_isListening) {
      debugPrint("Vosk offline service is already active.");
      return;
    }

    if (!_isModelLoaded || _recognizer == null) {
      final success = await initModel();
      if (!success) {
        throw Exception(
          "Vosk model could not be loaded. Place offline model in assets/models/vosk-model/.",
        );
      }
    }

    try {
      _speechService = await _vosk.initSpeechService(_recognizer!);

      // Listen to partial speech recognition results in real-time
      _speechService!.onPartial().listen((partialJson) {
        _handleRecognitionResult(partialJson, onTrigger);
      });

      // Listen to final recognized speech sentences
      _speechService!.onResult().listen((resultJson) {
        _handleRecognitionResult(resultJson, onTrigger);
      });

      await _speechService!.start();
      _isListening = true;
      debugPrint("Vosk offline listening started successfully.");
    } catch (e) {
      _isListening = false;
      debugPrint("Error starting Vosk speech service: $e");
      rethrow;
    }
  }

  /// Parses the recognized JSON and checks for trigger words with debounce protection
  void _handleRecognitionResult(String jsonString, Function onTrigger) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final String recognizedText =
          (data['text'] ?? data['partial'] ?? '').toString().toLowerCase();

      if (recognizedText.trim().isEmpty) return;

      debugPrint("Vosk recognized speech: \"$recognizedText\"");

      for (final trigger in triggerWords) {
        if (recognizedText.contains(trigger)) {
          final now = DateTime.now();
          // Debounce: prevent multiple call triggers within 10 seconds
          if (_lastTriggerTime != null &&
              now.difference(_lastTriggerTime!).inSeconds < 10) {
            debugPrint("Trigger '$trigger' detected but debounced (recent call in progress).");
            return;
          }

          _lastTriggerTime = now;
          debugPrint(">>> TRIGGER DETECTED: '$trigger'! Launching fake call rescue! <<<");
          onTrigger();
          break;
        }
      }
    } catch (e) {
      debugPrint("Error parsing Vosk recognition output: $e");
    }
  }

  /// Stop listening service
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      if (_speechService != null) {
        await _speechService!.stop();
      }
      _isListening = false;
      debugPrint("Vosk listening service stopped.");
    } catch (e) {
      debugPrint("Error stopping Vosk service: $e");
    }
  }

  /// Release resources
  Future<void> dispose() async {
    await stopListening();
    _speechService?.dispose();
    _recognizer?.dispose();
    _speechService = null;
    _recognizer = null;
    _model = null;
    _isModelLoaded = false;
  }
}
