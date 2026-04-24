import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../screens/home_screen.dart' show GridSizeOption;

/// メモ一覧グリッドに混在表示するToDoカード
/// 本家TodoCardView準拠: しおり + タイトル + "ToDo" + 件数
class TodoCard extends ConsumerWidget {
  final TodoList todoList;
  final VoidCallback onTap;
  final bool isHighlighted;
  final GridSizeOption gridSize;
  // メモカードと同じ仕組みでオレンジ枠フラッシュさせる
  final double flashLevel;
  // 外側で左上にチェックボックスが出るとき、結合マークを右へずらす
  final bool selectModeActive;

  const TodoCard({
    super.key,
    required this.todoList,
    required this.onTap,
    this.isHighlighted = false,
    this.gridSize = GridSizeOption.grid2x3,
    this.flashLevel = 0,
    this.selectModeActive = false,
  });

  // メモカードと完全一致のサイズ可変ロジック
  double get _titleFont => switch (gridSize) {
        GridSizeOption.grid3x6 => 13,
        GridSizeOption.grid2x5 => 15,
        GridSizeOption.grid2x3 => 16,
        GridSizeOption.grid1x2 => 17,
        GridSizeOption.grid1flex => 16,
        GridSizeOption.titleOnly => 14,
      };

  double get _bodyFont => switch (gridSize) {
        GridSizeOption.grid3x6 => 13,
        GridSizeOption.grid2x5 => 14,
        GridSizeOption.grid2x3 => 14,
        GridSizeOption.grid1x2 => 15,
        GridSizeOption.grid1flex => 14,
        GridSizeOption.titleOnly => 12,
      };

  double get _cardPadding => switch (gridSize) {
        GridSizeOption.grid3x6 => 4,
        GridSizeOption.grid2x5 => 8,
        GridSizeOption.grid2x3 => 10,
        GridSizeOption.grid1x2 => 12,
        GridSizeOption.grid1flex => 10,
        GridSizeOption.titleOnly => 6,
      };

  // しおりアイコンはタイトル font に合わせて 2px 程度小さく
  double get _bookmarkSize => _titleFont - 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    // ルートアイテムをwatch
    final rootStream = (db.select(db.todoItems)
          ..where(
              (t) => t.listId.equals(todoList.id) & t.parentId.isNull()))
        .watch();

    return StreamBuilder<List<TodoItem>>(
      stream: rootStream,
      builder: (context, snap) {
        final items = snap.data ?? const <TodoItem>[];
        final total = items.length;
        final done = items.where((i) => i.isDone).length;

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.all(_cardPadding),
            // フラッシュ枠は foregroundDecoration で中身に重ねてレイアウトを変えない
            foregroundDecoration: flashLevel > 0
                ? BoxDecoration(
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: flashLevel * 0.7),
                        width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Colors.blue.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // タイトル行: しおり + タイトル
                    Row(
                      children: [
                        Icon(CupertinoIcons.bookmark_fill,
                            size: _bookmarkSize, color: Colors.orange),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            todoList.title.isEmpty
                                ? '(無題)'
                                : todoList.title,
                            style: TextStyle(
                              fontSize: _titleFont,
                              fontWeight: todoList.title.isEmpty
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                              color: todoList.title.isEmpty
                                  ? Colors.grey.withValues(alpha: 0.5)
                                  : const Color(0xFF2D1F50), // 黒寄り紫
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // titleOnly モードではタイトルのみ表示（仕切り線・件数は省略）
                    if (gridSize != GridSizeOption.titleOnly) ...[
                      // 仕切り線（メモカード準拠: 0.5px グレー）
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.only(top: 4, bottom: 3),
                        color: Colors.grey.withValues(alpha: 0.6),
                      ),
                      // "ToDo" + 件数（本文相当）
                      Row(
                        children: [
                          Text(
                            'ToDo',
                            style: TextStyle(
                              fontSize: _bodyFont,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Hiragino Sans',
                              color: Colors.green,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$done/$total件',
                            style: TextStyle(
                              fontSize: _bodyFont,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Hiragino Sans',
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                // ピン・ロックアイコン（右上）
                if (todoList.isPinned || todoList.isLocked)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (todoList.isPinned)
                          Icon(Icons.push_pin,
                              size: 8,
                              color: Colors.orange.withValues(alpha: 0.6)),
                        if (todoList.isPinned && todoList.isLocked)
                          const SizedBox(width: 2),
                        if (todoList.isLocked)
                          Icon(Icons.lock,
                              size: 8,
                              color: Colors.orange.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                // 結合で生成されたリスト: しおり上端寄り (カード上端から 3/4 位置) に配置
                // 水平は しおり中心 x = _cardPadding + _bookmarkSize/2 (通常時)
                // 垂直は しおり上端(y=_cardPadding)の 3/4 位置 y=_cardPadding*0.75
                // 12px アイコンの中心をそこに合わせる → top = _cardPadding*0.75 - 6
                // 選択モード中は外側のチェックボックス(-6,-6,24px→右端x=18)との
                // 重なりを避けるため x=20 へ逃がす
                if (todoList.isMerged)
                  Positioned(
                    left: selectModeActive
                        ? 20
                        : _cardPadding + _bookmarkSize / 2 - 6,
                    top: _cardPadding * 0.75 - 6,
                    child: const Icon(
                      Icons.merge_type,
                      size: 12,
                      color: Color(0xFF007AFF),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
