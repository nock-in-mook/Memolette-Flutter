import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/frosted_alert_dialog.dart';

/// 同期で「上書きされて失われた側」の内容を一覧する画面（Phase 9 Step 5e）。
/// 詳細から「現在のメモをこの内容で復元」できる。
/// 履歴は最大 [AppDatabase.conflictHistoryMaxCount] 件まで保持。
class ConflictHistoryScreen extends ConsumerWidget {
  const ConflictHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConflicts = ref.watch(allConflictsProvider);
    final memos = ref.watch(allMemosProvider).valueOrNull ?? const <Memo>[];
    final memoTitleById = {for (final m in memos) m.id: m.title};
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('競合履歴'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            tooltip: '全削除',
            onPressed: () => _onDeleteAll(context, ref),
          ),
        ],
      ),
      body: asyncConflicts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込みエラー: $e')),
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.merge_type,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      '競合履歴はありません',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '別の端末で同じメモを同時に編集したとき、'
                      '上書きされた方の内容がここに記録されます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: conflicts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = conflicts[i];
              return _ConflictTile(
                conflict: c,
                winnerTitle: memoTitleById[c.memoId],
                memoExists: memoTitleById.containsKey(c.memoId),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onDeleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: '競合履歴を全削除',
      message: '競合履歴をすべて削除します。元には戻せません。',
      confirmLabel: '全削除',
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    await db.deleteAllConflicts();
  }
}

class _ConflictTile extends StatelessWidget {
  final ConflictHistory conflict;
  final String? winnerTitle; // 現在のメモタイトル（勝者）
  final bool memoExists;
  const _ConflictTile({
    required this.conflict,
    required this.winnerTitle,
    required this.memoExists,
  });

  @override
  Widget build(BuildContext context) {
    // 一覧の表示タイトルは「現在のメモタイトル(=勝者)」を出す。
    // すべての端末で同じ表示になるよう、lostSide に依存した表記はしない。
    final String title;
    if (!memoExists) {
      title = '(削除済みメモ)';
    } else if (winnerTitle == null || winnerTitle!.isEmpty) {
      title = '(無題)';
    } else {
      title = winnerTitle!;
    }
    return ListTile(
      leading:
          const Icon(Icons.history_toggle_off, size: 22, color: Colors.grey),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
        _fmtDateTime(conflict.recordedAt),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ConflictDetailScreen(conflictId: conflict.id),
        ));
      },
    );
  }
}

/// 競合詳細画面: 失われた側の本文を表示し、復元できる。
class ConflictDetailScreen extends ConsumerStatefulWidget {
  final int conflictId;
  const ConflictDetailScreen({super.key, required this.conflictId});

  @override
  ConsumerState<ConflictDetailScreen> createState() =>
      _ConflictDetailScreenState();
}

class _ConflictDetailScreenState extends ConsumerState<ConflictDetailScreen> {
  bool _busy = false;
  ConflictHistory? _conflict;
  Memo? _currentMemo;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final c = await db.getConflictById(widget.conflictId);
    Memo? m;
    if (c != null) {
      m = await db.getMemoById(c.memoId);
    }
    if (!mounted) return;
    setState(() {
      _conflict = c;
      _currentMemo = m;
      _loaded = true;
    });
  }

  Future<void> _onRestore() async {
    final c = _conflict;
    if (c == null) return;
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: '現在のメモを上書き',
      message: 'このメモを以下の内容で上書きします。\n'
          '現在の内容は失われます（このあと別の競合履歴として残ります）。',
      confirmLabel: '上書きする',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final current = await db.getMemoById(c.memoId);
      if (current == null) {
        if (!mounted) return;
        showFrostedAlert(
          context: context,
          title: '復元できません',
          message: '対象のメモが既に削除されています。',
        );
        return;
      }
      // 復元前に「今の内容」も lost 側として記録する
      await db.recordConflict(
        memoId: c.memoId,
        lostSide: 'local',
        lostTitle: current.title,
        lostContent: current.content,
        lostUpdatedAt: current.updatedAt,
        winnerUpdatedAt: DateTime.now(),
      );
      await db.updateMemo(
        id: c.memoId,
        title: c.lostTitle,
        content: c.lostContent,
      );
      if (!mounted) return;
      showFrostedAlert(
        context: context,
        title: '復元しました',
        message: 'メモをこの内容で上書きしました。',
      );
      // 現在メモを再ロードして表示更新
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDelete() async {
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: 'この履歴を削除',
      message: 'この競合履歴を削除します。元には戻せません。',
      confirmLabel: '削除',
    );
    if (!ok || !mounted) return;
    final db = ref.read(databaseProvider);
    await db.deleteConflict(widget.conflictId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('競合詳細'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _conflict == null
              ? const Center(child: Text('履歴が見つかりません'))
              : _buildBody(_conflict!),
    );
  }

  Widget _buildBody(ConflictHistory c) {
    final currentExists = _currentMemo != null;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _MetaRow(
                label: '失われた更新日時',
                value: _fmtDateTime(c.lostUpdatedAt)),
            _MetaRow(
                label: '勝った更新日時',
                value: _fmtDateTime(c.winnerUpdatedAt)),
            _MetaRow(
                label: '記録日時', value: _fmtDateTime(c.recordedAt)),
            const SizedBox(height: 16),
            const _SectionLabel('失われたタイトル'),
            _ReadonlyBox(
              text: c.lostTitle.isEmpty ? '(無題)' : c.lostTitle,
              isEmpty: c.lostTitle.isEmpty,
            ),
            const SizedBox(height: 16),
            const _SectionLabel('失われた本文'),
            _ReadonlyBox(
              text: c.lostContent.isEmpty ? '(本文なし)' : c.lostContent,
              isEmpty: c.lostContent.isEmpty,
            ),
            const SizedBox(height: 24),
            if (!currentExists)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '※ 現在このメモは存在しません（既に削除済）。復元すると新規作成ではなく失敗します。',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_busy || !currentExists) ? null : _onRestore,
                icon: const Icon(Icons.restore),
                label: const Text('現在のメモをこの内容で上書き'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busy ? null : _onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                label: const Text('この履歴を削除',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          ],
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyBox extends StatelessWidget {
  final String text;
  final bool isEmpty;
  const _ReadonlyBox({required this.text, required this.isEmpty});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isEmpty ? Colors.grey : Colors.black,
          fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

String _fmtDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}
