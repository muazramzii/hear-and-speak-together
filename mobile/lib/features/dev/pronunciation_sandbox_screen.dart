import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_recorder.dart';
import '../../core/network/api_exception.dart';
import '../../models/pronunciation_debug_result.dart';
import '../../repositories/dev_repository.dart';

/// Phase 2: a developer-only sandbox for exercising the real recognition and
/// pronunciation-scoring pipeline end to end.
///
/// This screen is never shown to a child. It exists purely to validate
/// accuracy and performance, so nothing here is summarised or prettied up -
/// every raw and normalised value the backend returns is shown as-is. See
/// docs/pronunciation-engine.md.
class PronunciationSandboxScreen extends ConsumerStatefulWidget {
  const PronunciationSandboxScreen({super.key});

  @override
  ConsumerState<PronunciationSandboxScreen> createState() =>
      _PronunciationSandboxScreenState();
}

enum _SandboxStage { idle, listening, processing, done, error }

class _PronunciationSandboxScreenState
    extends ConsumerState<PronunciationSandboxScreen> {
  final _referenceController = TextEditingController(text: 'elephant');
  String _language = 'en';
  _SandboxStage _stage = _SandboxStage.idle;
  PronunciationDebugResult? _result;
  String? _errorMessage;
  Map<String, dynamic>? _testWords;

  @override
  void initState() {
    super.initState();
    ref
        .read(devRepositoryProvider)
        .fetchTestWords()
        .then((words) => setState(() => _testWords = words))
        .catchError((_) {
          // The picker is a convenience; typing a word by hand still works
          // if this account cannot reach the endpoint.
        });
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    setState(() {
      _stage = _SandboxStage.listening;
      _errorMessage = null;
    });

    try {
      await ref.read(audioRecorderProvider).start();
    } on RecordingException catch (error) {
      setState(() {
        _stage = _SandboxStage.error;
        _errorMessage = 'Recording failed: ${error.failure.name}';
      });
    }
  }

  Future<void> _stopAndSubmit() async {
    final recorder = ref.read(audioRecorderProvider);
    String path;
    try {
      path = await recorder.stop();
    } on RecordingException catch (error) {
      setState(() {
        _stage = _SandboxStage.error;
        _errorMessage = 'Recording failed: ${error.failure.name}';
      });
      return;
    }

    setState(() => _stage = _SandboxStage.processing);

    try {
      final result = await ref
          .read(devRepositoryProvider)
          .debugEvaluate(
            reference: _referenceController.text.trim(),
            language: _language,
            audioPath: path,
          );
      setState(() {
        _stage = _SandboxStage.done;
        _result = result;
      });
    } on ApiException catch (error) {
      setState(() {
        _stage = _SandboxStage.error;
        _errorMessage = '${error.message} (${error.statusCode})';
      });
    } finally {
      await recorder.discard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pronunciation Sandbox (dev only)')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _wordPicker(),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference word',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ms', label: Text('Bahasa Melayu')),
                ],
                selected: {_language},
                onSelectionChanged:
                    (selection) => setState(() => _language = selection.first),
              ),
              const SizedBox(height: 20),
              _recordButton(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              if (_result != null) _ResultDump(result: _result!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wordPicker() {
    final words = _testWords;
    if (words == null) return const SizedBox.shrink();

    final spec = words[_language] as Map<String, dynamic>?;
    final correct = (spec?['words'] as List?)?.cast<String>() ?? const [];
    final mispronounced =
        (spec?['mispronunciations'] as Map?)?.cast<String, dynamic>() ??
        const {};

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final word in correct) _wordChip(word),
        for (final entry in mispronounced.entries)
          _wordChip(entry.value as String, label: '${entry.value} (wrong)'),
      ],
    );
  }

  Widget _wordChip(String word, {String? label}) {
    return ActionChip(
      label: Text(label ?? word),
      onPressed: () => setState(() => _referenceController.text = word),
    );
  }

  Widget _recordButton() {
    final listening = _stage == _SandboxStage.listening;
    final processing = _stage == _SandboxStage.processing;

    return FilledButton.icon(
      onPressed: processing ? null : (listening ? _stopAndSubmit : _record),
      icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
      label: Text(
        processing ? 'Processing...' : (listening ? 'Stop & submit' : 'Record'),
      ),
    );
  }
}

/// A plain, unstyled dump of every field the backend returned. This is
/// deliberately not a polished result screen - see the module docstring.
class _ResultDump extends StatelessWidget {
  const _ResultDump({required this.result});

  final PronunciationDebugResult result;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');

    final lines = <String>[
      'attempt_id: ${result.attemptId}',
      'reference: ${result.reference}',
      'recognized: ${result.recognized}',
      'language: ${result.language}',
      'heard_speech: ${result.heardSpeech}',
      '',
      '-- whisper --',
      'text: ${result.whisper.text}',
      'confidence: ${result.whisper.confidence}',
      '',
      '-- performance --',
      'recording_duration_seconds: ${result.performance.recordingDurationSeconds}',
      'whisper_inference_ms: ${result.performance.whisperInferenceMs}',
      'phoneme_analysis_ms: ${result.performance.phonemeAnalysisMs}',
      'total_processing_ms: ${result.performance.totalProcessingMs}',
    ];

    final phoneme = result.phoneme;
    if (phoneme != null) {
      lines.addAll([
        '',
        '-- phoneme --',
        'expected: ${phoneme.expected}',
        'recognized: ${phoneme.recognized}',
        'distance: ${phoneme.distance}',
      ]);
    }

    final assessment = result.assessment;
    if (assessment != null) {
      lines.addAll([
        '',
        '-- assessment --',
        'similarity: ${assessment.similarity}',
        'confidence: ${assessment.confidence}',
        'completeness: ${assessment.completeness}',
        'final_score: ${assessment.finalScore}',
        'error_type: ${assessment.errorType}',
        'errors:',
        for (final error in assessment.errors)
          '  - ${error.type} (expected=${error.expected}, detected=${error.detected})',
      ]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(lines.join('\n'), style: mono),
    );
  }
}
