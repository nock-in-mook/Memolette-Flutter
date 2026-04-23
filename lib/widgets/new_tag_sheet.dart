import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/keyboard_done_bar.dart';
import '../utils/safe_dialog.dart';
import '../utils/text_menu_dismisser.dart';
import 'trapezoid_tab_shape.dart';

/// タグシート（Swift版 NewTagSheetView 準拠）
///
/// モード:
/// - 親タグ追加: 引数なし
/// - 子タグ追加: parentTagId
/// - 既存タグ編集: editingTag
/// - 特殊タブ(すべて/タグなし)の色変更: specialLabel + specialInitialColorIndex + onSpecialColorSaved
///
/// 確定時は対象タグの id をPopの戻り値として返す（特殊タブの場合は null）。
class NewTagSheet extends ConsumerStatefulWidget {
  final String? parentTagId;
  final Tag? editingTag;
  final String? specialLabel;
  final int specialInitialColorIndex;
  final ValueChanged<int>? onSpecialColorSaved;
  final String initialName;
  final int initialColorIndex;

  const NewTagSheet({
    super.key,
    this.parentTagId,
    this.editingTag,
    this.specialLabel,
    this.specialInitialColorIndex = 0,
    this.onSpecialColorSaved,
    this.initialName = '',
    this.initialColorIndex = 1,
  });

  /// モーダルボトムシートで開くヘルパー。完了時に対象タグIDを返す。
  /// 画面高の約 75% を占める大きなシート。カラーパレットまで最初から見える位置。
  /// キーボード表示時はシート外枠は動かさず、内側コンテンツだけを上に寄せる
  /// （= 編集中に位置がガタつかない）。
  static Future<String?> show({
    required BuildContext context,
    String? parentTagId,
    Tag? editingTag,
    String? specialLabel,
    int specialInitialColorIndex = 0,
    ValueChanged<int>? onSpecialColorSaved,
  }) {
    return focusSafe(
      context,
      () => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        // 背景を透明にして、内部でBackdropFilter（すりガラス）を適用する
        backgroundColor: Colors.transparent,
        // 背景の暗幕は薄く（背後のUIをうっすら透けさせる）
        barrierColor: Colors.black.withValues(alpha: 0.15),
        builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final screenH = mq.size.height;
        final keyboardH = mq.viewInsets.bottom;
        final visibleH = screenH * 0.75;
        final maxVisible = screenH - mq.padding.top - 10;
        final sheetH =
            visibleH > maxVisible && maxVisible > 0 ? maxVisible : visibleH;
        return SuppressKeyboardDoneBar(child: SizedBox(
          height: sheetH,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            child: BackdropFilter(
              // すりガラス効果（iOS UIBlurEffect.systemMaterial 相当）
              // sigma小さめで形が軽く残るくらいに
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                // 半透明の白で軽くカバー
                color: Colors.white.withValues(alpha: 0.65),
                // 内側だけキーボード分上に詰める（外枠は動かない）
                child: Padding(
                  padding: EdgeInsets.only(bottom: keyboardH),
                  child: NewTagSheet(
                    parentTagId: parentTagId,
                    editingTag: editingTag,
                    specialLabel: specialLabel,
                    specialInitialColorIndex: specialInitialColorIndex,
                    onSpecialColorSaved: onSpecialColorSaved,
                  ),
                ),
              ),
            ),
          ),
        ));
        },
      ),
    );
  }

  @override
  ConsumerState<NewTagSheet> createState() => _NewTagSheetState();
}

class _NewTagSheetState extends ConsumerState<NewTagSheet> {
  final _nameController = TextEditingController();
  int _selectedColorIndex = 1;
  static const int _maxNameLength = 20;

