import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/answer_stats.dart';
import '../models/stats_dimensions.dart';
import '../services/question_stats_service.dart';
import '../utils/constants.dart';

/// Which chart type is currently rendered.
enum _ChartType { bars, donut }

/// A widget that displays voting statistics for a question.
///
/// Visualization and segmentation are orthogonal:
///  - The toggle in the header selects the chart type (bars or donut).
///  - The "Breakdown" row selects *whose* votes are shown: everyone by
///    default, or any combination of dimension filters (gender, age,
///    nationality, … — anything listed in [statsDimensions]). Filters are
///    picked via a bottom sheet and shown as removable chips; combinations
///    across dimensions are resolved by the backend into a single segment.
///
/// Segment data is provided by [QuestionStatsController], which loads segments
/// lazily and caches them.
class QuestionStatsWidget extends StatefulWidget {
  final QuestionStatsController controller;

  const QuestionStatsWidget({super.key, required this.controller});

  @override
  State<QuestionStatsWidget> createState() => _QuestionStatsWidgetState();
}

class _QuestionStatsWidgetState extends State<QuestionStatsWidget>
    with TickerProviderStateMixin {
  _ChartType _chartType = _ChartType.bars;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  /// Query whose content was animated last, so switching charts or segments
  /// replays the fade-in.
  String? _lastAnimatedKey;

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
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Replays the fade animation when the displayed content changed.
  void _animateFor(String key) {
    if (_lastAnimatedKey == key) return;
    _lastAnimatedKey = key;
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final query = widget.controller.activeQuery;
        _animateFor('${query.cacheKey}|${_chartType.name}');

        final activeState = widget.controller.activeState;
        // The badge always reports the overall vote count, independent of the
        // segment currently displayed.
        final overallState = widget.controller.stateFor(StatsQuery.overall());
        final totalVotes = _totalVotesOf(overallState);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with total votes and chart-type toggle
            Row(
              children: [
                Expanded(
                  child: _TotalVotesBadge(
                    state: overallState,
                    fallbackTotalVotes: totalVotes,
                  ),
                ),
                const SizedBox(width: 12),
                _ViewToggle(
                  selected: _chartType,
                  onSelected: (type) => setState(() => _chartType = type),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Breakdown / segment filter row
            _buildBreakdownRow(l10n),
            const SizedBox(height: 16),
            // Content area
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildContent(l10n, query, activeState),
            ),
          ],
        );
      },
    );
  }

  int _totalVotesOf(SegmentLoadState state) {
    final result = state.result;
    if (result == null || result.insufficientData || result.hasError) return 0;
    return result.answers.fold<int>(0, (sum, s) => sum + s.count);
  }

  // ─── Breakdown Row ───────────────────────────────────────

  Widget _buildBreakdownRow(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = widget.controller.activeQuery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.breakdownLabel,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text(l10n.filterEveryone),
              selected: query.isOverall,
              onSelected: query.isOverall
                  ? null
                  : (_) => widget.controller.select(StatsQuery.overall()),
              avatar: Icon(
                Icons.groups,
                size: 18,
                color: query.isOverall ? colorScheme.onPrimaryContainer : null,
              ),
            ),
            // One removable chip per active dimension filter.
            for (final entry in query.filters.entries)
              _buildActiveFilterChip(l10n, entry.key, entry.value),
            ActionChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: Text(l10n.addFilter),
              onPressed: _openFilterSheet,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(
    AppLocalizations l10n,
    String dimensionKey,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dimension = widget.controller.dimensions
        .where((d) => d.key == dimensionKey)
        .firstOrNull;
    if (dimension == null) return const SizedBox.shrink();
    final dimensionValue = dimension.values
        .where((v) => v.value == value)
        .firstOrNull;
    final label =
        '${dimension.label(l10n)} · '
        '${dimensionValue?.label(l10n) ?? value}';

    return InputChip(
      avatar: Icon(dimension.icon, size: 16, color: colorScheme.primary),
      label: Text(label),
      deleteButtonTooltipMessage: l10n.removeFilterTooltip,
      onDeleted: () => widget.controller.select(
        widget.controller.activeQuery.withoutFilter(dimensionKey),
      ),
      onPressed: () => _openFilterSheet(),
    );
  }

  Future<void> _openFilterSheet() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _SegmentFilterSheet(controller: widget.controller),
    );
  }

  // ─── Content Area ────────────────────────────────────────

  Widget _buildContent(
    AppLocalizations l10n,
    StatsQuery query,
    SegmentLoadState state,
  ) {
    if (state.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final result = state.result!;
    if (result.insufficientData) {
      return _buildEmpty(context, l10n.statsInsufficientData);
    }
    if (result.hasError) {
      return switch (result.errorKind!) {
        SegmentErrorKind.notAvailable => _buildEmpty(
          context,
          l10n.statsNotAvailable,
        ),
        SegmentErrorKind.loadFailed => _buildError(
          result.errorDetail != null
              ? l10n.connectionError(result.errorDetail!)
              : l10n.statsLoadFailed,
        ),
      };
    }

    final stats = result.answers;
    if (stats.isEmpty) return _buildEmpty(context, l10n.noVotesYet);

    final sorted = List<AnswerStats>.from(stats)
      ..sort((a, b) => b.count.compareTo(a.count));

    return switch (_chartType) {
      _ChartType.bars => _buildBarChart(l10n, query, sorted),
      _ChartType.donut => _buildDonutChart(sorted),
    };
  }

  Widget _buildBarChart(
    AppLocalizations l10n,
    StatsQuery query,
    List<AnswerStats> sorted,
  ) {
    final maxCount = sorted.first.count;
    final totalVotes = sorted.fold<int>(0, (sum, s) => sum + s.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!query.isOverall)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.votesCount(totalVotes),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        _buildLegend(context, sorted),
        const SizedBox(height: 16),
        ...List.generate(sorted.length, (index) {
          final stat = sorted[index];
          return _AnimatedBar(
            stat: stat,
            color: answerColors[index % answerColors.length],
            maxCount: maxCount,
            isWinner: index == 0 && stat.count > 0 && query.isOverall,
            delay: Duration(milliseconds: index * 80),
          );
        }),
      ],
    );
  }

  Widget _buildDonutChart(List<AnswerStats> sorted) {
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
        _buildLegend(context, sorted),
      ],
    );
  }

  // ─── Shared helpers ──────────────────────────────────────

  Widget _buildLegend(BuildContext context, List<AnswerStats> sorted) {
    final colorScheme = Theme.of(context).colorScheme;
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

  Widget _buildError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
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

  Widget _buildEmpty(BuildContext context, [String? message]) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
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

// ─── Segment Filter Bottom Sheet ───────────────────────────

/// Sheet listing every known [StatsDimension] with its values as toggleable
/// chips. Selecting a value applies it immediately so several dimensions can
/// be combined before dismissing the sheet; tapping a selected value removes
/// that dimension again.
class _SegmentFilterSheet extends StatelessWidget {
  final QuestionStatsController controller;

  const _SegmentFilterSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.statsFilterSheetTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.statsFilterSheetHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final query = controller.activeQuery;
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    for (final dimension in controller.dimensions) ...[
                      _DimensionSection(
                        dimension: dimension,
                        selectedValue: query.valueOf(dimension.key),
                        onToggle: (value) => _toggle(dimension, value),
                      ),
                      if (dimension != controller.dimensions.last)
                        const Divider(height: 24),
                    ],
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.groups),
                label: Text(l10n.filterEveryone),
                onPressed: () {
                  controller.select(StatsQuery.overall());
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(StatsDimension dimension, StatsDimensionValue value) {
    final current = controller.activeQuery.valueOf(dimension.key);
    controller.select(
      current == value.value
          ? controller.activeQuery.withoutFilter(dimension.key)
          : controller.activeQuery.withFilter(dimension.key, value.value),
    );
  }
}

/// One dimension block inside the filter sheet: header row plus value chips.
class _DimensionSection extends StatelessWidget {
  final StatsDimension dimension;
  final String? selectedValue;
  final ValueChanged<StatsDimensionValue> onToggle;

  const _DimensionSection({
    required this.dimension,
    required this.selectedValue,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(dimension.icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                dimension.label(l10n),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in dimension.values)
                ChoiceChip(
                  label: Text(value.label(l10n)),
                  selected: selectedValue == value.value,
                  onSelected: (_) => onToggle(value),
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: selectedValue == value.value
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: selectedValue == value.value
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Total Votes Badge ─────────────────────────────────────

class _TotalVotesBadge extends StatelessWidget {
  final SegmentLoadState state;
  final int fallbackTotalVotes;

  const _TotalVotesBadge({
    required this.state,
    required this.fallbackTotalVotes,
  });

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
          // Once loading finished the count is always rendered as text —
          // including zero totals, withheld segments (insufficient_data) and
          // failed requests, which all report 0 — so the badge never keeps
          // spinning.
          if (!state.isLoading)
            Text(
              l10n.totalVotes(fallbackTotalVotes),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

// ─── View Toggle (Segmented Button style) ─────────────────

class _ViewToggle extends StatelessWidget {
  final _ChartType selected;
  final ValueChanged<_ChartType> onSelected;

  const _ViewToggle({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final types = [_ChartType.bars, _ChartType.donut];
    final icons = [Icons.bar_chart, Icons.donut_large];
    final tooltips = [l10n.viewBars, l10n.viewDonut];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(types.length, (index) {
          final isSelected = selected == types[index];
          return Tooltip(
            message: tooltips[index],
            child: GestureDetector(
              onTap: () => onSelected(types[index]),
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
