import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/auth_controller.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/models/submission_models.dart';
import 'package:vote/services/submission_service.dart';
import 'package:vote/utils/constants.dart';
import 'package:vote/widgets/create_question_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The dialogs in these tests never reach the backend, but the token
    // storage behind the auth controller expects a preferences mock.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('showCreateQuestionDialog', () {
    testWidgets('asks for a question and offers a category and answers', (
      tester,
    ) async {
      await pumpDialog(tester);

      expect(find.text('Submit a Question'), findsOneWidget);
      expect(find.text('Question'), findsOneWidget);
      expect(find.text('Answer options'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Question text plus the two initial answer options.
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('marks the category and the answer options as optional', (
      tester,
    ) async {
      await pumpDialog(tester);

      expect(find.text('Category (optional)'), findsOneWidget);
      expect(find.textContaining('Optional'), findsWidgets);
    });

    testWidgets('lists the categories of the auth controller', (tester) async {
      await pumpDialog(tester);

      await openCategoryDropdown(tester);

      expect(find.text('General').last, findsOneWidget);
      expect(find.text('Sports').last, findsOneWidget);
    });

    testWidgets('explains when no categories are available', (tester) async {
      await pumpDialog(tester, categories: <int, String>{});

      expect(find.text('No categories available'), findsOneWidget);
    });

    testWidgets('offers filing without a category', (tester) async {
      await pumpDialog(tester);

      // The default selection files the question without a category.
      expect(find.text('No category'), findsOneWidget);

      await openCategoryDropdown(tester);

      expect(find.text('No category'), findsWidgets);
    });

    testWidgets('requires only the question text', (tester) async {
      await pumpDialog(tester);

      await tapSubmit(tester);

      // Only the question text is mandatory; the category and the answer
      // options may be left out.
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('files the question without category and answer options', (
      tester,
    ) async {
      final _FakeSubmissionService service = _FakeSubmissionService();
      await pumpDialog(tester, submissionService: service);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Who is going to win?',
      );
      await tapSubmit(tester);

      expect(service.submissions.single.categoryId, isNull);
      expect(service.submissions.single.answerOptions, isEmpty);
      expect(find.text('Submit a Question'), findsNothing);
    });

    testWidgets('removes every answer option', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.byTooltip('Remove answer option').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove answer option').first);
      await tester.pumpAndSettle();

      // Only the question text field is left.
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Add answer option'), findsOneWidget);
    });

    testWidgets('adds and removes answer options', (tester) async {
      await pumpDialog(tester);

      final Finder addButton = find.text('Add answer option');
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(4));

      await tester.tap(find.byTooltip('Remove answer option').first);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('caps the answer options at the backend limit', (tester) async {
      await pumpDialog(tester);

      final Finder addButton = find.text('Add answer option');
      for (int option = 2; option < kMaxAnswerOptions; option++) {
        // The dialog scrolls, so the button has to be brought into view first.
        await tester.ensureVisible(addButton);
        await tester.pumpAndSettle();
        await tester.tap(addButton);
        await tester.pump();
      }

      expect(find.byType(TextFormField), findsNWidgets(kMaxAnswerOptions + 1));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Add answer option'),
            )
            .onPressed,
        isNull,
        reason: 'the add button must be disabled once the limit is reached',
      );
    });

    testWidgets('closes on cancel without submitting', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Submit a Question'), findsNothing);
    });

    group('submitting', () {
      testWidgets('confirms the submission and reports back', (tester) async {
        int reloads = 0;
        await pumpDialog(
          tester,
          submissionService: _FakeSubmissionService(),
          onSubmitted: () => reloads++,
        );
        await fillInQuestion(tester);

        await tapSubmit(tester);

        expect(find.text('Question submitted for review'), findsOneWidget);
        expect(find.text('Submit a Question'), findsNothing);
        expect(reloads, 1);
      });

      testWidgets('sends the question together with its answer options', (
        tester,
      ) async {
        final _FakeSubmissionService service = _FakeSubmissionService();
        await pumpDialog(tester, submissionService: service);
        await fillInQuestion(tester, text: 'Who is going to win?');
        await tester.enterText(find.byType(TextFormField).at(1), 'Team A');

        await tapSubmit(tester);

        expect(service.submissions.single.text, 'Who is going to win?');
        expect(service.submissions.single.categoryId, 1);
        expect(service.submissions.single.answerOptions, <String>['Team A']);
      });

      testWidgets('logs the user out when the session expired', (tester) async {
        final AuthController auth = await pumpDialog(
          tester,
          submissionService: _FakeSubmissionService(
            failure: const SubmissionException('Unauthorized', 401),
          ),
        );
        await fillInQuestion(tester);

        await tapSubmit(tester);

        expect(find.text('Submit a Question'), findsNothing);
        expect(auth.showLoginPage, isTrue);
      });

      testWidgets('shows the message of a rejected submission', (tester) async {
        await pumpDialog(
          tester,
          submissionService: _FakeSubmissionService(
            failure: const SubmissionException('Category is read-only', 422),
          ),
        );
        await fillInQuestion(tester);

        await tapSubmit(tester);

        expect(find.text('Category is read-only'), findsOneWidget);
        expect(find.text('Submit a Question'), findsOneWidget);
      });

      testWidgets('explains an unexpected failure', (tester) async {
        await pumpDialog(
          tester,
          submissionService: _FakeSubmissionService(
            failure: StateError('connection reset'),
          ),
        );
        await fillInQuestion(tester);

        await tapSubmit(tester);

        expect(find.text('Failed to submit the question'), findsOneWidget);
        expect(find.text('Submit a Question'), findsOneWidget);
      });
    });
  });
}

