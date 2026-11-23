import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/widgets/intro_carousel.dart';

void main() {
  /// English localizations for the static page-order tests.
  AppLocalizations en() => lookupAppLocalizations(const Locale('en'));

  group('IntroCarousel.startPageForSeenRevision', () {
    test('starts at the beginning when nothing has been seen', () {
      expect(IntroCarousel.startPageForSeenRevision(en(), 0), 0);
    });

    test('skips to the first page added in the next revision', () {
      // Revision 1 (the original tour) -> the Suggest Answers page (index 4)
      // was added in revision 2.
      expect(IntroCarousel.startPageForSeenRevision(en(), 1), 4);
    });

    test('starts at the beginning when the tour is up to date', () {
      expect(IntroCarousel.startPageForSeenRevision(en(), 2), 0);
    });
  });

  group('IntroCarousel', () {
    /// Wraps [IntroCarousel] in a MaterialApp so that
    /// [AppLocalizations] and [MediaQuery] are available — exactly as they
    /// would be inside the real app shell.
    Future<void> pumpCarousel(
      WidgetTester tester, {
      required Future<void> Function() onComplete,
      int initialPage = 0,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: IntroCarousel(onComplete: onComplete, initialPage: initialPage),
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

    testWidgets('opens on the requested page', (tester) async {
      await pumpCarousel(tester, onComplete: () async {}, initialPage: 4);
      await tester.pumpAndSettle();

      // The fifth page (Suggest Answers) is the last one, so the footer
      // already reads "Get Started" and the welcome page is not shown.
      expect(find.text('Suggest Answers'), findsOneWidget);
      expect(find.text('Welcome to Vote4It'), findsNothing);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
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

      // Page 3: submitting a question (not the last page anymore).
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Submit a Question'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);

      // Page 4 (last): suggesting answers — the footer reads "Get Started".
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Suggest Answers'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('Get Started calls onComplete', (tester) async {
      bool called = false;
      await pumpCarousel(tester, onComplete: () async => called = true);
      await tester.pumpAndSettle();

      // Walk to the last page.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

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
