import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/responsive.dart';
import '../utils/safe_dialog.dart';
import 'day_items_panel.dart';

/// 「全カレンダー」タブ本体。縦スクロール月別カレンダー。
/// - 日付セルタップ:
///   - iPad 横画面: 右カラムの DayItemsPanel に選択日を反映
///   - 縦画面: showModalBottomSheet で当日アイテム一覧を表示
/// 「+」ボタンの動作配線は Step 6。
class CalendarView extends ConsumerStatefulWidget {
  final ValueChanged<Memo> onMemoTap;
  final ValueChanged<TodoList> onTodoListTap;
  final ValueChanged<Memo> onMemoCreated;

  const CalendarView({
    super.key,
    required this.onMemoTap,
    required this.onTodoListTap,
    required this.onMemoCreated,
  });

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  static const int _monthsBefore = 6;
  static const int _monthsAfter = 12;
  static const double _approxMonthHeight = 360;

  late final ScrollController _scrollController;
  late final DateTime _today;
  DateTime? _selectedDay; // iPad 横画面で右カラムに表示する日

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _scrollController = ScrollController();
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

  void _handleDayTap(DateTime day, int count) {
    if (Responsive.isWide(context)) {
      setState(() => _selectedDay = day);
      return;
    }
    // メモ入力欄のフォーカスを外しておかないと、シート閉時に
    // フォーカス復元で勝手に編集モードに突入する
    FocusManager.instance.primaryFocus?.unfocus();
    if (count == 0) {
      // 何もない日は新規作成アクションに直行
      _handleAddTap(day);
    } else {
      _showDaySheet(day);
    }
  }

  Future<void> _handleAddTap(DateTime day) async {
    // 開閉前後で unfocus してフォーカス復元による編集モード突入を防ぐ
    final type = await focusSafe<_AddType>(
      context,
      () => showModalBottomSheet<_AddType>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _AddActionSheet(day: day),
      ),
    );
    if (type == null || !mounted) return;
    final db = ref.read(databaseProvider);
    switch (type) {
      case _AddType.memo:
        final memo = await db.createMemo(eventDate: day);
        if (!mounted) return;
        widget.onMemoCreated(memo);
      case _AddType.todoList:
        final list = await db.createTodoList(eventDate: day);
        if (!mounted) return;
        widget.onTodoListTap(list);
    }
  }

  void _showDaySheet(DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // ドラッグハンドル
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: PrimaryScrollController(
                    controller: scrollController,
                    child: DayItemsPanel(
                      day: day,
                      onMemoTap: (m) {
                        Navigator.of(ctx).pop();
                        widget.onMemoTap(m);
                      },
                      onTodoListTap: (l) {
                        Navigator.of(ctx).pop();
                        widget.onTodoListTap(l);
                      },
                      onAddTap: () {
                        Navigator.of(ctx).pop();
                        _handleAddTap(day);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarList = _buildCalendarList();
    if (Responsive.isWide(context)) {
      // 横画面では右カラムに常時 DayItemsPanel
      _selectedDay ??= _today;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: calendarList),
          Container(
            width: 1,
            color: Colors.black.withValues(alpha: 0.06),
          ),
          Expanded(
            flex: 3,
            child: DayItemsPanel(
              day: _selectedDay!,
              onMemoTap: widget.onMemoTap,
              onTodoListTap: widget.onTodoListTap,
              onAddTap: () => _handleAddTap(_selectedDay!),
            ),
          ),
        ],
      );
    }
    return calendarList;
  }

  Widget _buildCalendarList() {
    final months = <DateTime>[];
    for (int i = -_monthsBefore; i <= _monthsAfter; i++) {
      months.add(DateTime(_today.year, _today.month + i));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: months.length,
      itemBuilder: (ctx, i) => _MonthBlock(
        month: months[i],
        today: _today,
        selectedDay: _selectedDay,
        onDayTap: _handleDayTap,
      ),
    );
  }
}

/// 月単位のブロック: 月見出し + 曜日ヘッダ + 日付グリッド
class _MonthBlock extends ConsumerWidget {
  final DateTime month; // その月の1日
  final DateTime today;
  final DateTime? selectedDay;
  // 引数: タップされた day と当日件数（0なら新規作成シートに直行）
  final void Function(DateTime day, int count) onDayTap;

