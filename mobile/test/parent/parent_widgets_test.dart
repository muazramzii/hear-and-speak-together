import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/features/parent/design/parent_theme.dart';
import 'package:hear_speak_together/features/parent/widgets/parent_widgets.dart';
import 'package:hear_speak_together/models/progress.dart';

Widget _wrap(Widget child, {bool dark = false}) {
  return MaterialApp(
    theme: dark ? ParentTheme.dark : ParentTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('ParentEmptyState shows the given message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ParentEmptyState(
          icon: Icons.history_rounded,
          message: "Start your child's first practice.",
        ),
      ),
    );

    expect(find.text("Start your child's first practice."), findsOneWidget);
  });

  testWidgets('MetricTile renders label, value and trend without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 160,
          child: MetricTile(
            label: 'Average score',
            value: '89%',
            trend: '+7% this week',
            trendPositive: true,
          ),
        ),
      ),
    );

    expect(find.text('Average score'), findsOneWidget);
    expect(find.text('89%'), findsOneWidget);
    expect(find.text('+7% this week'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'HeatBar prints the percentage next to the bar, not colour alone',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            child: HeatBar(
              label: 'Animals',
              value: 91,
              subtitle: '12 attempts',
            ),
          ),
        ),
      );

      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('91%'), findsOneWidget);
      expect(find.text('12 attempts'), findsOneWidget);
    },
  );

  testWidgets('PhonemeBar shows the phoneme, rate and example words', (
    tester,
  ) async {
    const stat = PhonemeStat(
      phoneme: 'l',
      frequency: 68,
      occurrences: 6,
      sampleSize: 9,
      examples: ['bola', 'belon'],
    );

    await tester.pumpWidget(
      _wrap(
        const SizedBox(width: 320, child: PhonemeBar(stat: stat, isWeak: true)),
      ),
    );

    expect(find.text('/l/'), findsOneWidget);
    expect(find.text('68%'), findsOneWidget);
    expect(find.text('bola'), findsOneWidget);
    expect(find.text('belon'), findsOneWidget);
  });

  testWidgets('AnalyticsCard adapts to dark mode without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AnalyticsCard(child: Text('Dark mode content')), dark: true),
    );

    expect(find.text('Dark mode content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ActivityTile shows a dash rather than a score for a silent attempt',
    (tester) async {
      final attempt = RecentAttempt(
        id: 1,
        word: 'cat',
        score: null,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(_wrap(ActivityTile(attempt: attempt)));

      expect(find.text('—'), findsOneWidget);
    },
  );
}
