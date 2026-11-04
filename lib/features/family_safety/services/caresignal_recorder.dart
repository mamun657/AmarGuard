import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'caresignal_api.dart';

enum CareSignalRecordingState { idle, recording, stopped, error }

abstract interface class CareSignalRecorderService {
  bool get isRecording;

  Future<bool> hasPermission();

  Future<bool> start({String path});

  Future<String> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class CareSignalRecorder implements CareSignalRecorderService {
  CareSignalRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<bool> hasPermission() async {
    if (!await _recorder.hasPermission()) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> start({String path = 'caresignal_recording.wav'}) async {
    if (_recording || await _recorder.isRecording()) {
      await cancel();
      return false;
    }
    if (!await _recorder.hasPermission()) {
      throw const CareSignalException(
        'microphone_permission_denied',
        'Microphone permission was denied.',
      );
    }
    final supported = await _recorder.isEncoderSupported(AudioEncoder.wav);
    if (!supported) {
      throw const CareSignalException(
        'microphone_format_unsupported',
        'This device cannot record the required audio format.',
      );
    }
    final outputPath = path == 'caresignal_recording.wav' || path.isEmpty
        ? '${Directory.systemTemp.path}${Platform.pathSeparator}caresignal_${DateTime.now().microsecondsSinceEpoch}.wav'
        : path;
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.mic,
            manageBluetooth: false,
          ),
        ),
        path: outputPath,
      );
      _recording = true;
      return true;
    } on CareSignalException {
      rethrow;
    } catch (error) {
      _recording = false;
      debugPrint('CareSignal recorder stage=start error=${error.runtimeType}');
      throw const CareSignalException(
        'microphone_start_failed',
        'The microphone could not be started. Check microphone permission and close other apps using the microphone.',
      );
    }
  }

  @override
  Future<String> stop() async {
    try {
      final path = await _recorder.stop();
      return path ?? '';
    } finally {
      _recording = false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      try {
        await _recorder.stop();
      } catch (error) {
        debugPrint(
          'CareSignal recorder stage=cancel error=${error.runtimeType}',
        );
      }
    }
    _recording = false;
  }

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

Future<bool> isEmptyRecording(File file) async {
  if (!file.existsSync()) return true;
  if (await file.length() <= 44) return true;
  return false;
}
