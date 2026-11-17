import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/auth_controller.dart';
import 'package:vote/controllers/configuration_controller.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/models/special_category.dart';
import 'package:vote/models/submission_models.dart';
import 'package:vote/pages/admin_submission_detail_page.dart';
import 'package:vote/services/admin_service.dart';
import 'package:vote/services/auth_middleware.dart';

/// Submission without a category and without answers, as a user may file it.
Submission _incompleteSubmission() {
  return Submission.fromJson(<String, dynamic>{
    'id': 7,
    'text': 'Who is going to win?',
    'category_id': null,
    'language': 'en',
    'min_age': 0,
    'created_at': '2026-08-24T10:00:00Z',
    'submission_status': 'pending',
    'answer_options': <dynamic>[],
  });
}

/// A submission an administrator has already approved.
Submission _approvedSubmission() {
  return Submission.fromJson(<String, dynamic>{
    'id': 7,
    'text': 'Who is going to win?',
    'category_id': 1,
    'language': 'en',
    'min_age': 16,
    'created_at': '2026-08-24T10:00:00Z',
    'submission_status': 'approved',
    'submitted_by': 'alice',
    'reviewed_by': 'bob',
    'answer_options': <dynamic>[],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AdminSubmissionDetailPage', () {
    testWidgets('shows a submission that has no category as uncategorized', (
      tester,
    ) async {
      await _pumpPage(tester);

      expect(find.text('Uncategorized'), findsOneWidget);
      expect(find.text('Who is going to win?'), findsOneWidget);
    });

    testWidgets('blocks approval while category and answers are missing', (
      tester,
    ) async {
      final _FakeAdminService admin = await _pumpPage(tester);

      await scrollToApprove(tester);

      expect(approveButton(tester).onPressed, isNull);
      expect(admin.approvals, isEmpty);
    });

    testWidgets('blocks approval when only one answer option would remain', (
      tester,
    ) async {
      final _FakeAdminService admin = await _pumpPage(tester);

      await pickCategory(tester, 'General');
      await enterAnswerOption(tester, 'Team A');
      await scrollToApprove(tester);

      // One option is not votable: an approved question is public and its
      // answers cannot be edited afterwards.
      expect(approveButton(tester).onPressed, isNull);
      expect(admin.approvals, isEmpty);
    });

    testWidgets('sends the completed category and answers on approval', (
      tester,
    ) async {
      final _FakeAdminService admin = await _pumpPage(tester);

      await pickCategory(tester, 'General');
      await enterAnswerOptions(tester, <String>['Team A', 'Team B']);
      await scrollToApprove(tester);
      expect(approveButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(admin.approvals.single.categoryId, 1);
      expect(admin.approvals.single.answerOptions, <String>[
        'Team A',
        'Team B',
      ]);
      expect(admin.approvals.single.minAge, 0);
    });

    testWidgets('tops up a submission that arrived with a single option', (
      tester,
    ) async {
      final _FakeAdminService admin = await _pumpPage(
        tester,
        answers: <String>['Yes'],
      );

      await pickCategory(tester, 'General');
      // The editor stays available while the question is short of options, and
      // one more is enough to complete it.
      await enterAnswerOption(tester, 'No');
      await scrollToApprove(tester);
      expect(approveButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Only the missing option is sent; the backend appends it to the one the
      // submitter provided.
      expect(admin.approvals.single.answerOptions, <String>['No']);
    });

    testWidgets('keeps the answers the submitter provided', (tester) async {
      final _FakeAdminService admin = await _pumpPage(
        tester,
        answers: <String>['Yes', 'No'],
      );

      await pickCategory(tester, 'Sports');
      await scrollToApprove(tester);

      // The editor is hidden; only the category is missing.
      expect(
        find.text('The submitter already provided enough answer options.'),
        findsOneWidget,
      );
      expect(approveButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(admin.approvals.single.categoryId, 2);
      expect(admin.approvals.single.answerOptions, isNull);
    });

    testWidgets('surfaces the backend message when approval fails', (
      tester,
    ) async {
      final _FakeAdminService admin = await _pumpPage(
        tester,
        approveFailure: const AdminException(
          'At least two answer options are required to approve a question',
          400,
        ),
      );

      await pickCategory(tester, 'General');
      await enterAnswerOptions(tester, <String>['Team A', 'Team B']);
      await scrollToApprove(tester);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(admin.approvals, hasLength(1));
      expect(
        find.text(
          'At least two answer options are required to approve a question',
        ),
        findsOneWidget,
      );
    });

    testWidgets('rejects the submission', (tester) async {
      final _FakeAdminService admin = await _pumpPage(tester);

      await scrollToApprove(tester);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(admin.rejections, 1);
      expect(admin.approvals, isEmpty);
    });

    testWidgets('shows a decided submission without further actions', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        submission: _approvedSubmission(),
        answers: <String>['Yes', 'No'],
      );

      // The review actions are replaced by a note once the question was
      // approved.
      expect(find.text('Approve'), findsNothing);
      expect(
        find.text('This submission has already been reviewed.'),
        findsOneWidget,
      );
    });

    testWidgets('logs the user out when the answers are unauthorized', (
      tester,
    ) async {
      final AuthController auth = _CategoriesAuthController();

      await _pumpPage(tester, answersStatus: 401, auth: auth);

      expect(auth.showLoginPage, isTrue);
    });

    testWidgets('explains when the answers cannot be loaded', (tester) async {
      await _pumpPage(tester, answersStatus: 500);

      expect(find.text('Server returned an error'), findsOneWidget);
    });

    testWidgets('survives an unexpected answer failure', (tester) async {
      await _pumpPage(tester, answersThrow: true);

      expect(find.byType(AdminSubmissionDetailPage), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });
}

/// Pumps the page and returns the [AdminService] the fake records calls in.
///
/// [answers] are returned by the answers endpoint; when non-empty the
/// submission is treated as already carrying answer options. [answersStatus]
/// and [answersThrow] stand in for the other answer-endpoint outcomes, and
/// [approveFailure] is thrown by the fake approval. [auth] can be supplied so
/// the caller can inspect it.
Future<_FakeAdminService> _pumpPage(
  WidgetTester tester, {
  Submission? submission,
  List<String> answers = const <String>[],
  int answersStatus = 404,
  bool answersThrow = false,
  AdminException? approveFailure,
  AuthController? auth,
}) async {
  final _FakeAdminService admin = _FakeAdminService(
    approveFailure: approveFailure,
  );
  final AuthController controller = auth ?? _CategoriesAuthController();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: controller),
        ChangeNotifierProvider<ConfigurationController>.value(
          value: ConfigurationController(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminSubmissionDetailPage(
          submission: submission ?? _incompleteSubmission(),
          adminService: admin,
          authMiddleware: _AnswersMiddleware(
            answers: answers,
            status: answersStatus,
            throws: answersThrow,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return admin;
}

/// Scrolls the approve button into view.
Future<void> scrollToApprove(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Approve'));
  await tester.pumpAndSettle();
}

/// The approve button of the page.
FilledButton approveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Approve'),
  );
}

/// Picks [label] in the category dropdown of the approval settings.
Future<void> pickCategory(WidgetTester tester, String label) async {
  final Finder dropdown = find.byType(DropdownButtonFormField<int>);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  // Tapping the field itself hits the button; the hint text inside its
  // decoration is not a hit target.
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Types [texts] into the answer-option inputs of the approval settings, adding
/// empty fields when the editor does not have enough of them yet.
///
/// The minimum-age input is a [TextFormField] as well, so the answer fields
/// start at index 1.
Future<void> enterAnswerOptions(WidgetTester tester, List<String> texts) async {
  // The editor starts with a single empty field.
  final Finder fields = find.byType(TextFormField);
  while (fields.evaluate().length - 1 < texts.length) {
    final Finder add = find.widgetWithText(OutlinedButton, 'Add answer option');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
  }
  for (int i = 0; i < texts.length; i++) {
    final Finder field = fields.at(i + 1);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, texts[i]);
    await tester.pumpAndSettle();
  }
}

/// Types [text] into the first answer-option input of the approval settings.
Future<void> enterAnswerOption(WidgetTester tester, String text) async {
  await enterAnswerOptions(tester, <String>[text]);
}

/// [AuthController] exposing the category list without a backend.
class _CategoriesAuthController extends AuthController {
  @override
  Map<int, String> get categories => <int, String>{1: 'General', 2: 'Sports'};
}

/// [AuthMiddleware] answering the answers endpoint of the submission.
class _AnswersMiddleware extends AuthMiddleware {
  _AnswersMiddleware({
    required this.answers,
    this.status = 404,
    this.throws = false,
  });

  final List<String> answers;

  /// Status returned for the answers endpoint; `200` when [answers] is set.
  final int status;

  /// Whether the request fails instead of returning a response.
  final bool throws;

  @override
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    if (throws) throw Exception('no route to host');
    if (!url.contains('/answers')) {
      return http.Response('{}', 404);
    }
    if (answers.isEmpty) {
      return http.Response('{}', status);
    }
    return http.Response(
      jsonEncode(
        answers
            .asMap()
            .entries
            .map(
              (entry) => <String, Object>{
                'id': entry.key + 1,
                'question_id': 7,
                'text': entry.value,
              },
            )
            .toList(),
      ),
      200,
    );
  }
}

/// [AdminService] recording the approvals and rejections it receives.
class _FakeAdminService extends AdminService {
  _FakeAdminService({this.approveFailure});

  /// Thrown by [approveQuestion] instead of returning the approved submission.
  final AdminException? approveFailure;

  final List<_Approval> approvals = <_Approval>[];
  int rejections = 0;

  @override
  Future<Submission> approveQuestion(
    int id, {
    int? minAge,
    SpecialCategory? specialCategory,
    int? categoryId,
    List<String>? answerOptions,
  }) async {
    approvals.add(
      _Approval(
        minAge: minAge,
        specialCategory: specialCategory,
        categoryId: categoryId,
        answerOptions: answerOptions,
      ),
    );
    final AdminException? failure = approveFailure;
    if (failure != null) throw failure;
    return Submission.fromJson(<String, dynamic>{
      'id': id,
      'text': 'Who is going to win?',
      'category_id': categoryId,
      'language': 'en',
      'min_age': minAge ?? 0,
      'created_at': '2026-08-24T10:00:00Z',
      'submission_status': 'approved',
    });
  }

  @override
  Future<Submission> rejectQuestion(int id) async {
    rejections++;
    return Submission.fromJson(<String, dynamic>{
      'id': id,
      'text': 'Who is going to win?',
      'category_id': null,
      'language': 'en',
      'min_age': 0,
      'created_at': '2026-08-24T10:00:00Z',
      'submission_status': 'rejected',
    });
  }
}

/// The arguments of one [AdminService.approveQuestion] call.
class _Approval {
  const _Approval({
    required this.minAge,
    required this.specialCategory,
    required this.categoryId,
    required this.answerOptions,
  });

  final int? minAge;
  final SpecialCategory? specialCategory;
  final int? categoryId;
  final List<String>? answerOptions;
}
