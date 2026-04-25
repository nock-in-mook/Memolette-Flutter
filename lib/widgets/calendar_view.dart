import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';

/// 「全カレンダー」タブ本体。縦スクロール月別カレンダー。
/// 各日付セルに件数バッジ + 「+」ボタン（タップ動作は Step 6 で配線）。
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  // 表示範囲: 当月の前後何ヶ月分を出すか（Lazy 拡張は後フェーズ）
  static const int _monthsBefore = 6;
  static const int _monthsAfter = 12;

  // 各月ブロックの高さ概算（曜日ヘッダ込み・週数で変動するためあくまで初期スクロール用）
  static const double _approxMonthHeight = 360;

  late final ScrollController _scrollController;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _scrollController = ScrollController();
    // 起動時に当月までスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final offset = _approxMonthHeight * _monthsBefore;
      _scrollController.jumpTo(offset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final months = <DateTime>[];
    for (int i = -_monthsBefore; i <= _monthsAfter; i++) {
      months.add(DateTime(_today.year, _today.month + i));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: months.length,
      itemBuilder: (ctx, i) => _MonthBlock(month: months[i], today: _today),
    );
  }
}

/// 月単位のブロック: 月見出し + 曜日ヘッダ + 日付グリッド
class _MonthBlock extends ConsumerWidget {
  final DateTime month; // その月の1日
  final DateTime today;

  const _MonthBlock({required this.month, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final countsAsync = ref.watch(eventCountsForRangeProvider(
      (start: monthStart, end: monthEnd),
    ));
    final counts = countsAsync.valueOrNull ?? const <DateTime, int>{};

    // 月の日数
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 月初が日曜から数えて何番目か (0=日曜)
    // DateTime.weekday は 1=月曜, ..., 7=日曜
    final firstDayWeekday = monthStart.weekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月見出し
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                '${month.year}年 ${month.month}月',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
            // 曜日ヘッダ
            const _WeekdayHeader(),
            // 日付グリッド (7 列)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.9,
              ),
              itemCount: firstDayWeekday + daysInMonth,
              itemBuilder: (ctx, i) {
                if (i < firstDayWeekday) {
                  return const _EmptyDayCell();
                }
                final dayNum = i - firstDayWeekday + 1;
                final day = DateTime(month.year, month.month, dayNum);
                final count = counts[day] ?? 0;
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                return _DayCell(day: day, count: count, isToday: isToday);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['日', '月', '火', '水', '木', '金', '土'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: labels
            .map((l) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Hiragino Sans',
                          color: l == '日'
                              ? Colors.red.shade400
                              : l == '土'
                                  ? Colors.blue.shade400
                                  : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _EmptyDayCell extends StatelessWidget {
  const _EmptyDayCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final int count;
  final bool isToday;

  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final weekdayColor = day.weekday == DateTime.sunday
        ? Colors.red.shade400
        : day.weekday == DateTime.saturday
            ? Colors.blue.shade400
            : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
        color: isToday ? Colors.blue.withValues(alpha: 0.06) : null,
      ),
      child: Stack(
        children: [
          // 日付数字（左上）
          Positioned(
            top: 3,
            left: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: isToday
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade500,
                    )
                  : null,
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Hiragino Sans',
                    color: isToday ? Colors.white : weekdayColor,
                  ),
                ),
              ),
            ),
          ),
          // 件数バッジ（中央下）
          if (count > 0)
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.orange.withValues(alpha: 0.18),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Hiragino Sans',
                      color: Color(0xFFE67E22),
                    ),
                  ),
                ),
              ),
            ),
          // 「+」ボタン（右下、Step 6 で onTap 配線）
          Positioned(
            bottom: 2,
            right: 2,
            child: Icon(
              Icons.add_circle_outline,
              size: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
