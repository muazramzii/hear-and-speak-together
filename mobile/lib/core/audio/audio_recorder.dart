import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Why a recording could not be made. The UI maps these to specific,
/// actionable messages - "allow the microphone" is useful, "error" is not.
enum RecordingFailure { permissionDenied, unavailable, tooShort }

class RecordingException implements Exception {
  const RecordingException(this.failure);

  final RecordingFailure failure;
}

/// Captures a short spoken word.
///
/// Records 16 kHz mono PCM WAV because that is what the server's speech
/// recognition model expects; handing it a compressed format risks a worse
/// score for reasons that have nothing to do with the child's pronunciation.
class AudioRecorderService {
  AudioRecorderService(this._recorder);

  final AudioRecorder _recorder;

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  String? _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const RecordingException(RecordingFailure.permissionDenied);
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/attempt_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(_config, path: path);
      _currentPath = path;
    } on Exception {
      throw const RecordingException(RecordingFailure.unavailable);
    }
  }

  /// Stops and returns the file path, or throws if the clip is unusably short.
  Future<String> stop() async {
    final path = await _recorder.stop() ?? _currentPath;

    if (path == null) {
      throw const RecordingException(RecordingFailure.unavailable);
    }

    final file = File(path);
    // A WAV header alone is ~44 bytes, so anything at this size holds no
    // audio - usually a tap that registered as press-and-release.
    if (!file.existsSync() || await file.length() < 1024) {
      throw const RecordingException(RecordingFailure.tooShort);
    }

    return path;
  }

  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } on Exception {
      // Nothing useful to do; the temp file is cleaned up below.
    }
    await discard();
  }

  /// Deletes the recording. Called once the attempt has been uploaded, so
  /// children's audio does not accumulate on the device.
  Future<void> discard() async {
    final path = _currentPath;
    _currentPath = null;
    if (path == null) return;

    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // A leftover temp file is harmless; the OS clears the cache directory.
    }
  }

  Future<void> dispose() => _recorder.dispose();
}

final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService(AudioRecorder());
  ref.onDispose(service.dispose);
  return service;
});
