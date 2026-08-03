import 'package:flutter_test/flutter_test.dart';
import 'package:vote/models/submission_models.dart';

void main() {
  group('Submission.fromJson', () {
    const sampleJson = {
      'id': 42,
      'text': 'Should we adopt a new style guide?',
      'category_id': 3,
      'language': 'en',
      'min_age': 18,
      'created_at': '2025-06-15T10:30:00Z',
      'submission_status': 'pending',
      'submitted_by': 7,
      'reviewed_by': null,
      'answer_options': [
        {'id': 1, 'question_id': 42, 'text': 'Yes'},
        {'id': 2, 'question_id': 42, 'text': 'No'},
      ],
    };

    test('parses all fields including nested answerOptions', () {
      final submission = Submission.fromJson(sampleJson);

      expect(submission.id, 42);
      expect(submission.text, 'Should we adopt a new style guide?');
      expect(submission.categoryId, 3);
      expect(submission.language, 'en');
      expect(submission.minAge, 18);
      expect(submission.createdAt, '2025-06-15T10:30:00Z');
      expect(submission.submissionStatus, 'pending');
      expect(submission.submittedBy, 7);
      expect(submission.reviewedBy, isNull);
      expect(submission.answerOptions, hasLength(2));
      expect(submission.answerOptions![0].id, 1);
      expect(submission.answerOptions![0].text, 'Yes');
      expect(submission.answerOptions![1].id, 2);
      expect(submission.answerOptions![1].text, 'No');
    });

    test('fills missing optional fields with defaults', () {
      final submission = Submission.fromJson({
        'id': 1,
        'text': 'Minimal question',
        'category_id': 1,
        // language missing → defaults to 'en'
        // min_age missing → defaults to 0
        // created_at missing → defaults to ''
        // submission_status missing → defaults to 'pending'
        // submitted_by missing → defaults to null
        // reviewed_by missing → defaults to null
        // answer_options missing → defaults to null
      });

      expect(submission.language, 'en');
      expect(submission.minAge, 0);
      expect(submission.createdAt, '');
      expect(submission.submissionStatus, 'pending');
      expect(submission.submittedBy, isNull);
      expect(submission.reviewedBy, isNull);
      expect(submission.answerOptions, isNull);
    });

    test('handles null answer_options', () {
      final submission = Submission.fromJson({
        'id': 1,
        'text': 'No options question',
        'category_id': 1,
        'answer_options': null,
      });

      expect(submission.answerOptions, isNull);
    });

    test('handles empty answer_options list', () {
      final submission = Submission.fromJson({
        'id': 1,
        'text': 'Empty options question',
        'category_id': 1,
        'answer_options': [],
      });

      expect(submission.answerOptions, isEmpty);
    });

    test('preserves approved status', () {
      final submission = Submission.fromJson({
        'id': 1,
        'text': 'Approved question',
        'category_id': 1,
        'submission_status': 'approved',
      });

      expect(submission.isApproved, isTrue);
      expect(submission.isPending, isFalse);
      expect(submission.isRejected, isFalse);
    });

    test('preserves rejected status', () {
      final submission = Submission.fromJson({
        'id': 1,
        'text': 'Rejected question',
        'category_id': 1,
        'submission_status': 'rejected',
      });

      expect(submission.isRejected, isTrue);
      expect(submission.isPending, isFalse);
      expect(submission.isApproved, isFalse);
    });

    test('defaults to pending when status is unrecognised', () {
      final submission = Submission.fromJson({
        'id': 1,
        'text': 'Unknown status question',
        'category_id': 1,
        'submission_status': 'archived',
      });

      expect(submission.isPending, isFalse);
      expect(submission.isApproved, isFalse);
      expect(submission.isRejected, isFalse);
    });

    test('answerOptions are parsed from nested JSON objects', () {
      final submission = Submission.fromJson({
        'id': 1,
        'text': 'Question',
        'category_id': 1,
        'answer_options': [
          {'id': 10, 'question_id': 1, 'text': 'Option A'},
          {'id': 11, 'question_id': 1, 'text': 'Option B'},
          {'id': 12, 'question_id': 1, 'text': 'Option C'},
        ],
      });

      expect(submission.answerOptions, hasLength(3));
      expect(submission.answerOptions![0].questionId, 1);
      expect(submission.answerOptions![1].text, 'Option B');
      expect(submission.answerOptions![2].id, 12);
    });
  });

  group('Submission status getters', () {
    test('isPending returns true only for pending status', () {
      final pending = Submission.fromJson({
        'id': 1,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'pending',
      });
      final approved = Submission.fromJson({
        'id': 2,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'approved',
      });
      final rejected = Submission.fromJson({
        'id': 3,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'rejected',
      });

      expect(pending.isPending, isTrue);
      expect(approved.isPending, isFalse);
      expect(rejected.isPending, isFalse);
    });

    test('isApproved returns true only for approved status', () {
      final pending = Submission.fromJson({
        'id': 1,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'pending',
      });
      final approved = Submission.fromJson({
        'id': 2,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'approved',
      });
      final rejected = Submission.fromJson({
        'id': 3,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'rejected',
      });

      expect(pending.isApproved, isFalse);
      expect(approved.isApproved, isTrue);
      expect(rejected.isApproved, isFalse);
    });

    test('isRejected returns true only for rejected status', () {
      final pending = Submission.fromJson({
        'id': 1,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'pending',
      });
      final approved = Submission.fromJson({
        'id': 2,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'approved',
      });
      final rejected = Submission.fromJson({
        'id': 3,
        'text': 'Q',
        'category_id': 1,
        'submission_status': 'rejected',
      });

      expect(pending.isRejected, isFalse);
      expect(approved.isRejected, isFalse);
      expect(rejected.isRejected, isTrue);
    });
  });
}