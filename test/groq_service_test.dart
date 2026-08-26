import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root/services/groq_service.dart';
import 'package:root/services/audio_record_service.dart';
import 'package:root/services/terminal_command_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'create') {
          return null;
        }
        if (methodCall.method == 'dispose') {
          return null;
        }
        if (methodCall.method == 'hasPermission') {
          return true;
        }
        return null;
      },
    );
  });

  group('GroqService Tests', () {
    test('Default models are properly configured', () {
      expect(GroqService.defaultModel, 'groq/compound');
      expect(GroqService.defaultAudioModel, 'whisper-large-v3');
      expect(GroqService.modelCompound, 'groq/compound');
      expect(GroqService.modelCompoundMini, 'groq/compound-mini');
      expect(GroqService.modelGptOss120b, 'openai/gpt-oss-120b');
      expect(GroqService.modelGptOss20b, 'openai/gpt-oss-20b');
    });

    test('Effective API key resolution', () {
      final customKey = GroqService.getEffectiveApiKey('gsk_custom_123');
      expect(customKey, 'gsk_custom_123');

      final defaultKey = GroqService.getEffectiveApiKey('');
      expect(defaultKey, isNotEmpty);
    });
  });

  group('AudioRecordService Tests', () {
    test('Initial state is idle and 0 duration', () {
      final service = AudioRecordService();
      expect(service.status, AudioRecordStatus.idle);
      expect(service.isRecording, false);
      expect(service.currentDurationSeconds, 0);
      service.dispose();
    });
  });

  group('TerminalCommandService Tests', () {
    test('Recognizes voice, mic, and model commands', () {
      final cmdService = TerminalCommandService();
      expect(cmdService.isCommand('voice'), true);
      expect(cmdService.isCommand('mic'), true);
      expect(cmdService.isCommand('rec'), true);
      expect(cmdService.isCommand('whisper'), true);
      expect(cmdService.isCommand('model compound'), true);
      expect(cmdService.isCommand('model mini'), true);
      expect(cmdService.isCommand('model gpt120'), true);
      expect(cmdService.isCommand('model gpt20'), true);
    });
  });
}
