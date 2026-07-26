/// Statistics for a single answer option.
class AnswerStats {
  final int answerId;
  final String answerText;
  final int count;
  final double percent;

  AnswerStats({
    required this.answerId,
    required this.answerText,
    required this.count,
    required this.percent,
  });

  factory AnswerStats.fromJson(Map<String, dynamic> json) {
    return AnswerStats(
      answerId: json['answer_id'] as int,
      answerText: json['answer_text'] as String,
      count: json['count'] as int,
      percent: (json['percent'] as num).toDouble(),
    );
  }
}

/// Gender-specific statistics data.
class GenderStats {
  final String gender;
  final String label;
  final List<AnswerStats> stats;
  final bool isLoading;
  final String? errorMessage;

  GenderStats({
    required this.gender,
    required this.label,
    required this.stats,
    required this.isLoading,
    this.errorMessage,
  });
}
