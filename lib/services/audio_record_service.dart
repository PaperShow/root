import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum AudioRecordStatus {
  idle,
  recording,
  transcribing,
  error,
}

class AudioRecordService {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  int _recordSeconds = 0;
  String? _currentRecordingPath;
  AudioRecordStatus _status = AudioRecordStatus.idle;

  final StreamController<int> _durationController =
      StreamController<int>.broadcast();
  final StreamController<AudioRecordStatus> _statusController =
      StreamController<AudioRecordStatus>.broadcast();

  Stream<int> get durationStream => _durationController.stream;
  Stream<AudioRecordStatus> get statusStream => _statusController.stream;

  int get currentDurationSeconds => _recordSeconds;
  AudioRecordStatus get status => _status;
  bool get isRecording => _status == AudioRecordStatus.recording;

  /// Check and request microphone permission
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Start recording audio to a temporary file
  Future<bool> startRecording() async {
    try {
      if (_status == AudioRecordStatus.recording) {
        return true;
      }

      final hasPerm = await hasPermission();
      if (!hasPerm) {
        _setStatus(AudioRecordStatus.error);
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/voice_query_$timestamp.m4a';
      _currentRecordingPath = filePath;

      const recordConfig = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      );

      await _recorder.start(recordConfig, path: filePath);

      _recordSeconds = 0;
      _setStatus(AudioRecordStatus.recording);
      _durationController.add(0);

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordSeconds++;
        _durationController.add(_recordSeconds);
      });

      return true;
    } catch (e) {
      _setStatus(AudioRecordStatus.error);
      return false;
    }
  }

  /// Stop recording and return the path to the recorded audio file
  Future<String?> stopRecording() async {
    _timer?.cancel();
    _timer = null;

    if (_status != AudioRecordStatus.recording) {
      return null;
    }

    try {
      _setStatus(AudioRecordStatus.transcribing);
      final path = await _recorder.stop();
      final effectivePath = path ?? _currentRecordingPath;
      return effectivePath;
    } catch (e) {
      _setStatus(AudioRecordStatus.error);
      return null;
    }
  }

  /// Cancel recording and discard audio file
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;

    try {
      if (_status == AudioRecordStatus.recording) {
        await _recorder.stop();
      }
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}

    _recordSeconds = 0;
    _currentRecordingPath = null;
    _setStatus(AudioRecordStatus.idle);
  }

  void resetStatus() {
    _setStatus(AudioRecordStatus.idle);
    _recordSeconds = 0;
  }

  void _setStatus(AudioRecordStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    _timer?.cancel();
    _durationController.close();
    _statusController.close();
    _recorder.dispose();
  }
}
