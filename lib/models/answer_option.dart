/// Represents a single answer option for a question.
class AnswerOption {
  final int id;
  final int questionId;
  final String text;

  AnswerOption({
    required this.id,
    required this.questionId,
    required this.text,
  });

  factory AnswerOption.fromJson(Map<String, dynamic> json) {
    return AnswerOption(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      text: json['text'] as String,
    );
  }
}
