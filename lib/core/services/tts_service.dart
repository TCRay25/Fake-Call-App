import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      // Set language to Bengali (Bangladesh) as required
      await _flutterTts.setLanguage("bn-BD");
      await _flutterTts.setPitch(0.85); // Authoritative boss tone
      await _flutterTts.setSpeechRate(0.5); // Natural conversational speed
      await _flutterTts.setVolume(1.0);
      _isInitialized = true;
      debugPrint("TtsService initialized successfully with language bn-BD.");
    } catch (e) {
      debugPrint("Failed to initialize TtsService: $e");
    }
  }

  /// Speak the provided dialogue text
  Future<void> speak(String text) async {
    try {
      if (!_isInitialized) {
        await _initTts();
      }
      debugPrint("TTS Speaking: $text");
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS speak error: $e");
    }
  }

  /// Stop any active speech playback
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      debugPrint("TTS speech stopped.");
    } catch (e) {
      debugPrint("TTS stop error: $e");
    }
  }
}

