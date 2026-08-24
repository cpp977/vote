import 'package:flutter_test/flutter_test.dart';
import 'package:vote/models/answer_stats.dart';
import 'package:vote/models/auth_models.dart';
import 'package:vote/models/question.dart';
import 'package:vote/models/special_category.dart';
import 'package:vote/utils/constants.dart';

void main() {
  group('Question.fromJson', () {
    test('parses all fields when present', () {
      final question = Question.fromJson({
        'id': 1,
        'text': 'Is this a good question?',
        'category_id': 2,
        'category_name': 'General',
        'language': 'de',
      });

      expect(question.id, 1);
      expect(question.text, 'Is this a good question?');
      expect(question.categoryId, 2);
      expect(question.categoryName, 'General');
      expect(question.language, 'de');
    });

    test('parses special_category when present', () {
      final question = Question.fromJson({
        'id': 8,
        'text': 'Sensitive question',
        'category_id': 1,
        'category_name': 'Health',
        'language': 'en',
        'special_category': 'health',
      });

      expect(question.specialCategory, SpecialCategory.health);
    });

    test('falls back to none when special_category is missing', () {
      final question = Question.fromJson({
        'id': 1,
        'text': 'Regular question',
        'category_id': 1,
        'category_name': 'General',
        'language': 'en',
      });

      expect(question.specialCategory, SpecialCategory.none);
    });

    test('maps unknown special_category labels to none', () {
      final question = Question.fromJson({
        'id': 1,
        'text': 'Question with unknown category',
        'category_id': 1,
        'category_name': 'General',
        'language': 'en',
        'special_category': 'something_new',
      });

      expect(question.specialCategory, SpecialCategory.none);
    });

    test('falls back to uncategorizedFallback when category_name is null', () {
      final question = Question.fromJson({
        'id': 1,
        'text': 'No category question',
        'category_id': 0,
        'category_name': null,
        'language': 'en',
      });

      expect(question.categoryName, uncategorizedFallback);
    });

    test(
      'falls back to uncategorizedFallback when category_name is missing',
      () {
        final question = Question.fromJson({
          'id': 1,
          'text': 'Missing category question',
          'category_id': 0,
          'language': 'en',
        });

        expect(question.categoryName, uncategorizedFallback);
      },
    );

    test('falls back to en when language is null', () {
      final question = Question.fromJson({
        'id': 1,
        'text': 'No language question',
        'category_id': 1,
        'category_name': 'Test',
        'language': null,
      });

      expect(question.language, 'en');
    });

    test('falls back to en when language is missing', () {
      final question = Question.fromJson({
        'id': 1,
        'text': 'Missing language question',
        'category_id': 1,
        'category_name': 'Test',
      });

      expect(question.language, 'en');
    });
  });

  group('AnswerStats.fromJson', () {
    test('parses all fields including num-to-double percent', () {
      final stats = AnswerStats.fromJson({
        'answer_id': 5,
        'answer_text': 'Yes, absolutely',
        'count': 42,
        'percent': 75.5,
      });

      expect(stats.answerId, 5);
      expect(stats.answerText, 'Yes, absolutely');
      expect(stats.count, 42);
      expect(stats.percent, 75.5);
    });

    test('converts integer percent to double', () {
      final stats = AnswerStats.fromJson({
        'answer_id': 3,
        'answer_text': 'No way',
        'count': 10,
        'percent': 50,
      });

      expect(stats.percent, 50.0);
      expect(stats.percent, isA<double>());
    });

    test('handles zero count and percent', () {
      final stats = AnswerStats.fromJson({
        'answer_id': 1,
        'answer_text': 'Maybe',
        'count': 0,
        'percent': 0,
      });

      expect(stats.count, 0);
      expect(stats.percent, 0.0);
    });
  });

  group('RegisterRequest.toJson', () {
    test('includes all fields when all are provided', () {
      final request = RegisterRequest(
        username: 'alice',
        email: 'alice@example.com',
        password: 'secret123',
        birthYear: 1990,
        gender: 'f',
        nationality: 'US',
      );

      final json = request.toJson();

      expect(json['username'], 'alice');
      expect(json['email'], 'alice@example.com');
      expect(json['password'], 'secret123');
      expect(json['birth_year'], 1990);
      expect(json['gender'], 'f');
      expect(json['nationality'], 'US');
    });

    test('omits null optional fields from JSON', () {
      final request = RegisterRequest(
        username: 'bob',
        email: 'bob@example.com',
        password: 'secret456',
      );

      final json = request.toJson();

      expect(json.containsKey('birth_year'), isFalse);
      expect(json.containsKey('gender'), isFalse);
      expect(json.containsKey('nationality'), isFalse);
      expect(json['username'], 'bob');
      expect(json['email'], 'bob@example.com');
      expect(json['password'], 'secret456');
    });

    test('includes zero birthYear (falsy but non-null) in JSON', () {
      final request = RegisterRequest(
        username: 'carol',
        email: 'carol@example.com',
        password: 'secret789',
        birthYear: 0,
      );

      final json = request.toJson();

      // birthYear of 0 is non-null so it is included
      expect(json.containsKey('birth_year'), isTrue);
      expect(json['birth_year'], 0);
    });
  });

  group('UpdateUserRequest.toJson', () {
    test('includes email when provided', () {
      final request = UpdateUserRequest(email: 'new@example.com');
      final json = request.toJson();

      expect(json['email'], 'new@example.com');
    });

    test('includes gender when provided', () {
      final request = UpdateUserRequest(email: 'new@example.com', gender: 'm');
      final json = request.toJson();

      expect(json['email'], 'new@example.com');
      expect(json['gender'], 'm');
    });

    test('includes password when provided', () {
      final request = UpdateUserRequest(
        email: 'new@example.com',
        password: 'newpass123',
      );
      final json = request.toJson();

      expect(json['email'], 'new@example.com');
      expect(json['password'], 'newpass123');
    });

    test('omits null gender and password from JSON', () {
      final request = UpdateUserRequest(email: 'new@example.com');
      final json = request.toJson();

      expect(json.containsKey('gender'), isFalse);
      expect(json.containsKey('password'), isFalse);
      expect(json['email'], 'new@example.com');
    });
  });

  group('AuthError', () {
    test('toString includes code and detail when present', () {
      final error = AuthError('loginFailed', 'Invalid credentials');
      expect(error.toString(), 'AuthError(loginFailed: Invalid credentials)');
    });

    test('toString includes code but not detail when detail is null', () {
      final error = AuthError('registrationFailed');
      expect(error.toString(), 'AuthError(registrationFailed)');
    });
  });
}