  bool get _isEdit => widget.editingTag != null;
  bool get _isSpecial => widget.specialLabel != null;
  bool get _isChild =>
      widget.parentTagId != null || widget.editingTag?.parentTagId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameController.text = widget.editingTag!.name;
      _selectedColorIndex = widget.editingTag!.colorIndex;
    } else if (_isSpecial) {
      _nameController.text = widget.specialLabel!;
      _selectedColorIndex = widget.specialInitialColorIndex;
    } else {
      _nameController.text = widget.initialName;
      _selectedColorIndex = widget.initialColorIndex;
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _trimmed => _nameController.text.trim();

  bool _isDuplicate(List<Tag> all) {
    if (_trimmed.isEmpty) return false;
    final ownParent =
        widget.editingTag?.parentTagId ?? widget.parentTagId;
    return all.any(
      (t) =>
          t.parentTagId == ownParent &&
          t.name == _trimmed &&
          t.id != widget.editingTag?.id,
    );
  }

  Future<void> _save() async {
    // 特殊タブ: 色変更コールバック
    if (_isSpecial) {
      widget.onSpecialColorSaved?.call(_selectedColorIndex);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // 念のため save 時にも重複チェック（canSave で弾けているはずの二重防御）
    final all = ref.read(allTagsProvider).value ?? const <Tag>[];
    if (_isDuplicate(all)) return;
    // 編集モード
    if (_isEdit) {
      final name = _trimmed;
      if (name.isEmpty) return;
      final db = ref.read(databaseProvider);
      await db.updateTag(
        id: widget.editingTag!.id,
        name: name,
        colorIndex: _selectedColorIndex,
      );
      if (mounted) Navigator.of(context).pop(widget.editingTag!.id);
      return;
    }
    // 新規作成
    final name = _trimmed;
    if (name.isEmpty) return;
    final db = ref.read(databaseProvider);
    final tag = await db.createTag(
      name: name,
      colorIndex: _selectedColorIndex,
      parentTagId: widget.parentTagId,
    );
    if (mounted) {
      Navigator.of(context).pop(tag.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final duplicate = _isDuplicate(allTags);
    // 特殊タブは色変更だけなので常に保存可能
    final canSave = _isSpecial || (_trimmed.isNotEmpty && !duplicate);

    return KeyboardDoneBar(child: Column(
      children: [
        _buildHeader(canSave: canSave),
        // 仕切り線なし（Swift版同様に余白で区切る）
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 特殊タブはタブ名固定なので名前欄は出さない
                if (!_isSpecial) ...[
                  _buildNameField(duplicate: duplicate),
                  const SizedBox(height: 20),
                ],
                _buildPreview(),
                const SizedBox(height: 20),
                _buildColorPalette(),
              ],
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildHeader({required bool canSave}) {
    // タイトルとサブタイトルをモードごとに切り替え
    String title;
    String? subtitle;
    if (_isSpecial) {
      title = '色を変更';
      subtitle = '「${widget.specialLabel}」フォルダ';
    } else if (_isEdit) {
      title = _isChild ? '子タグを編集' : '親タグを編集';
      if (!_isChild) subtitle = '（フォルダの編集）';
    } else {
      title = _isChild ? '子タグの追加' : '親タグの追加';
      if (!_isChild) subtitle = '（フォルダの追加）';
    }

    // iOSナビゲーションバー風: 余白多め、仕切り線なし
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          // 中央タイトル
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 左: キャンセル
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                'キャンセル',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ),
          // 右: 確定
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: TextButton(
              onPressed: canSave ? _save : null,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF007AFF),
                disabledForegroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                '確定',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField({required bool duplicate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'タグ名',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          maxLength: _maxNameLength,
          onTap: TextMenuDismisser.wrap(null),
          contextMenuBuilder: TextMenuDismisser.builder,
          // 自動フォーカスしない（Swift版同様、ユーザータップでキーボードが出る）
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'タグ名を入力（20文字まで）',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: duplicate
                    ? Colors.red
                    : Colors.grey.withValues(alpha: 0.3),
                width: duplicate ? 1.5 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: duplicate
                    ? Colors.red
                    : Colors.grey.withValues(alpha: 0.3),
                width: duplicate ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: duplicate
                    ? Colors.red
                    : Colors.grey.withValues(alpha: 0.5),
                width: duplicate ? 1.5 : 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (duplicate) ...[
              const Icon(Icons.error_outline, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                _isChild
                    ? 'このフォルダ内に同じ名前の子タグが既にあります'
                    : '同じ名前の親タグが既にあります',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            Text(
              '${_nameController.text.characters.length}/$_maxNameLength',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }

  /// プレビュー（親=フォルダタブ形状、子=タグバッジ）
  Widget _buildPreview() {
    final color = TagColors.getColor(_selectedColorIndex);
    // 特殊タブ・編集中は名前固定/初期値あり、新規はトリム値
    final displayName = _isSpecial
        ? widget.specialLabel!
        : (_trimmed.isEmpty ? ' ' : _trimmed);
    final isEmpty = !_isSpecial && _trimmed.isEmpty;

    if (_isChild) {
      // 子タグはバッジ風プレビュー
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isEmpty ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isEmpty ? Colors.transparent : Colors.black,
            ),
          ),
        ),
      );
    }

    // 親タグはフォルダタブ形状（タグ名が入るまで非表示）
    return Center(
      child: Opacity(
        opacity: isEmpty ? 0 : 1,
        child: CustomPaint(
          painter: TrapezoidTabPainter(
            color: color,
            shadows: const [
              Shadow(
                color: Color(0x4D000000),
                offset: Offset(-3, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Text(
              displayName,
              strutStyle: const StrutStyle(
                fontSize: 16,
                height: 1.0,
                forceStrutHeight: true,
                leading: 0,
              ),
              style: const TextStyle(
                fontSize: 16,
                height: 1.0,
                fontFamily: 'Hiragino Sans',
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'カラー',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        // 選択中の色名
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: TagColors.getColor(_selectedColorIndex),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              TagColors.getName(_selectedColorIndex),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 8列x9行 = 72色
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 72,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: 26,
          ),
          itemBuilder: (context, i) {
            final index = i + 1;
            final selected = index == _selectedColorIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedColorIndex = index),
              child: Container(
                decoration: BoxDecoration(
                  color: TagColors.getColor(index),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
