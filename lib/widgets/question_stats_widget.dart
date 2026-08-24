import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/answer_stats.dart';
import '../utils/constants.dart';

/// A widget that displays voting statistics for a question.
///
/// Uses a tabbed layout to support multiple views of the statistics.
/// Supports bar chart, donut chart, and gender comparison views.
class QuestionStatsWidget extends StatefulWidget {
  final List<AnswerStats> stats;
  final bool isLoading;
  final String? errorMessage;

  /// Neutral notice for the bar and donut views, shown when the backend
  /// withheld statistics because too few matching answers exist
  /// (`insufficient_data`). Rendered like the empty state, not as an error.
  final String? insufficientDataMessage;
  final List<GenderStats> genderStats;

  const QuestionStatsWidget({
    super.key,
    required this.stats,
    required this.isLoading,
    this.errorMessage,
    this.insufficientDataMessage,
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

  // ─── Bar Chart View ──────────────────────────────────────

  Widget _buildBarChart(ColorScheme colorScheme) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.insufficientDataMessage != null) {
      return _buildEmpty(colorScheme, widget.insufficientDataMessage);
    }
    if (widget.errorMessage != null) {
      return _buildError(widget.errorMessage!, colorScheme);
    }
    if (widget.stats.isEmpty) {
      return _buildEmpty(colorScheme);
    }

    final sorted = List<AnswerStats>.from(widget.stats)
      ..sort((a, b) => b.count.compareTo(a.count));
    final maxCount = sorted.first.count;

    return Column(
      children: [
        // Legend
        _buildLegend(colorScheme, sorted),
        const SizedBox(height: 16),
        // Bars
        ...List.generate(sorted.length, (index) {
          final stat = sorted[index];
          return _AnimatedBar(
            stat: stat,
            color: answerColors[index % answerColors.length],
            maxCount: maxCount,
            isWinner: index == 0 && stat.count > 0,
            delay: Duration(milliseconds: index * 80),
          );
        }),
      ],
    );
  }

  // ─── Donut Chart View ────────────────────────────────────

  Widget _buildDonutChart(ColorScheme colorScheme) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.insufficientDataMessage != null) {
      return _buildEmpty(colorScheme, widget.insufficientDataMessage);
    }
    if (widget.errorMessage != null) {
      return _buildError(widget.errorMessage!, colorScheme);
    }
    if (widget.stats.isEmpty) {
      return _buildEmpty(colorScheme);
    }

    final sorted = List<AnswerStats>.from(widget.stats)
      ..sort((a, b) => b.count.compareTo(a.count));

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: _DonutChart(stats: sorted, colors: answerColors),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(colorScheme, sorted),
      ],
    );
  }

  // ─── Gender Comparison View ──────────────────────────────

  Widget _buildGenderComparison(ColorScheme colorScheme) {
    final allLoading = widget.genderStats.every((g) => g.isLoading);
    if (allLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        // Gender selector chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(widget.genderStats.length, (index) {
              final g = widget.genderStats[index];
              final isSelected = _selectedGenderIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g.label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedGenderIndex = index);
                  },
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        // Selected gender stats
        if (_selectedGenderIndex < widget.genderStats.length)
          _buildGenderStatsForIndex(colorScheme, _selectedGenderIndex),
      ],
    );
  }

  Widget _buildGenderStatsForIndex(ColorScheme colorScheme, int index) {
    final l10n = AppLocalizations.of(context);
    final g = widget.genderStats[index];
    if (g.isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (g.insufficientMessage != null) {
      return _buildEmpty(colorScheme, g.insufficientMessage);
    }
    if (g.errorMessage != null) {
      return _buildError(g.errorMessage!, colorScheme);
    }
    if (g.stats.isEmpty) {
      return _buildEmpty(colorScheme);
    }

    final sorted = List<AnswerStats>.from(g.stats)
      ..sort((a, b) => b.count.compareTo(a.count));
    final totalVotes = g.stats.fold<int>(0, (sum, s) => sum + s.count);
    final maxCount = sorted.first.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.votesCount(totalVotes),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...List.generate(sorted.length, (i) {
          final stat = sorted[i];
          return _AnimatedBar(
            stat: stat,
            color: answerColors[i % answerColors.length],
            maxCount: maxCount,
            isWinner: false,
            delay: Duration(milliseconds: i * 60),
          );
        }),
      ],
    );
  }

  // ─── Shared helpers ──────────────────────────────────────

  Widget _buildLegend(ColorScheme colorScheme, List<AnswerStats> sorted) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: List.generate(sorted.length, (index) {
        final stat = sorted[index];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: answerColors[index % answerColors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              stat.answerText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildError(String message, ColorScheme colorScheme) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 28),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme, [String? message]) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? l10n.noVotesYet,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Total Votes Badge ─────────────────────────────────────

class _TotalVotesBadge extends StatelessWidget {
  final int totalVotes;

  const _TotalVotesBadge({required this.totalVotes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_vote, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            l10n.totalVotes(totalVotes),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── View Toggle (Segmented Button style) ─────────────────

class _ViewToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ViewToggle({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final icons = [Icons.bar_chart, Icons.donut_large, Icons.people_outline];
    final tooltips = [l10n.viewBars, l10n.viewDonut, l10n.viewGender];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(icons.length, (index) {
          final isSelected = selectedIndex == index;
          return Tooltip(
            message: tooltips[index],
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icons[index],
                  size: 18,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Animated Bar ──────────────────────────────────────────

class _AnimatedBar extends StatefulWidget {
  final AnswerStats stat;
  final Color color;
  final int maxCount;
  final bool isWinner;
  final Duration delay;

  const _AnimatedBar({
    required this.stat,
    required this.color,
    required this.maxCount,
    required this.isWinner,
    required this.delay,
  });

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _barAnimation;
  late Animation<double> _percentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _barAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _percentAnimation = Tween<double>(
      begin: 0,
      end: widget.stat.percent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = widget.maxCount > 0
        ? widget.stat.count / widget.maxCount
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              if (widget.isWinner) ...[
                Icon(Icons.emoji_events, size: 16, color: widget.color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  widget.stat.answerText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: widget.isWinner
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _percentAnimation,
                builder: (context, _) {
                  return Text(
                    '${widget.stat.count} (${_percentAnimation.value.toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Bar track
          AnimatedBuilder(
            animation: _barAnimation,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Filled portion with gradient
                    FractionallySizedBox(
                      widthFactor: fraction * _barAnimation.value,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [
                              widget.color,
                              widget.color.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: widget.isWinner
                              ? [
                                  BoxShadow(
                                    color: widget.color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Donut Chart (Custom Painter) ──────────────────────────

class _DonutChart extends StatelessWidget {
  final List<AnswerStats> stats;
  final List<Color> colors;

  const _DonutChart({required this.stats, required this.colors});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final total = stats.fold<int>(0, (sum, s) => sum + s.count);

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _DonutChartPainter(
              stats: stats,
              colors: colors,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              textColor: colorScheme.onSurface,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.votesNoun,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<AnswerStats> stats;
  final List<Color> colors;
  final Color backgroundColor;
  final Color textColor;

  _DonutChartPainter({
    required this.stats,
    required this.colors,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = stats.fold<int>(0, (sum, s) => sum + s.count);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.32;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Segments
    double startAngle = -3.14159 / 2; // Start at top
    for (int i = 0; i < stats.length; i++) {
      final sweepAngle = (stats[i].count / total) * 2 * 3.14159;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
