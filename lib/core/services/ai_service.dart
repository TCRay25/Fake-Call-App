import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  // Provide your Gemini API Key here or pass via --dart-define=GEMINI_API_KEY=...
  String apiKey;

  AiService({
    this.apiKey = const String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
    ),
  });

  /// Generates dynamic, context-aware dialogue using Gemini 1.5 Flash
  Future<String> getInitialDialogue() async {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final currentTime = "$hour:$minute";

    final prompt =
        "Act as my boss. The current time is $currentTime. Keep it short and ask why I am late in Bengali or English.";

    // Fallback dialogue in case of missing API key or offline network errors
    final fallbackDialogue =
        "কই তুমি? এখন $currentTime বাজে, এখনো আসোনি কেন? অফিসে জলদি আসো!";

    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      debugPrint("Gemini API key not configured. Using realistic fallback dialogue.");
      return fallbackDialogue;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.trim().isNotEmpty) {
        return response.text!.trim();
      }
    } catch (e) {
      debugPrint("Error calling Gemini API: $e");
    }

    return fallbackDialogue;
  }
}
