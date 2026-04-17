import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/study_log.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

/// Widget body thống kê — nhúng vào HomeScreen (không có Scaffold/AppBar)
class StatsBody extends StatefulWidget {
  const StatsBody({super.key});
  @override
  State<StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<StatsBody> {
  final FirestoreService _fs = FirestoreService();
  List<StudyLog> _logs = [];
  bool _isLoading = true;
  int _filterDays = 7;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _fs.getStudyLogs(lastNDays: _filterDays);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('StatsBody _loadLogs error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, int> get _cardsPerDay {
    final map = <String, int>{};
    for (final log in _logs) {
      final key = DateFormat('yyyy-MM-dd').format(log.studiedAt);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<int, int> get _ratingCounts {
    final map = {0: 0, 2: 0, 3: 0, 5: 0};
    for (final log in _logs) {
      if (map.containsKey(log.rating)) {
        map[log.rating] = map[log.rating]! + 1;
      }
    }
    return map;
  }

  int get _totalCards => _logs.length;
  int get _correctCards => _logs.where((l) => l.isCorrect).length;
  int get _studyDays => _cardsPerDay.keys.length;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }
    return RefreshIndicator(
      color: c.primary,
      onRefresh: _loadLogs,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildFilterChips(c),
          const SizedBox(height: 14),
          _buildSummaryCards(c),
          const SizedBox(height: 18),
          _buildSectionLabel('SỐ THẺ HỌC MỖI NGÀY', c),
          const SizedBox(height: 10),
          _buildBarChart(c),
          const SizedBox(height: 22),
          _buildSectionLabel('PHÂN BỐ MỨC ĐÁNH GIÁ', c),
          const SizedBox(height: 10),
          _buildPieChart(c),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppColors c) {
    return Row(
      children: [
        _filterChip(7, '7 ngày', c),
        const SizedBox(width: 8),
        _filterChip(30, '30 ngày', c),
      ],
    );
  }

  Widget _filterChip(int days, String label, AppColors c) {
    final active = _filterDays == days;
    return GestureDetector(
      onTap: () {
        if (_filterDays != days) {
          _filterDays = days;
          _loadLogs();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? c.primary : c.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(AppColors c) {
    final accuracy = _totalCards > 0
        ? (_correctCards / _totalCards * 100).round()
        : 0;
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            Icons.style_rounded,
            '$_totalCards',
            'Lượt ôn',
            c.primary,
            c.primaryBg,
            c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            Icons.check_circle_outline_rounded,
            '$accuracy%',
            'Chính xác',
            c.teal,
            c.tealBg,
            c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            Icons.calendar_today_rounded,
            '$_studyDays',
            'Ngày học',
            c.amber,
            c.amberBg,
            c,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    IconData icon,
    String value,
    String label,
    Color color,
    Color bg,
    AppColors c,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, AppColors c) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: c.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildBarChart(AppColors c) {
    final cpd = _cardsPerDay;
    final now = DateTime.now();
    final days = List.generate(
      _filterDays,
      (i) => now.subtract(Duration(days: _filterDays - 1 - i)),
    );

    int maxY = 1;
    for (final d in days) {
      final count = cpd[DateFormat('yyyy-MM-dd').format(d)] ?? 0;
      if (count > maxY) maxY = count;
    }
    maxY = ((maxY / 5).ceil() * 5).clamp(5, 999);

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < days.length; i++) {
      final count = cpd[DateFormat('yyyy-MM-dd').format(days[i])] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: count > 0
                  ? c.primary
                  : c.textTertiary.withValues(alpha: 0.3),
              width: _filterDays <= 7 ? 28 : 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(0, 16, 8, 0),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY.toDouble(),
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 999),
            getDrawingHorizontalLine: (v) =>
                FlLine(color: c.bodyBg, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (maxY / 4).ceilToDouble().clamp(1, 999),
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: TextStyle(fontSize: 9, color: c.textTertiary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= days.length) {
                    return const SizedBox.shrink();
                  }
                  if (_filterDays > 7 &&
                      idx % 5 != 0 &&
                      idx != days.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('dd/MM').format(days[idx]),
                      style: TextStyle(fontSize: 8, color: c.textTertiary),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, gIdx, rod, rIdx) {
                final d = days[group.x.toInt()];
                return BarTooltipItem(
                  '${DateFormat('dd/MM').format(d)}\n${rod.toY.toInt()} thẻ',
                  const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(AppColors c) {
    final rc = _ratingCounts;
    final total = rc.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            'Chưa có dữ liệu đánh giá',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ),
      );
    }

    final data = [
      _PieEntry('Quên', rc[0]!, c.error, c.coralBg),
      _PieEntry('Khó', rc[2]!, c.coral, c.amberBg),
      _PieEntry('Được', rc[3]!, c.primary, c.primaryBg),
      _PieEntry('Dễ', rc[5]!, c.teal, c.tealBg),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: data.where((d) => d.count > 0).map((d) {
                  final pct = (d.count / total * 100).round();
                  return PieChartSectionData(
                    value: d.count.toDouble(),
                    color: d.color,
                    radius: 42,
                    title: '$pct%',
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.map((d) {
                final pct = total > 0 ? (d.count / total * 100).round() : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: d.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${d.count}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: d.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($pct%)',
                        style: TextStyle(
                          fontSize: 10,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieEntry {
  final String label;
  final int count;
  final Color color;
  final Color bg;
  const _PieEntry(this.label, this.count, this.color, this.bg);
}
