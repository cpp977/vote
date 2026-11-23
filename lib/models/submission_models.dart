/// A possible answer attached to a submitted question, as returned inside the
/// `answer_options` array of the `POST /questions/submissions` response.
class AnswerOption {
  final int id;
  final int questionId;
  final String text;

  const AnswerOption({
    required this.id,
    required this.questionId,
    required this.text,
  });

  /// Builds an [AnswerOption] from a JSON object returned by the backend.
  factory AnswerOption.fromJson(Map<String, dynamic> json) {
    return AnswerOption(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      text: json['text'] as String,
    );
  }
}

/// A question submission made by a user, as returned by the
/// `GET /questions/mine` endpoint and as the result of a successful
/// `POST /questions/submissions` call.
///
/// Submissions are created as `pending` (the backend forces this and ignores
/// any client-supplied status) and later move to `approved` (visible to
/// everyone) or `rejected` by an administrator. A submission is always created
/// together with its [answerOptions], which the backend stores atomically.
class Submission {
  final int id;
  final String text;

  /// Category this submission was filed under, or `null` when the user did not
  /// pick one. An administrator has to assign a category before approving.
  final int? categoryId;

  final String language;
  final int minAge;
  final String createdAt;
  final String submissionStatus;
  final String? submittedBy;
  final String? reviewedBy;

  /// The answer options the question can be voted on. Only present in the
  /// response of `POST /questions/submissions`; `null` for the rows returned by
  /// `GET /questions/mine` (which omits this array).
  final List<AnswerOption>? answerOptions;

  const Submission({
    required this.id,
    required this.text,
    required this.categoryId,
    required this.language,
    required this.minAge,
    required this.createdAt,
    required this.submissionStatus,
    this.submittedBy,
    this.reviewedBy,
    this.answerOptions,
  });

  /// Builds a [Submission] from a JSON object returned by the backend.
  ///
  /// Missing or null fields fall back to safe defaults so a partially populated
  /// row never throws during decoding.
  factory Submission.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawOptions = json['answer_options'] as List?;
    final List<AnswerOption>? answerOptions = rawOptions
        ?.map((e) => AnswerOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return Submission(
      id: json['id'] as int,
      text: json['text'] as String,
      categoryId: json['category_id'] as int?,
      language: json['language'] as String? ?? 'en',
      minAge: json['min_age'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      submissionStatus: json['submission_status'] as String? ?? 'pending',
      submittedBy: json['submitted_by'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      answerOptions: answerOptions,
    );
  }

  /// The submission is still awaiting administrator review.
  bool get isPending => submissionStatus == 'pending';

  /// The submission has been approved and is now publicly visible.
  bool get isApproved => submissionStatus == 'approved';

  /// The submission has been rejected by an administrator.
  bool get isRejected => submissionStatus == 'rejected';
}

/// An answer-option submission made by a user: a proposed new answer option for
/// an existing question, as returned by the
/// `POST /questions/{id}/answer-submissions`, `GET /answer-submissions/mine` and
/// `GET /admin/answer-submissions` endpoints.
///
/// Like a [Submission] it is created as `pending` and later moves to `approved`
/// (the option has been appended to the question and is votable) or `rejected`
/// by an administrator. [questionText] is denormalized by the backend so the
/// list screens can render the question next to the proposed option.
class AnswerSubmission {
  final int id;
  final int questionId;

  /// Text of the question the option is proposed for.
  final String questionText;

  /// The proposed answer option.
  final String text;

  final String language;
  final String submissionStatus;
  final String createdAt;
  final String? submittedBy;
  final String? reviewedBy;
  final String? reviewedAt;

  const AnswerSubmission({
    required this.id,
    required this.questionId,
    required this.questionText,
    required this.text,
    required this.language,
    required this.submissionStatus,
    required this.createdAt,
    this.submittedBy,
    this.reviewedBy,
    this.reviewedAt,
  });

  /// Builds an [AnswerSubmission] from a JSON object returned by the backend.
  ///
  /// Missing or null fields fall back to safe defaults so a partially populated
  /// row never throws during decoding.
  factory AnswerSubmission.fromJson(Map<String, dynamic> json) {
    return AnswerSubmission(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      questionText: json['question_text'] as String? ?? '',
      text: json['text'] as String,
      language: json['language'] as String? ?? 'en',
      submissionStatus: json['submission_status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      submittedBy: json['submitted_by'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
    );
  }

  /// The submission is still awaiting administrator review.
  bool get isPending => submissionStatus == 'pending';

  /// The submission has been approved and the option is now votable.
  bool get isApproved => submissionStatus == 'approved';

  /// The submission has been rejected by an administrator.
  bool get isRejected => submissionStatus == 'rejected';
}
