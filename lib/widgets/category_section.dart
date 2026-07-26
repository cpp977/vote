import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/question.dart';
import '../utils/constants.dart';
import 'question_card.dart';

class CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Question> questions;
  final void Function(Question) onQuestionTap;

  const CategorySection({
    super.key,
    required this.categoryName,
    required this.questions,
    required this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    categoryName == uncategorizedFallback
                        ? l10n.uncategorized
                        : categoryName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...questions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QuestionCard(
                question: question,
                onTap: () => onQuestionTap(question),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
