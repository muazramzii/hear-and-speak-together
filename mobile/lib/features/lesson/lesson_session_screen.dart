import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../l10n/l10n.dart';
import '../../repositories/content_repository.dart';
import '../../theme/theme.dart';
import 'celebration/celebration_view.dart';
import 'learn/learn_stage_view.dart';
import 'intro/lesson_intro_view.dart';
import 'listen/listen_stage_view.dart';
import 'quiz/quiz_stage_view.dart';
import 'speak_stage_view.dart';

/// A lesson is no longer a single screen: this walks a child through one
/// lesson end to end - Intro, Learn, Listen, Speak, Quiz, then Celebration -
/// as nested state within one route, rather than as separate pushed screens.
/// Each stage still gets its own full `Scaffold`/`AppBar` (unchanged from
/// how they behaved as standalone screens), so this widget itself owns no
/// chrome of its own - only which stage is showing.
class LessonSessionScreen extends ConsumerStatefulWidget {
  const LessonSessionScreen({
    super.key,
    required this.lessonId,
    required this.languageCode,
  });

  final int lessonId;
  final String languageCode;

  @override
  ConsumerState<LessonSessionScreen> createState() =>
      _LessonSessionScreenState();
}

enum _LessonStage { intro, learn, listen, speak, quiz, celebration }

class _LessonSessionScreenState extends ConsumerState<LessonSessionScreen> {
  _LessonStage _stage = _LessonStage.intro;

  int _quizCorrect = 0;
  int _quizTotal = 0;
  int _pointsAwarded = 0;
  List<String> _newAchievements = const [];

  void _goTo(_LessonStage stage) => setState(() => _stage = stage);

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));

    return lessonAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  error is ApiException
                      ? error.message
                      : context.l10n.errorGeneric,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
      data: (lesson) {
        if (lesson.words.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(lesson.title)),
            body: Center(child: Text(context.l10n.learnNoWords)),
          );
        }

        return switch (_stage) {
          _LessonStage.intro => LessonIntroView(
            lesson: lesson,
            languageCode: widget.languageCode,
            onStart: () => _goTo(_LessonStage.learn),
          ),
          _LessonStage.learn => LearnStageView(
            words: lesson.words,
            languageCode: widget.languageCode,
            onComplete: () => _goTo(_LessonStage.listen),
          ),
          _LessonStage.listen => ListenStageView(
            words: lesson.words,
            languageCode: widget.languageCode,
            onComplete: () => _goTo(_LessonStage.speak),
          ),
          _LessonStage.speak => SpeakStageView(
            words: lesson.words,
            languageCode: widget.languageCode,
            onFinished: () => _goTo(_LessonStage.quiz),
          ),
          _LessonStage.quiz => QuizStageView(
            lessonId: widget.lessonId,
            languageCode: widget.languageCode,
            onFinished: ({
              required correct,
              required total,
              required pointsAwarded,
              required newAchievements,
            }) {
              setState(() {
                _quizCorrect = correct;
                _quizTotal = total;
                _pointsAwarded = pointsAwarded;
                _newAchievements = newAchievements;
                _stage = _LessonStage.celebration;
              });
            },
          ),
          _LessonStage.celebration => CelebrationView(
            lesson: lesson,
            languageCode: widget.languageCode,
            correct: _quizCorrect,
            total: _quizTotal,
            pointsAwarded: _pointsAwarded,
            newAchievements: _newAchievements,
          ),
        };
      },
    );
  }
}
