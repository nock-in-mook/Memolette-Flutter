import 'package:flutter/material.dart';

/// 「すべて」タブの上部フィルタタブ デザイン比較ラボ
/// 各案を縦に並べて見比べ、選択中の挙動も試せる
class AllTabFilterLabScreen extends StatefulWidget {
  const AllTabFilterLabScreen({super.key});

  @override
  State<AllTabFilterLabScreen> createState() => _AllTabFilterLabScreenState();
}

class _AllTabFilterLabScreenState extends State<AllTabFilterLabScreen> {
  // 各案ごとに独立した選択状態を持たせる
  final Map<String, int> _selected = {};

  static const _items = ['すべて', 'よく見る', '最近見た', 'タグなし'];

  int _sel(String key) => _selected[key] ?? 0;
  void _setSel(String key, int v) => setState(() => _selected[key] = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('すべてフィルタ ラボ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          _section(
            '0. 現状（仕切り線 + 青文字太字）',
            _CurrentStyle(
              items: _items,
              selected: _sel('current'),
              onTap: (i) => _setSel('current', i),
            ),
          ),
          _section(
            '1. iOS Segmented Control 風',
            _SegmentedStyle(
              items: _items,
              selected: _sel('segmented'),
              onTap: (i) => _setSel('segmented', i),
            ),
          ),
          _section(
            '2. アンダーライン式タブ',
            _UnderlineStyle(
              items: _items,
              selected: _sel('underline'),
              onTap: (i) => _setSel('underline', i),
            ),
          ),
          _section(
            '3. ピル状（選択中だけ青ピル）',
            _PillStyle(
              items: _items,
              selected: _sel('pill'),
              onTap: (i) => _setSel('pill', i),
            ),
          ),
          _section(
            '4. アイコン+テキスト（縦）',
            _IconTextStyle(
              items: _items,
              selected: _sel('icontext'),
              onTap: (i) => _setSel('icontext', i),
            ),
          ),
          _section(
            '5. チップ（全部に枠 / 選択中は塗り）',
            _ChipStyle(
              items: _items,
              selected: _sel('chip'),
              onTap: (i) => _setSel('chip', i),
            ),
          ),
          _section(
            '6. ドット付き（選択中の左に小さい丸）',
            _DotStyle(
              items: _items,
              selected: _sel('dot'),
              onTap: (i) => _setSel('dot', i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ---- 0. 現状 ----
class _CurrentStyle extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  const _CurrentStyle(
      {required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Text('0件',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600)),
            const SizedBox(width: 10),
            Text('フィルタ：',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600)),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Container(
                          width: 1, height: 12, color: Colors.grey.shade300),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Text(
                          items[i],
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: selected == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected == i
                                ? const Color(0xFF007AFF)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- 1. iOS Segmented Control 風 ----
class _SegmentedStyle extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  const _SegmentedStyle(
      {required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF4),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: selected == i ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: selected == i
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            selected == i ? FontWeight.w600 : FontWeight.w500,
                        color: selected == i
                            ? Colors.black87
                            : Colors.grey.shade600,
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

// ---- 2. アンダーライン式 ----
class _UnderlineStyle extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  const _UnderlineStyle(
      {required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        items[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected == i
                              ? const Color(0xFF007AFF)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (selected == i)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 4,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- 3. ピル状 ----
class _PillStyle extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  const _PillStyle(
      {required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Wrap(
        spacing: 6,
        children: [
          for (int i = 0; i < items.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected == i
                      ? const Color(0xFF007AFF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  items[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected == i ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected == i ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- 4. アイコン+テキスト ----
class _IconTextStyle extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  const _IconTextStyle(
      {required this.items, required this.selected, required this.onTap});

  static const _icons = [
    Icons.list_alt,
    Icons.local_fire_department_outlined,
    Icons.history,
    Icons.label_off_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _icons[i],
                      size: 18,
                      color: selected == i
                          ? const Color(0xFF007AFF)
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected == i
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected == i
                            ? const Color(0xFF007AFF)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- 5. チップ ----
class _ChipStyle extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  const _ChipStyle(
      {required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Wrap(
        spacing: 6,
        children: [
          for (int i = 0; i < items.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected == i
                      ? const Color(0xFF007AFF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == i
                        ? const Color(0xFF007AFF)
                        : Colors.grey.shade400,
                    width: 1,
                  ),
                ),
                child: Text(
                  items[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        selected == i ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected == i ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- 6. ドット付き ----
class _DotStyle extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onTap;
  const _DotStyle(
      {required this.items, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: selected == i ? 6 : 0,
                        height: 6,
                        margin: EdgeInsets.only(right: selected == i ? 4 : 0),
                        decoration: const BoxDecoration(
                          color: Color(0xFF007AFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        items[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected == i
                              ? const Color(0xFF007AFF)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
