import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/auth_controller.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/widgets/submit_question_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SubmitQuestionButton', () {
    testWidgets('is labelled after the action it offers', (tester) async {
      await pumpButton(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('New Question'), findsOneWidget);
    });

    testWidgets('asks guests to sign in instead of opening the dialog', (
      tester,
    ) async {
      await pumpButton(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to submit a question'), findsOneWidget);
      expect(find.text('Submit a Question'), findsNothing);
    });

    testWidgets('routes guests to the login page once they confirm', (
      tester,
    ) async {
      final AuthController auth = await pumpButton(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(auth.showLoginPage, isTrue);
    });

    testWidgets('keeps guests where they are when they cancel', (tester) async {
      final AuthController auth = await pumpButton(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(auth.showLoginPage, isFalse);
    });

    testWidgets('opens the submit dialog for signed-in users', (tester) async {
      await pumpButton(tester, authenticated: true);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Submit a Question'), findsOneWidget);
      expect(find.text('Sign in to submit a question'), findsNothing);
    });
  });
}

/// Pumps the button in a scaffold, as both pages embed it, and returns the
/// backing [AuthController].
Future<AuthController> pumpButton(
  WidgetTester tester, {
  bool authenticated = false,
}) async {
  final AuthController auth = authenticated
      ? _SignedInAuthController()
      : _GuestAuthController();

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(floatingActionButton: SubmitQuestionButton()),
      ),
    ),
  );

  return auth;
}

/// Signed-out [AuthController]; the dialog's category list stays empty because
/// no backend is contacted.
class _GuestAuthController extends AuthController {}

/// Signed-in [AuthController] with a category mapping, as the app would have it
/// after a login.
class _SignedInAuthController extends AuthController {
  @override
  bool get isAuthenticated => true;

  @override
  Map<int, String> get categories => <int, String>{1: 'General'};
}
