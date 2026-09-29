import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_shell.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../workout_session/data/workout_history_repository.dart';
import '../domain/analytics_engine.dart';
import '../domain/records_engine.dart';

/// Progress tab (spec §19): range select 7/30/90/all, frequency bars,
/// consistency stats, per-exercise progression line, PR overview + history.
/// All chart data comes from [AnalyticsEngine] / [RecordsEngine] — no
/// widget-local math.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  AnalyticsRange _range = AnalyticsRange.thirtyDays;
  String? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final history =
        ref.watch(workoutHistoryRepositoryProvider).value ?? const [];

    final records = RecordsEngine.build(history);

    final frequency = AnalyticsEngine.frequency(history, _range);
    final consistency = AnalyticsEngine.consistency(history, _range);
    final top = AnalyticsEngine.topExercises(history, _range, n: 3);

    final exercise = _selectedExerciseId == null
        ? (top.isEmpty ? null : top.first)
        : AnalyticsEngine.exerciseTrend(
                history,
                _selectedExerciseId!,
                _range,
              ) ??
              top.firstOrNull;
    final selectedId = exercise?.exerciseId;

    return Scaffold(
      appBar: ShellAppBar(title: 'Progress'),
      body: history.isEmpty
          ? const AppEmptyState(
              title: 'No progress data yet',
              message:
                  'Charts for frequency, consistency and exercise '
                  'progression appear after your first workouts.',
              icon: Icons.insights_outlined,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Range selector (spec §19: 7 / 30 / 90 / all).
                SegmentedButton<AnalyticsRange>(
                  segments: [
                    for (final r in AnalyticsRange.values)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Frequency bar chart.
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frequency', style: AppTypography.title),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Workouts per day',
                        style: AppTypography.caption.apply(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 180,
                        child: _FrequencyChart(
                          buckets: frequency,
                          range: _range,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Consistency stats.
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Consistency', style: AppTypography.title),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          _ConsistencyStat(
                            value: '${consistency.sessions}',
                            label: 'Workouts',
                          ),
                          _ConsistencyStat(
                            value: '${consistency.activeDays}',
                            label: 'Active days',
                          ),
                          _ConsistencyStat(
                            value: '${consistency.totalMinutes}',
                            label: 'Minutes',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _ConsistencyStat(
                            value: '${consistency.avgSessionsPerWeek}',
                            label: 'Per week',
                          ),
                          _ConsistencyStat(
                            value: '${consistency.currentStreak}',
                            label: 'Streak',
                            accent: consistency.currentStreak > 0,
                          ),
                          _ConsistencyStat(
                            value: '${consistency.longestStreak}',
                            label: 'Best streak',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Exercise progression line chart.
                if (top.isNotEmpty) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exercise progression',
                          style: AppTypography.title,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Selector chips (top 3 by frequency in range).
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xxs,
                          children: [
                            for (final e in top)
                              ChoiceChip(
                                label: Text(e.name),
                                selected: selectedId == e.exerciseId,
                                onSelected: (_) => setState(
                                  () => _selectedExerciseId = e.exerciseId,
                                ),
                                visualDensity: VisualDensity.compact,
                                labelStyle: AppTypography.caption,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 180,
                          child: exercise!.points.length < 2
                              ? Center(
                                  child: Text(
                                    'One more session needed for a trend line.',
                                    style: AppTypography.caption.apply(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : _ProgressionChart(trend: exercise),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Records + history shortcut (Phase 4).
                Text('Personal records', style: AppTypography.title),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      for (final r in _topRecords(records, 6))
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                r.isTimed
                                    ? Icons.timer_outlined
                                    : Icons.fitness_center,
                                size: 16,
                                color: AppColors.accentLight,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  r.exerciseName,
                                  style: AppTypography.body,
                                ),
                              ),
                              Text(
                                r.labelValue,
                                style: AppTypography.bodySmall.apply(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'Workout history',
                  icon: Icons.history_rounded,
                  onPressed: () => context.go('/app/progress/history'),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }

  List<ExerciseRecords> _topRecords(
    Map<String, ExerciseRecords> records,
    int n,
  ) {
    final list = records.values.where((r) => r.bestSingle > 0).toList()
      ..sort((a, b) => b.bestSingle.compareTo(a.bestSingle));
    return list.take(n).toList();
  }
}

class _FrequencyChart extends StatelessWidget {
  const _FrequencyChart({required this.buckets, required this.range});

  final List<FrequencyBucket> buckets;
  final AnalyticsRange range;

  @override
  Widget build(BuildContext context) {
    if (buckets.every((b) => b.sessions == 0)) {
      return Center(
        child: Text(
          'No workouts in this range yet.',
          style: AppTypography.caption.apply(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxY = buckets.fold<int>(
      0,
      (a, b) => b.sessions > a ? b.sessions : a,
    );

    final showEveryDay = range == AnalyticsRange.sevenDays;

    return BarChart(
      BarChartData(
        maxY: (maxY + 1).toDouble(),
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].sessions.toDouble(),
                  width: 10,
                  color: buckets[i].sessions > 0
                      ? AppColors.accentLight
                      : AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showEveryDay,
              reservedSize: 18,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox();
                final b = buckets[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _weekday(b.day.weekday),
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.accent.withValues(alpha: 0.12),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final b = buckets[group.x];
              return BarTooltipItem(
                '${b.sessions} workout${b.sessions == 1 ? '' : 's'}\n'
                '${b.sets} sets',
                AppTypography.caption.copyWith(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  String _weekday(int w) => switch (w) {
    1 => 'Mo',
    2 => 'Tu',
    3 => 'We',
    4 => 'Th',
    5 => 'Fr',
    6 => 'Sa',
    _ => 'Su',
  };
}

class _ProgressionChart extends StatelessWidget {
  const _ProgressionChart({required this.trend});

  final ExerciseTrend trend;

  @override
  Widget build(BuildContext context) {
    final points = trend.points;
    final maxV = trend.bestEver;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxV * 1.15).toDouble(),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].bestSingle.toDouble()),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.accentLight,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withValues(alpha: 0.12),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxV > 15 ? (maxV / 2).ceilToDouble() : 1,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: points.length <= 8,
              reservedSize: 18,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                final p = points[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${p.date.day}/${p.date.month}',
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.accent.withValues(alpha: 0.12),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${s.y.toInt()} ${trend.unitLabel}',
                  AppTypography.caption.copyWith(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsistencyStat extends StatelessWidget {
  const _ConsistencyStat({
    required this.value,
    required this.label,
    this.accent = false,
  });

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: accent
                ? AppTypography.statNumber.copyWith(
                    color: AppColors.accentLight,
                  )
                : AppTypography.statNumber,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.caption.apply(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
