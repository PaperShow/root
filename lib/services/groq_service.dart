import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String defaultModel = 'llama-3.3-70b-versatile';

  /// >>> PROVIDE YOUR GROQ API KEY HERE <<<
  static const String apiKeyInCode = '';

  /// Sends a chat query to Groq Cloud REST API and returns text response.
  static Future<String> askGroq({
    required String prompt,
    String? apiKey,
    String? model,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final cleanKey = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : apiKeyInCode.trim();

    if (cleanKey.isEmpty) {
      return '[AI ERROR] Groq API key is missing.\n'
          'Please paste your Groq API key into lib/services/groq_service.dart (apiKeyInCode).';
    }

    try {
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content':
              'You are Root AI, a concise and highly intelligent terminal assistant integrated into a minimalist launcher. '
              'Provide clear, direct, accurate, and formatted text outputs. Keep answers well-structured for terminal display.',
        },
      ];

      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }

      messages.add({'role': 'user', 'content': prompt});

      final response = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Authorization': 'Bearer $cleanKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model ?? defaultModel,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString().trim();
        }
        return '[AI] Received empty response from Groq.';
      } else {
        final errJson = jsonDecode(response.body);
        final errMsg =
            errJson['error']?['message'] ?? 'HTTP ${response.statusCode}';
        return '[AI ERROR] Groq API Error ($response.statusCode): $errMsg';
      }
    } catch (e) {
      return '[AI ERROR] Failed to communicate with Groq: $e';
    }
  }
}