  const _MonthBlock({
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.onDayTap,
  });

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

    // 7 列 × N 行を手動レイアウト（GridView は shrinkWrap 下で余白挙動が読めなかった）
    final totalCells = firstDayWeekday + daysInMonth;
    final weeksCount = (totalCells / 7).ceil();
    final rows = <Widget>[];
    for (int week = 0; week < weeksCount; week++) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final cellIndex = week * 7 + col;
        if (cellIndex >= totalCells || cellIndex < firstDayWeekday) {
          cells.add(const Expanded(child: _EmptyDayCell()));
          continue;
        }
        final dayNum = cellIndex - firstDayWeekday + 1;
        final day = DateTime(month.year, month.month, dayNum);
        final count = counts[day] ?? 0;
        final isToday = day.year == today.year &&
            day.month == today.month &&
            day.day == today.day;
        final isSelected = selectedDay != null &&
            day.year == selectedDay!.year &&
            day.month == selectedDay!.month &&
            day.day == selectedDay!.day;
        cells.add(Expanded(
          child: _DayCell(
            day: day,
            count: count,
            isToday: isToday,
            isSelected: isSelected,
            onTap: () => onDayTap(day, count),
          ),
        ));
      }
      rows.add(SizedBox(
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        ),
      ));
    }

    final mainContent = Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 月見出し
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              '${month.year}年 ${month.month}月',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontFamily: 'Hiragino Sans',
              ),
            ),
          ),
          // 曜日ヘッダ（密着配置）
          const _WeekdayHeader(),
          // 日付グリッド: Row × N (手動レイアウト)
          ...rows,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // メインカード（Stack のサイズはこの Column で決まる）
            mainContent,
            // 大きな月数字を中央透かしとして重ねる（IgnorePointer でクリック素通し）
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '${month.month}',
                    style: TextStyle(
                      fontSize: 200,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black.withValues(alpha: 0.06),
                      height: 1.0,
                    ),
                  ),
                ),
              ),
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
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Row(
        children: labels
            .map((l) => Expanded(
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
  final bool isSelected;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekdayColor = day.weekday == DateTime.sunday
        ? Colors.red.shade400
        : day.weekday == DateTime.saturday
            ? Colors.blue.shade400
            : Colors.black87;

    final cell = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.6)
              : Colors.black.withValues(alpha: 0.08),
          width: isSelected ? 1.5 : 0.5,
        ),
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.10)
            : isToday
                ? Colors.blue.withValues(alpha: 0.06)
                : null,
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
        ],
      ),
    );

    if (onTap == null) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: cell,
    );
  }
}

enum _AddType { memo, todoList }

/// 「+」タップで出るアクションシート: メモ作成 / ToDoリスト作成 を選ぶ
class _AddActionSheet extends StatelessWidget {
  final DateTime day;
  const _AddActionSheet({required this.day});

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];
    final wd = weekdayLabels[day.weekday - 1];
    final wdColor = day.weekday == DateTime.sunday
        ? Colors.red.shade400
        : day.weekday == DateTime.saturday
            ? Colors.blue.shade400
            : Colors.black87;
    return GestureDetector(
      // 枠外タップでシートを閉じる
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                // ダイアログ本体内のタップは外側に伝搬させない
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          children: [
                            Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Hiragino Sans',
                                  color: Colors.black87,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${day.year}年${day.month}月${day.day}日',
                                  ),
                                  TextSpan(
                                    text: '($wd)',
                                    style: TextStyle(color: wdColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _AddSquareButton(
                                icon: Icons.note_outlined,
                                iconColor: Colors.amber.shade700,
                                label: 'メモ',
                                onTap: () => Navigator.of(context)
                                    .pop(_AddType.memo),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AddSquareButton(
                                icon: Icons.checklist,
                                iconColor: Colors.green.shade600,
                                label: 'ToDoリスト',
                                onTap: () => Navigator.of(context)
                                    .pop(_AddType.todoList),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSquareButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _AddSquareButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.08),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Hiragino Sans',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 10),
              // 丸で囲まれた + マーク
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.45),
                      width: 1.2),
                ),
                child: Icon(
                  Icons.add,
                  size: 14,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
