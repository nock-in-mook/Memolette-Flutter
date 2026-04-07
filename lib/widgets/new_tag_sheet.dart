import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';
import '../providers/database_provider.dart';

/// 新規タグ追加シート（Swift版 NewTagSheetView 準拠）
///
/// 親タグ追加: parentTagId == null
/// 子タグ追加: parentTagId に親タグIDを指定
///
/// 確定時は新規タグの id をPopの戻り値として返す。
class NewTagSheet extends ConsumerStatefulWidget {
  final String? parentTagId;
  final String initialName;
  final int initialColorIndex;

  const NewTagSheet({
    super.key,
    this.parentTagId,
    this.initialName = '',
    this.initialColorIndex = 1,
  });

  /// モーダルボトムシートで開くヘルパー。完了時に新規タグIDを返す。
  /// Swift版 .medium detent 相当: 画面高の約55%が見える状態。
  /// キーボード表示時はシート全体を上に伸ばし、見える領域(55%)を維持する。
  static Future<String?> show({
    required BuildContext context,
    String? parentTagId,
  }) {
    return showModalBottomSheet<String>(
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
        final visibleH = screenH * 0.55;
        final maxVisible = screenH - mq.padding.top - 10 - keyboardH;
        final actualVisible =
            visibleH > maxVisible && maxVisible > 0 ? maxVisible : visibleH;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardH),
          child: SizedBox(
            height: actualVisible,
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
                  child: NewTagSheet(parentTagId: parentTagId),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<NewTagSheet> createState() => _NewTagSheetState();
}

class _NewTagSheetState extends ConsumerState<NewTagSheet> {
  final _nameController = TextEditingController();
  int _selectedColorIndex = 1;
  static const int _maxNameLength = 20;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedColorIndex = widget.initialColorIndex;
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
    return all.any(
      (t) => t.parentTagId == widget.parentTagId && t.name == _trimmed,
    );
  }

  Future<void> _saveTag() async {
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
    final isChild = widget.parentTagId != null;
    final allTags = ref.watch(allTagsProvider).value ?? const <Tag>[];
    final duplicate = _isDuplicate(allTags);
    final canSave = _trimmed.isNotEmpty && !duplicate;

    return Column(
      children: [
        _buildHeader(isChild: isChild, canSave: canSave),
        // 仕切り線なし（Swift版同様に余白で区切る）
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNameField(duplicate: duplicate),
                const SizedBox(height: 20),
                _buildPreview(isChild: isChild),
                const SizedBox(height: 20),
                _buildColorPalette(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool isChild, required bool canSave}) {
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
                  isChild ? '子タグの追加' : '親タグの追加',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isChild) ...[
                  const SizedBox(height: 2),
                  Text(
                    '（フォルダの追加）',
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
              onPressed: canSave ? _saveTag : null,
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
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (duplicate)
              const Text(
                '同じ名前のタグが既にあります',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
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

  /// プレビュー（暫定: 親も子もタグバッジ。後で親はフォルダタブに差し替え予定）
  Widget _buildPreview({required bool isChild}) {
    final color = TagColors.getColor(_selectedColorIndex);
    final name = _trimmed.isEmpty ? ' ' : _trimmed;
    final isEmpty = _trimmed.isEmpty;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isEmpty ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(isChild ? 6 : 10),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: isChild ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: isEmpty ? Colors.transparent : Colors.black,
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
