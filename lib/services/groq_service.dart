import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqAudioEndpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  /// Default chat completion model is groq/compound
  static const String defaultModel = 'groq/compound';

  /// Available chat models
  static const String modelCompound = 'groq/compound';
  static const String modelCompoundMini = 'groq/compound-mini';
  static const String modelGptOss120b = 'openai/gpt-oss-120b';
  static const String modelGptOss20b = 'openai/gpt-oss-20b';
  static const String modelLlama33 = 'llama-3.3-70b-versatile';

  /// Default audio transcription model
  static const String defaultAudioModel = 'whisper-large-v3';

  /// >>> PROVIDE YOUR GROQ API KEY HERE <<<
  static const String apiKeyInCode =
      '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';

  /// Helper to resolve the clean active API key
  static String getEffectiveApiKey(String? apiKey) {
    final key = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : apiKeyInCode.trim();
    return key;
  }

  /// Sends a chat query to Groq Cloud REST API and returns text response.
  static Future<String> askGroq({
    required String prompt,
    String? apiKey,
    String? model,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final cleanKey = getEffectiveApiKey(apiKey);

    if (cleanKey.isEmpty) {
      return '[AI ERROR] Groq API key is missing.\n'
          'Please set your Groq API key in Settings or with `setkey <gsk_...>` in the terminal.';
    }

    final selectedModel = (model != null && model.trim().isNotEmpty)
        ? model.trim()
        : defaultModel;

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
              'model': selectedModel,
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString().trim();
        }
        return '[AI] Received empty response from Groq.';
      } else {
        try {
          final errJson = jsonDecode(response.body);
          final errMsg =
              errJson['error']?['message'] ?? 'HTTP ${response.statusCode}';
          return '[AI ERROR] Groq API Error ($response.statusCode): $errMsg';
        } catch (_) {
          return '[AI ERROR] Groq API Error (${response.statusCode}): ${response.body}';
        }
      }
    } catch (e) {
      return '[AI ERROR] Failed to communicate with Groq: $e';
    }
  }

  /// Transcribes an audio file using Groq's Whisper API (whisper-large-v3).
  static Future<String> transcribeAudio({
    required String filePath,
    String? apiKey,
    String? model,
    String? language,
  }) async {
    final cleanKey = getEffectiveApiKey(apiKey);

    if (cleanKey.isEmpty) {
      return '[WHISPER ERROR] Groq API key is missing. Please set your Groq API key.';
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return '[WHISPER ERROR] Audio recording file not found at $filePath';
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_groqAudioEndpoint),
      );

      request.headers['Authorization'] = 'Bearer $cleanKey';

      request.fields['model'] = (model != null && model.trim().isNotEmpty)
          ? model.trim()
          : defaultAudioModel;

      request.fields['response_format'] = 'json';

      if (language != null && language.trim().isNotEmpty) {
        request.fields['language'] = language.trim();
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcribedText = data['text'];
        if (transcribedText != null &&
            transcribedText.toString().trim().isNotEmpty) {
          return transcribedText.toString().trim();
        }
        return '[WHISPER] No speech detected.';
      } else {
        try {
          final errJson = jsonDecode(response.body);
          final errMsg =
              errJson['error']?['message'] ?? 'HTTP ${response.statusCode}';
          return '[WHISPER ERROR] ($response.statusCode): $errMsg';
        } catch (_) {
          return '[WHISPER ERROR] (${response.statusCode}): ${response.body}';
        }
      }
    } catch (e) {
      return '[WHISPER ERROR] Failed to transcribe audio: $e';
    } finally {
      // Clean up temporary audio file after transcription
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }
}
