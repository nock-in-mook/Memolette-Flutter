import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/responsive.dart';
import '../utils/safe_dialog.dart';
import 'day_items_panel.dart';

/// カレンダーで現在オーバーレイ表示中の日付。
///
/// CalendarView の State じゃなく Provider に持つ理由:
/// home_screen の `_isEditingCompact`（メモ編集コンパクトモード）が立つと
/// CalendarView が条件外で unmount → State の `_selectedDay` が消失して
/// キーボード閉じた後にパネルが再表示されない問題があったため。
/// Provider 化で、CalendarView が remount されても選択状態を保持する。
final calendarSelectedDayProvider =
    StateProvider<DateTime?>((ref) => null);

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
  // 選択中の日付は calendarSelectedDayProvider で管理（CalendarView remount 越しに保持）

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // 今日の日付がスクロールビューの「見えている範囲の中央くらい」に
      // 来るように初期位置を計算する（SE 3rd 等の縦が短い機種でも
      // 今日のセルが画面外にならないように）。
      // - 今日の月の上端: _approxMonthHeight * _monthsBefore
      // - 月内の今日の週インデックス（日曜始まり）を加味
      // - viewport 中央に合わせる
      final firstDay = DateTime(_today.year, _today.month, 1);
      final firstWeekdaySunBase = firstDay.weekday % 7; // 0=Sun, 1=Mon...
      final weekIndex =
          ((_today.day - 1) + firstWeekdaySunBase) ~/ 7;
      const headerH = 36.0; // 月ヘッダ概算
      const weekH = (_approxMonthHeight - headerH) / 6;
      final monthTop = _approxMonthHeight * _monthsBefore;
      final todayY = monthTop + headerH + weekIndex * weekH;
      final viewportH = _scrollController.position.viewportDimension;
      final offset = todayY - viewportH / 2 + weekH / 2;
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
      ref.read(calendarSelectedDayProvider.notifier).state = day;
      return;
    }
    // メモ入力欄のフォーカスを外しておかないと、編集モード突入の副作用が出る
    FocusManager.instance.primaryFocus?.unfocus();
    if (count == 0) {
      // 何もない日は新規作成アクションに直行
      _handleAddTap(day);
    } else {
      // カレンダー下半分に DayItemsPanel をオーバーレイ表示（非モーダル）
      // → 上のメモ入力エリアも触れる、ToDo へ遷移して戻ってもパネルは残る
      ref.read(calendarSelectedDayProvider.notifier).state = day;
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
    switch (type) {
      case _AddType.memo:
        await _createMemoForDay(day);
      case _AddType.todoList:
        await _createTodoListForDay(day);
    }
  }

  Future<void> _createMemoForDay(DateTime day) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final db = ref.read(databaseProvider);
    final memo = await db.createMemo(eventDate: day);
    if (!mounted) return;
    widget.onMemoCreated(memo);
  }

  Future<void> _createTodoListForDay(DateTime day) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final db = ref.read(databaseProvider);
    final list = await db.createTodoList(eventDate: day);
    if (!mounted) return;
    widget.onTodoListTap(list);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(calendarSelectedDayProvider);
    final calendarList = _buildCalendarList(selectedDay);
    if (Responsive.isWide(context)) {
      // 横画面では右カラムに常時 DayItemsPanel
      final day = selectedDay ?? _today;
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
              day: day,
              onMemoTap: widget.onMemoTap,
              onTodoListTap: widget.onTodoListTap,
              onAddMemo: () => _createMemoForDay(day),
              onAddTodoList: () => _createTodoListForDay(day),
            ),
          ),
        ],
      );
    }
    // 縦画面: 日付タップで下半分に DayItemsPanel をオーバーレイ（非モーダル）
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            calendarList,
            if (selectedDay != null) ...[
              // 背景を暗くする半透明オーバーレイ（タップで閉じる）
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref
                      .read(calendarSelectedDayProvider.notifier)
                      .state = null,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
            if (selectedDay != null)
              Positioned(
                left: 24,
                right: 24,
                top: 16,
                bottom: 24,
                child: Material(
                  elevation: 16,
                  color: Colors.lightBlue.shade50,
                  shadowColor: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: DayItemsPanel(
                    day: selectedDay,
                    onMemoTap: widget.onMemoTap,
                    onTodoListTap: widget.onTodoListTap,
                    onAddMemo: () => _createMemoForDay(selectedDay),
                    onAddTodoList: () => _createTodoListForDay(selectedDay),
                    onClose: () => ref
                        .read(calendarSelectedDayProvider.notifier)
                        .state = null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarList(DateTime? selectedDay) {
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
        selectedDay: selectedDay,
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
    final summariesAsync = ref.watch(eventSummariesForRangeProvider(
      (start: monthStart, end: monthEnd),
    ));
    final summaries =
        summariesAsync.valueOrNull ?? const <DateTime, DaySummary>{};

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
        final summary = summaries[day] ?? const DaySummary();
        final count = summary.memoCount + summary.todoCount;
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
            summary: summary,
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
  final DaySummary summary;
  final bool isToday;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.summary,
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

    final hasMemo = summary.memoCount > 0;
    final hasTodo = summary.todoCount > 0;

    final cell = DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            // 日付数字（中央寄せ、当日は青丸）
            Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 18),
              decoration: isToday
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade500,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Hiragino Sans',
                  color: isToday ? Colors.white : weekdayColor,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // メモ帯（オレンジ）
            if (hasMemo)
              _DayBand(
                color: Colors.orange.shade400,
                label: summary.firstMemoLabel ?? '',
                count: summary.memoCount,
              ),
            if (hasMemo && hasTodo) const SizedBox(height: 2),
            // ToDo 帯（緑）
            if (hasTodo)
              _DayBand(
                color: Colors.green.shade500,
                label: summary.firstTodoLabel ?? '',
                count: summary.todoCount,
              ),
          ],
        ),
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

/// セル内の帯（メモ=オレンジ / ToDo=緑）。横幅いっぱい、下部に配置、複数件は右端にバッジ。
class _DayBand extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _DayBand({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 13,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.fromLTRB(3, 0, 2, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.isEmpty ? '無題' : label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Hiragino Sans',
                height: 1.1,
              ),
              overflow: TextOverflow.clip,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          if (count > 1) ...[
            const SizedBox(width: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Hiragino Sans',
                  height: 1.1,
                ),
              ),
            ),
          ],
        ],
      ),
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
                                label: 'ToDo',
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
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: iconColor),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Hiragino Sans',
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // グレー丸 + 白抜き + ボタン
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade400,
                ),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 18,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
