import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/widgets/intro_carousel.dart';

void main() {
  group('IntroCarousel', () {
    /// Wraps [IntroCarousel] in a MaterialApp so that
    /// [AppLocalizations] and [MediaQuery] are available — exactly as they
    /// would be inside the real app shell.
    Future<void> pumpCarousel(
      WidgetTester tester, {
      required Future<void> Function() onComplete,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: IntroCarousel(onComplete: onComplete),
        ),
      );
    }

    testWidgets('shows the welcome page and a skip button', (tester) async {
      await pumpCarousel(tester, onComplete: () async {});
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Vote4It'), findsOneWidget);
      expect(
        find.text('A quick tour of the core features to get you started.'),
        findsOneWidget,
      );
      expect(find.text('Skip'), findsOneWidget);
      // First page uses the "Next" action rather than "Get Started".
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('tapping Skip calls onComplete once', (tester) async {
      bool called = false;
      await pumpCarousel(tester, onComplete: () async => called = true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('advances through the pages on Next', (tester) async {
      await pumpCarousel(tester, onComplete: () async {});
      await tester.pumpAndSettle();

      // Page 1: voting.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Vote'), findsOneWidget);

      // Page 2: statistics.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Statistics'), findsOneWidget);

      // Page 3 (last): submitting — the footer now reads "Get Started".
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Submit a Question'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Get Started calls onComplete', (tester) async {
      bool called = false;
      await pumpCarousel(tester, onComplete: () async => called = true);
      await tester.pumpAndSettle();

      // Walk to the last page.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('skips multiple pages by swiping', (tester) async {
      await pumpCarousel(tester, onComplete: () async {});
      await tester.pumpAndSettle();

      // A wide right→left drag on the PageView jumps to the next page.
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Vote'), findsOneWidget);
    });
  });
}
