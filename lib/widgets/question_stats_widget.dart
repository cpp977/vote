import 'package:flutter/material.dart';

import '../models/answer_stats.dart';

/// A widget that displays voting statistics for a question.
///
/// Uses a tabbed layout to support multiple views of the statistics.
/// Currently only shows an "Overall" tab with vote counts and percentages.
class QuestionStatsWidget extends StatefulWidget {
  final List<AnswerStats> stats;
  final bool isLoading;
  final String? errorMessage;
  final List<GenderStats> genderStats;

  const QuestionStatsWidget({
    super.key,
    required this.stats,
    required this.isLoading,
    this.errorMessage,
    required this.genderStats,
  });

  @override
  State<QuestionStatsWidget> createState() => _QuestionStatsWidgetState();
}

class _QuestionStatsWidgetState extends State<QuestionStatsWidget>
    with TickerProviderStateMixin {
  int _selectedView = 0; // 0 = bars, 1 = donut, 2 = gender
  int _selectedGenderIndex = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalVotes = widget.stats.fold<int>(0, (sum, s) => sum + s.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with total votes and view toggle
        Row(
          children: [
            Expanded(child: _TotalVotesBadge(totalVotes: totalVotes)),
            const SizedBox(width: 12),
            _ViewToggle(
              selectedIndex: _selectedView,
              onSelected: (index) {
                setState(() => _selectedView = index);
                _animController.reset();
                _animController.forward();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Content area
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildContent(colorScheme),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    switch (_selectedView) {
      case 0:
        return _buildBarChart(colorScheme);
      case 1:
        return _buildDonutChart(colorScheme);
      case 2:
        return _buildGenderComparison(colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBarChart(ColorScheme colorScheme) {
    // TODO: Implement bar chart visualization
    return const Placeholder();
  }

  Widget _buildDonutChart(ColorScheme colorScheme) {
    // TODO: Implement donut chart visualization
    return const Placeholder();
  }

  Widget _buildGenderComparison(ColorScheme colorScheme) {
    // TODO: Implement gender comparison visualization
    return const Placeholder();
  }
}

class _TotalVotesBadge extends StatelessWidget {
  final int totalVotes;

  const _TotalVotesBadge({required this.totalVotes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Total Votes: $totalVotes',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelected;

  const _ViewToggle({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const <ButtonSegment<int>>[
        ButtonSegment<int>(label: Text('Bars'), value: 0),
        ButtonSegment<int>(label: Text('Donut'), value: 1),
        ButtonSegment<int>(label: Text('Gender'), value: 2),
      ],
      selected: <int>{selectedIndex},
      onSelectionChanged: (Set<int> newSelection) {
        onSelected(newSelection.first);
      },
    );
  }
}