/// Pumps a host screen with a button that opens the dialog and taps it.
///
/// [categories] is the category mapping the dialog reads from the
/// [AuthController].
Future<AuthController> pumpDialog(
  WidgetTester tester, {
  Map<int, String> categories = const <int, String>{1: 'General', 2: 'Sports'},
  SubmissionService? submissionService,
  VoidCallback? onSubmitted,
}) async {
  final AuthController auth = _DialogAuthController(categories);

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
                onPressed: () => showCreateQuestionDialog(
                  context,
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

/// Fills in a valid question with a single answer option so the dialog can be
/// submitted.
Future<void> fillInQuestion(
  WidgetTester tester, {
  String text = 'Who is going to win?',
}) async {
  await selectCategory(tester, 'General');
  await tester.enterText(find.byType(TextFormField).first, text);
  await tester.enterText(find.byType(TextFormField).at(1), 'Team A');
}

/// Taps the dialog's submit button.
Future<void> tapSubmit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
  await tester.pumpAndSettle();
}

/// Opens the category dropdown of the dialog.
Future<void> openCategoryDropdown(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
}

/// Picks [label] in the category dropdown of the dialog.
Future<void> selectCategory(WidgetTester tester, String label) async {
  await openCategoryDropdown(tester);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// [AuthController] with a fixed category mapping.
///
/// Only the categories the dialog reads are provided; everything else keeps the
/// default (signed-out) state so no backend is contacted.
class _DialogAuthController extends AuthController {
  _DialogAuthController(this._categories);

  final Map<int, String> _categories;

  @override
  Map<int, String> get categories => _categories;
}

/// [SubmissionService] recording the submissions the dialog sends.
///
/// [failure] is thrown instead of returning a created submission, standing in
/// for a rejected request or an unexpected error.
class _FakeSubmissionService extends SubmissionService {
  _FakeSubmissionService({this.failure});

  final Object? failure;

  final List<_SubmittedQuestion> submissions = <_SubmittedQuestion>[];

  @override
  Future<Submission> submitQuestion({
    required String text,
    int? categoryId,
    required String language,
    List<String> answerOptions = const <String>[],
  }) async {
    submissions.add(
      _SubmittedQuestion(
        text: text,
        categoryId: categoryId,
        language: language,
        answerOptions: answerOptions,
      ),
    );
    final Object? error = failure;
    if (error != null) throw error;
    return Submission(
      id: 1,
      text: text,
      categoryId: categoryId,
      language: language,
      minAge: 0,
      createdAt: '2024-01-01T00:00:00Z',
      submissionStatus: 'pending',
      answerOptions: <AnswerOption>[],
    );
  }
}

/// The arguments of one [SubmissionService.submitQuestion] call.
class _SubmittedQuestion {
  const _SubmittedQuestion({
    required this.text,
    required this.categoryId,
    required this.language,
    required this.answerOptions,
  });

  final String text;
  final int? categoryId;
  final String language;
  final List<String> answerOptions;
}
