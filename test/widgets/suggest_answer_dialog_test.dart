import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/auth_controller.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/models/submission_models.dart';
import 'package:vote/services/submission_service.dart';
import 'package:vote/widgets/suggest_answer_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The dialogs in these tests never reach the backend, but the token
    // storage behind the auth controller expects a preferences mock.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('showSuggestAnswerDialog', () {
    testWidgets('shows the question and asks for an answer', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Suggest an Answer'), findsOneWidget);
      // The question is shown read-only so the user knows what they answer.
      expect(find.text('Who is going to win?'), findsOneWidget);
      expect(find.text('Your answer'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('requires a non-empty answer', (tester) async {
      await pumpDialog(tester);

      await tapSubmit(tester);

      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('submits the trimmed answer to the question', (tester) async {
      final _FakeSubmissionService service = _FakeSubmissionService();
      await pumpDialog(tester, submissionService: service);

      await tester.enterText(find.byType(TextFormField), '  Team C  ');
      await tapSubmit(tester);

      expect(service.calls.single.questionId, 7);
      expect(service.calls.single.text, 'Team C');
      // The dialog closes on success.
      expect(find.text('Suggest an Answer'), findsNothing);
    });

    testWidgets('shows the success snackbar and reloads', (tester) async {
      final _FakeSubmissionService service = _FakeSubmissionService();
      var reloaded = false;
      await pumpDialog(
        tester,
        submissionService: service,
        onSubmitted: () => reloaded = true,
      );

      await tester.enterText(find.byType(TextFormField), 'Team C');
      await tapSubmit(tester);

      expect(
        find.text('Answer suggestion submitted for review'),
        findsOneWidget,
      );
      expect(reloaded, isTrue);
    });

    testWidgets('shows the backend error message verbatim', (tester) async {
      final _FakeSubmissionService service = _FakeSubmissionService(
        failure: const SubmissionException('Question not found', 404),
      );
      await pumpDialog(tester, submissionService: service);

      await tester.enterText(find.byType(TextFormField), 'Team C');
      await tapSubmit(tester);

      expect(find.text('Question not found'), findsOneWidget);
      // The dialog stays open so the user can correct the input.
      expect(find.text('Suggest an Answer'), findsOneWidget);
    });

    testWidgets('logs out on 401', (tester) async {
      final _FakeSubmissionService service = _FakeSubmissionService(
        failure: const SubmissionException('Unauthorized', 401),
      );
      final AuthController auth = await pumpDialog(
        tester,
        submissionService: service,
      );

      await tester.enterText(find.byType(TextFormField), 'Team C');
      await tapSubmit(tester);

      expect(auth.showLoginPage, isTrue);
    });

    testWidgets('shows a generic error for unexpected failures', (
      tester,
    ) async {
      final _FakeSubmissionService service = _FakeSubmissionService(
        failure: Exception('boom'),
      );
      await pumpDialog(tester, submissionService: service);

      await tester.enterText(find.byType(TextFormField), 'Team C');
      await tapSubmit(tester);

      expect(
        find.text('Failed to submit the answer suggestion'),
        findsOneWidget,
      );
    });

    testWidgets('closes without submitting on cancel', (tester) async {
      final _FakeSubmissionService service = _FakeSubmissionService();
      await pumpDialog(tester, submissionService: service);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.calls, isEmpty);
      expect(find.text('Suggest an Answer'), findsNothing);
    });
  });
}

/// Opens the suggest-answer dialog for question 7 and returns the
/// [AuthController] it reads.
Future<AuthController> pumpDialog(
  WidgetTester tester, {
  SubmissionService? submissionService,
  VoidCallback? onSubmitted,
}) async {
  final AuthController auth = _DialogAuthController();

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSuggestAnswerDialog(
                  context,
                  questionId: 7,
                  questionText: 'Who is going to win?',
                  submissionService: submissionService,
                  onSubmitted: onSubmitted,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return auth;
}

/// Taps the dialog's submit button.
Future<void> tapSubmit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
  await tester.pumpAndSettle();
}

/// [AuthController] that keeps the default (signed-in) state so no backend is
/// contacted; only the logout behaviour the dialog triggers is observed.
class _DialogAuthController extends AuthController {}

/// [SubmissionService] recording the answer suggestions the dialog sends.
///
/// [failure] is thrown instead of returning a created submission, standing in
/// for a rejected request or an unexpected error.
class _FakeSubmissionService extends SubmissionService {
  _FakeSubmissionService({this.failure});

  final Object? failure;

  final List<_SubmittedAnswer> calls = <_SubmittedAnswer>[];

  @override
  Future<AnswerSubmission> submitAnswerOption({
    required int questionId,
    required String text,
  }) async {
    calls.add(_SubmittedAnswer(questionId: questionId, text: text));
    final Object? error = failure;
    if (error != null) throw error;
    return AnswerSubmission(
      id: 12,
      questionId: questionId,
      questionText: 'Who is going to win?',
      text: text,
      language: 'en',
      submissionStatus: 'pending',
      createdAt: '2026-08-24T10:00:00Z',
    );
  }
}

/// The arguments of one [SubmissionService.submitAnswerOption] call.
class _SubmittedAnswer {
  const _SubmittedAnswer({required this.questionId, required this.text});

  final int questionId;
  final String text;
}
