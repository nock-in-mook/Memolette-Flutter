import 'package:flutter/material.dart';

import '../constants/design_constants.dart';
import '../db/database.dart';

/// タグ作成・編集ダイアログ（カスタムリッチUI��
class TagEditDialog extends StatefulWidget {
  final Tag? existingTag; // nullなら新規作成
  final String? parentTagId; // 子タグ作成時に指定

  const TagEditDialog({
    super.key,
    this.existingTag,
    this.parentTagId,
  });

  @override
  State<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<TagEditDialog> {
  late TextEditingController _nameController;
  late int _selectedColorIndex;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingTag?.name ?? '');
    _selectedColorIndex = widget.existingTag?.colorIndex ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTag != null;
    final isChild = widget.parentTagId != null ||
        widget.existingTag?.parentTagId != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CornerRadius.dialog),
          boxShadow: [AppShadows.heavy()],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー
                Text(
                  isEditing ? 'タグを編集' : (isChild ? '子タグを追加' : 'タグを追加'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // プレビュー
                Center(child: _buildTagPreview(isChild)),
                const SizedBox(height: 20),

                // タグ名入力
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'タグ名',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(CornerRadius.button),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // カラー名表示
                Center(
                  child: Text(
                    TagColors.getName(_selectedColorIndex),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // カラーパレット（8列グリッド）
                _buildColorPalette(),
                const SizedBox(height: 24),

                // ボタン
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(CornerRadius.button),
                          ),
                        ),
                        child: const Text('キャンセル'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _nameController.text.trim().isEmpty
                            ? null
                            : () => _save(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(CornerRadius.button),
                          ),
                        ),
                        child: Text(isEditing ? '保存' : '追加'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// タグプレビュー
  Widget _buildTagPreview(bool isChild) {
    final color = TagColors.getColor(_selectedColorIndex);
    final name =
        _nameController.text.isEmpty ? 'タグ名' : _nameController.text;

    if (isChild) {
      // 子タグ: 丸み帯のバッジ
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(CornerRadius.childTag),
          border: Border.all(color: TagColors.childTagBorder),
          boxShadow: [AppShadows.light()],
        ),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      );
    } else {
      // 親タグ: タブ風
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(CornerRadius.parentTag),
          boxShadow: [AppShadows.medium()],
        ),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      );
    }
  }

  /// 8列カラーパレット
  Widget _buildColorPalette() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: TagColors.palette.length,
      itemBuilder: (context, index) {
        final isSelected = index == _selectedColorIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = index),
          child: Container(
            decoration: BoxDecoration(
              color: TagColors.palette[index],
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.blueAccent, width: 2.5)
                  : null,
              boxShadow: isSelected ? [AppShadows.light()] : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.blueAccent)
                : null,
          ),
        );
      },
    );
  }

  void _save(BuildContext context) {
    final result = TagEditResult(
      name: _nameController.text.trim(),
      colorIndex: _selectedColorIndex,
      parentTagId: widget.parentTagId ?? widget.existingTag?.parentTagId,
    );
    Navigator.pop(context, result);
  }
}

/// ダイアログの戻り値
class TagEditResult {
  final String name;
  final int colorIndex;
  final String? parentTagId;

  TagEditResult({
    required this.name,
    required this.colorIndex,
    this.parentTagId,
  });
}
