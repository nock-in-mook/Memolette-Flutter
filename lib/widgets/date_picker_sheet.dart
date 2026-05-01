import 'package:flutter/material.dart';

import 'dialog_styles.dart';

/// 日付ピッカーシートの結果。
/// - cleared = true: 「カレンダーから消去」ボタンが押された（eventDate を null にする指示）
/// - date != null: 選択された日付
/// - 戻り値が null: シートが何もせずに閉じられた（キャンセル / 枠外タップ）
class DatePickerResult {
  final DateTime? date;
  final bool cleared;
  const DatePickerResult({this.date, this.cleared = false});
}

/// カスタム日付ピッカー（標準 showDatePicker は使わない方針）。
/// メモ／ToDo の eventDate 設定・変更・クリアに使う。
/// - initial を渡すと「カレンダーから消去」ボタンが下段に出る
/// - initial が null（新規付与）の場合は当日が初期選択
Future<DatePickerResult?> showCustomDatePickerSheet(
  BuildContext context, {
  DateTime? initial,
}) {
  return showModalBottomSheet<DatePickerResult?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _DatePickerSheet(initial: initial),
  );
}

class _DatePickerSheet extends StatefulWidget {
  final DateTime? initial;
  const _DatePickerSheet({this.initial});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  static const int _monthsBefore = 6;
  static const int _monthsAfter = 12;

  /// 月ブロックの実際の高さを計算。
  /// 内訳: 外側 padding 4*2 + 内側 vertical padding 8*2 + 月見出し 22 + weeksCount × 36
  static double _calcMonthHeight(DateTime month) {
    final firstDayWeekday = month.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = firstDayWeekday + daysInMonth;
    final weeksCount = (totalCells / 7).ceil();
    return 8 + 16 + 22 + weeksCount * 36;
  }

