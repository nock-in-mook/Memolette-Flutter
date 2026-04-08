import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// アイコン比較ラボ
/// 候補アイコンを並べて見比べるための画面
class IconLabScreen extends StatelessWidget {
  const IconLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('アイコンラボ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _IconSection(
            title: 'ゴミ箱（Material）',
            icons: [
              _IconItem('delete', Icons.delete),
              _IconItem('delete_outline', Icons.delete_outline),
              _IconItem('delete_outlined', Icons.delete_outlined),
              _IconItem('delete_forever', Icons.delete_forever),
              _IconItem('delete_forever_outlined', Icons.delete_forever_outlined),
              _IconItem('delete_sweep', Icons.delete_sweep),
              _IconItem('delete_sweep_outlined', Icons.delete_sweep_outlined),
              _IconItem('auto_delete', Icons.auto_delete),
              _IconItem('auto_delete_outlined', Icons.auto_delete_outlined),
            ],
          ),
          SizedBox(height: 24),
          _IconSection(
            title: 'グリッド数表示（Material）',
            icons: [
              _IconItem('grid_view', Icons.grid_view),
              _IconItem('grid_view_outlined', Icons.grid_view_outlined),
              _IconItem('grid_on', Icons.grid_on),
              _IconItem('grid_on_outlined', Icons.grid_on_outlined),
              _IconItem('dashboard', Icons.dashboard),
              _IconItem('dashboard_outlined', Icons.dashboard_outlined),
              _IconItem('apps', Icons.apps),
              _IconItem('apps_outlined', Icons.apps_outlined),
              _IconItem('window', Icons.window),
              _IconItem('window_outlined', Icons.window_outlined),
              _IconItem('view_module', Icons.view_module),
              _IconItem('view_module_outlined', Icons.view_module_outlined),
              _IconItem('view_quilt', Icons.view_quilt),
              _IconItem('view_compact', Icons.view_compact),
              _IconItem('view_comfy', Icons.view_comfy),
              _IconItem('view_agenda', Icons.view_agenda),
              _IconItem('calendar_view_month', Icons.calendar_view_month),
            ],
          ),
          SizedBox(height: 24),
          _IconSection(
            title: 'グリッド数表示（Cupertino）',
            icons: [
              _IconItem('square_grid_2x2', CupertinoIcons.square_grid_2x2),
              _IconItem('square_grid_3x2', CupertinoIcons.square_grid_3x2),
              _IconItem('square_grid_4x3_fill', CupertinoIcons.square_grid_4x3_fill),
              _IconItem('rectangle_grid_2x2', CupertinoIcons.rectangle_grid_2x2),
              _IconItem('rectangle_grid_1x2', CupertinoIcons.rectangle_grid_1x2),
              _IconItem('rectangle_grid_3x2', CupertinoIcons.rectangle_grid_3x2),
              _IconItem('square_split_2x2', CupertinoIcons.square_split_2x2),
              _IconItem('square_split_2x1', CupertinoIcons.square_split_2x1),
              _IconItem('square_grid_2x2_fill', CupertinoIcons.square_grid_2x2_fill),
            ],
          ),
          SizedBox(height: 24),
          _IconSection(
            title: 'ゴミ箱（Cupertino / iOS風）',
            icons: [
              _IconItem('trash', CupertinoIcons.trash),
              _IconItem('trash_fill', CupertinoIcons.trash_fill),
              _IconItem('delete', CupertinoIcons.delete),
              _IconItem('delete_solid', CupertinoIcons.delete_solid),
              _IconItem('delete_simple', CupertinoIcons.delete_simple),
              _IconItem('delete_right', CupertinoIcons.delete_right),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconItem {
  final String label;
  final IconData icon;
  const _IconItem(this.label, this.icon);
}

class _IconSection extends StatelessWidget {
  final String title;
  final List<_IconItem> icons;

  const _IconSection({required this.title, required this.icons});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: icons.map((item) => _IconTile(item: item)).toList(),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final _IconItem item;

  const _IconTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(item.icon, size: 28, color: Colors.grey[700]),
          const SizedBox(height: 8),
          Text(
            item.label,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
