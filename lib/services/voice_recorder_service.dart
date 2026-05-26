import 'dart:async';
import 'dart:io';

import 'package:cnattendance/services/chat_media_upload_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecordingResult {
  final String path;
  final Duration duration;
  final String extension;
  final String mimeType;

  const VoiceRecordingResult({
    required this.path,
    required this.duration,
    required this.extension,
    required this.mimeType,
  });
}

class VoiceRecorderService {
  final AudioRecorder _recorder;
  DateTime? _startedAt;
  String? _activePath;

  VoiceRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String> start() async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _startedAt = DateTime.now();
    _activePath = path;

    debugPrint('[VOICE_RECORD] selected file path=$path');
    debugPrint('[VOICE_RECORD] extension=m4a');
    debugPrint(
      '[VOICE_RECORD] mime type=${ChatMediaUploadService.mimeTypeForPath(path, mediaType: 'voice')}',
    );

    return path;
  }

  Future<VoiceRecordingResult?> stop() async {
    final path = await _recorder.stop();
    final startedAt = _startedAt;
    _startedAt = null;
    _activePath = null;

    if (path == null || path.trim().isEmpty) {
      return null;
    }

    final duration = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);
    final extension = _extensionFromPath(path);
    final mimeType = ChatMediaUploadService.mimeTypeForPath(
      path,
      mediaType: 'voice',
    );

    debugPrint('[VOICE_RECORD] selected file path=$path');
    debugPrint('[VOICE_RECORD] extension=$extension');
    debugPrint('[VOICE_RECORD] mime type=$mimeType');

    return VoiceRecordingResult(
      path: path,
      duration: duration,
      extension: extension,
      mimeType: mimeType,
    );
  }

  Future<void> cancel() async {
    final path = _activePath;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    _startedAt = null;
    _activePath = null;

    if (path == null || path.trim().isEmpty) {
      return;
    }

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> delete(String path) async {
    if (path.trim().isEmpty) {
      return;
    }

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> dispose() => _recorder.dispose();

  static String _extensionFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1);
  }
}
