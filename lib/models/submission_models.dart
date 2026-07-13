/// A question submission made by a user, as returned by the
/// `GET /questions/mine` endpoint.
///
/// Submissions are created as `pending` (the backend forces this and ignores
/// any client-supplied status) and later move to `approved` (visible to
/// everyone) or `rejected` by an administrator.
class Submission {
  final int id;
  final String text;
  final int categoryId;
  final String language;
  final int minAge;
  final String createdAt;
  final String submissionStatus;
  final int? submittedBy;
  final int? reviewedBy;

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
  });

  /// Builds a [Submission] from a JSON object returned by the backend.
  ///
  /// Missing or null fields fall back to safe defaults so a partially populated
  /// row never throws during decoding.
  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'] as int,
      text: json['text'] as String,
      categoryId: json['category_id'] as int,
      language: json['language'] as String? ?? 'en',
      minAge: json['min_age'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      submissionStatus: json['submission_status'] as String? ?? 'pending',
      submittedBy: json['submitted_by'] as int?,
      reviewedBy: json['reviewed_by'] as int?,
    );
  }

  /// The submission is still awaiting administrator review.
  bool get isPending => submissionStatus == 'pending';

  /// The submission has been approved and is now publicly visible.
  bool get isApproved => submissionStatus == 'approved';

  /// The submission has been rejected by an administrator.
  bool get isRejected => submissionStatus == 'rejected';
}