  late DateTime _selected; // initial or 当日
  late final DateTime _today;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selected = widget.initial != null
        ? DateTime(widget.initial!.year, widget.initial!.month,
            widget.initial!.day)
        : _today;
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth(animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 選択中の月を viewport の中央に来るようスクロール。
  /// 月ブロックの高さが月ごとに異なる（4-6週）ので、累積で offset を計算する。
  void _scrollToSelectedMonth({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final monthsFromBase = ((_selected.year - _today.year) * 12) +
        (_selected.month - _today.month) +
        _monthsBefore;
    // 選択月の上端までの累積高さ
    double accumulated = 0;
    for (int i = 0; i < monthsFromBase; i++) {
      final m =
          DateTime(_today.year, _today.month + i - _monthsBefore);
      accumulated += _calcMonthHeight(m);
    }
    final selectedMonthHeight = _calcMonthHeight(_selected);
    final viewportH = _scrollController.position.viewportDimension;
    // 中央配置: 月ブロックの上端を viewport の (viewportH - 月高さ) / 2 に
    final offset = (accumulated - (viewportH - selectedMonthHeight) / 2)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  /// 「本日」ボタン: 選択を当日に + 当月までスクロール
  void _jumpToToday() {
    setState(() => _selected = _today);
    _scrollToSelectedMonth();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 枠外タップで閉じる
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        // 下端固定で上端だけ下げる: bottomCenter + 高さ縮小
        // (上下それぞれ約 1 列分 = 36pt 程度を削った高さ)
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: FractionallySizedBox(
              heightFactor: 0.74,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GestureDetector(
                  // シート内タップは外側に伝搬させない
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildPreviewHeader(),
                        const Divider(height: 1),
                        _buildWeekdayRow(),
                        Expanded(child: _buildScrollableMonths()),
                        const Divider(height: 1),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewHeader() {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    final wd = labels[_selected.weekday - 1];
    final wdColor = _selected.weekday == DateTime.sunday
        ? Colors.red.shade400
        : _selected.weekday == DateTime.saturday
            ? Colors.blue.shade400
            : Colors.black87;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 上段: 左に refresh アイコン（本日へジャンプ） + 中央にタイトル
          Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _jumpToToday,
                  child: Icon(
                    Icons.refresh,
                    size: 20,
                    color: Colors.blue.shade400,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '日付を指定',
                      style: DialogStyles.title,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '（カレンダーに表示されます）',
                      style: DialogStyles.message.copyWith(
                        fontSize: 10,
                        color: DialogStyles.textGreyLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 6),
          // 下段: 選択日プレビュー
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Hiragino Sans',
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                    text:
                        '${_selected.year}年${_selected.month}月${_selected.day}日'),
                TextSpan(text: '($wd)', style: TextStyle(color: wdColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const labels = ['日', '月', '火', '水', '木', '金', '土'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
      child: Row(
        children: List.generate(7, (i) {
          final color = i == 0
              ? Colors.red.shade400
              : i == 6
                  ? Colors.blue.shade400
                  : Colors.black54;
          return Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScrollableMonths() {
    final months = <DateTime>[];
    for (int i = -_monthsBefore; i <= _monthsAfter; i++) {
      months.add(DateTime(_today.year, _today.month + i));
    }
    return Container(
      color: Colors.grey.shade200,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: months.length,
        // 月ごとに高さが違うので itemExtent は固定にしない
        itemBuilder: (ctx, i) => _MonthBlock(
          month: months[i],
          selected: _selected,
          onDayTap: (date) => setState(() => _selected = date),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final hasInitial = widget.initial != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          // 上段: キャンセル / 決定
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    side: BorderSide(
                      color: Colors.grey.shade400,
                      width: 0.8,
                    ),
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'キャンセル',
                    style: DialogStyles.actionLabel,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(
                    DatePickerResult(date: _selected),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    side: const BorderSide(
                      color: Colors.orange,
                      width: 0.8,
                    ),
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '決定',
                    style: DialogStyles.actionLabel
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          // 下段: カレンダーから消去（initial 指定 = 既に日付付与済み時のみ）
          if (hasInitial)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(
                    const DatePickerResult(cleared: true),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    side: BorderSide(
                      color: Colors.red.shade300,
                      width: 0.8,
                    ),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'カレンダーから消去',
                    style: DialogStyles.actionLabel
                        .copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 月ブロック: 白カードの中に月見出し + 日付グリッド（Row × N）
class _MonthBlock extends StatelessWidget {
  final DateTime month;
  final DateTime? selected;
  final ValueChanged<DateTime> onDayTap;

  const _MonthBlock({
    required this.month,
    required this.selected,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayWeekday = month.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = firstDayWeekday + daysInMonth;
    final weeksCount = (totalCells / 7).ceil();

    // 月の実際の週数だけ表示（4 / 5 / 6）。空行を出さず月ごとに高さが変わる。
    final rows = <Widget>[];
    for (int week = 0; week < weeksCount; week++) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final cellIndex = week * 7 + col;
        if (cellIndex < firstDayWeekday || cellIndex >= totalCells) {
          cells.add(const Expanded(child: SizedBox(height: 36)));
          continue;
        }
        final day = cellIndex - firstDayWeekday + 1;
        final date = DateTime(month.year, month.month, day);
        cells.add(Expanded(
          child: _DayCell(
            date: date,
            selected: selected,
            onTap: () => onDayTap(date),
          ),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: cells),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                '${month.year}年${month.month}月',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  fontFamily: 'Hiragino Sans',
                ),
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DateTime? selected;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected != null &&
        date.year == selected!.year &&
        date.month == selected!.month &&
        date.day == selected!.day;
    final weekday = date.weekday;
    final color = weekday == DateTime.sunday
        ? Colors.red.shade400
        : weekday == DateTime.saturday
            ? Colors.blue.shade400
            : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? Colors.white : color,
              fontFamily: 'Hiragino Sans',
            ),
          ),
        ),
      ),
    );
  }
}
