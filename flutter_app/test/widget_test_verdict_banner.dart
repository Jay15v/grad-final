import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aegismind/widgets/verdict_banner.dart';

/// Wraps [widget] in the minimal scaffold required by Flutter widget tests.
Widget _wrap(Widget widget) => MaterialApp(home: Scaffold(body: widget));

void main() {
  group('VerdictBanner', () {
    testWidgets('test_consensus_shows_green', (tester) async {
      await tester.pumpWidget(_wrap(const VerdictBanner(verdict: 'CONSENSUS')));

      // Text label
      expect(find.text('Consensus'), findsOneWidget);

      // Icon emoji
      expect(find.text('✅'), findsOneWidget);

      // Green background container
      final container = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                const Color(0xFF16A34A)),
      );
      expect(container, isNotNull);
    });

    testWidgets('test_partial_shows_yellow', (tester) async {
      await tester.pumpWidget(_wrap(const VerdictBanner(verdict: 'PARTIAL')));

      expect(find.text('Partially Hallucinating'), findsOneWidget);
      expect(find.text('⚠️'), findsOneWidget);

      final container = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                const Color(0xFFCA8A04)),
      );
      expect(container, isNotNull);
    });

    testWidgets('test_disagreement_shows_red', (tester) async {
      await tester
          .pumpWidget(_wrap(const VerdictBanner(verdict: 'DISAGREEMENT')));

      expect(find.text('High Risk of Hallucination'), findsOneWidget);
      expect(find.text('🔴'), findsOneWidget);

      final container = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                const Color(0xFFDC2626)),
      );
      expect(container, isNotNull);
    });

    testWidgets('test_unknown_verdict_does_not_crash', (tester) async {
      // Should render without throwing
      await tester
          .pumpWidget(_wrap(const VerdictBanner(verdict: 'UNKNOWN')));

      // Widget tree exists and shows the raw verdict as label
      expect(find.text('UNKNOWN'), findsOneWidget);
    });
  });
}
