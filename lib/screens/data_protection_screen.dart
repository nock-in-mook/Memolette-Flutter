import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../utils/backup_manager.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/frosted_alert_dialog.dart';

/// データ保護画面: バックアップ管理 + 手動エクスポート + 復元 UI。
/// Phase 9 同期に先立つセーフティネット。
class DataProtectionScreen extends StatefulWidget {
  const DataProtectionScreen({super.key});

  @override
  State<DataProtectionScreen> createState() => _DataProtectionScreenState();
}

class _DataProtectionScreenState extends State<DataProtectionScreen> {
  List<File> _snapshots = [];
  List<File> _exports = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final snaps = await BackupManager.listSnapshots();
    final exports = await BackupManager.listExports();
    if (!mounted) return;
    setState(() {
      _snapshots = snaps;
      _exports = exports;
    });
  }

  Future<void> _runBusy(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCreateSnapshot() async {
    await _runBusy(() async {
      final path = await BackupManager.createSnapshot();
      await BackupManager.pruneOldSnapshots(7);
      await _refresh();
      if (!mounted) return;
      _showInfo(path != null
          ? 'バックアップを作成しました\n${p.basename(path)}'
          : 'DB ファイルが見つかりませんでした');
    });
  }

  Future<void> _onExport() async {
    await _runBusy(() async {
      final path = await BackupManager.exportToDocumentsRoot();
      await _refresh();
      if (!mounted) return;
      _showInfo('Documents 直下にコピーしました\n${p.basename(path)}\n'
          'iOS は Files App、Android はファイラーから取り出せます');
    });
  }

  Future<void> _onRestore(File backup) async {
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: '復元します',
      message: '現在のデータを以下のバックアップで上書きします。\n'
          '念のため、復元前に現在の状態も自動バックアップします。\n'
          '復元後は アプリを完全に閉じて 再起動してください。\n\n'
          '対象: ${BackupManager.formatLabel(backup)}',
      confirmLabel: '復元',
    );
    if (!ok || !mounted) return;
    await _runBusy(() async {
      try {
        await BackupManager.restoreSnapshot(backup);
        await _refresh();
        if (!mounted) return;
        _showInfo('復元しました。アプリを完全に閉じて再起動してください。');
      } catch (e) {
        if (!mounted) return;
        _showInfo('復元に失敗しました: $e');
      }
    });
  }

  Future<void> _onDeleteSnapshot(File backup) async {
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: 'バックアップを削除',
      message: '${BackupManager.formatLabel(backup)} を削除します',
      confirmLabel: '削除',
    );
    if (!ok || !mounted) return;
    await _runBusy(() async {
      try {
        await backup.delete();
      } catch (_) {}
      await _refresh();
    });
  }

  Future<void> _onDeleteExport(File export) async {
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: 'エクスポートを削除',
      message: '${BackupManager.formatLabel(export)} を削除します',
      confirmLabel: '削除',
    );
    if (!ok || !mounted) return;
    await _runBusy(() async {
      try {
        await export.delete();
      } catch (_) {}
      await _refresh();
    });
  }

  void _showInfo(String message) {
    showFrostedAlert(
      context: context,
      title: 'データ保護',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('データ保護'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const _SectionHeader('操作'),
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: const Text('今すぐバックアップ'),
                subtitle: const Text('現在のデータをアプリ内に保存（最新7個まで保持）'),
                onTap: _busy ? null : _onCreateSnapshot,
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Documents にエクスポート'),
                subtitle: const Text('iOS Files / Android ファイラーから取り出せる場所にコピー'),
                onTap: _busy ? null : _onExport,
              ),
              const Divider(height: 24),
              const _SectionHeader('自動バックアップ（タップで復元 / 長押しで削除）'),
              if (_snapshots.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('まだバックアップはありません',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              else
                ..._snapshots.map((f) => _buildBackupTile(f, isExport: false)),
              const Divider(height: 24),
              const _SectionHeader('Documents へのエクスポート'),
              if (_exports.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('まだエクスポートはありません',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              else
                ..._exports.map((f) => _buildBackupTile(f, isExport: true)),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '同期機能は現在開発中です。データ消失リスクを最小化するため、'
                  '自動バックアップを毎日 1 回作成しています。'
                  '同期実装前に必ずエクスポートで控えを取ることを推奨します。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
      ),
    );
  }

  Widget _buildBackupTile(File f, {required bool isExport}) {
    return ListTile(
      leading: Icon(isExport ? Icons.folder_zip_outlined : Icons.history,
          size: 22, color: Colors.grey[700]),
      title: Text(p.basename(f.path),
          style: const TextStyle(fontSize: 13)),
      subtitle: Text(BackupManager.formatLabel(f),
          style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.restore, size: 20),
      onTap: isExport ? null : (_busy ? null : () => _onRestore(f)),
      onLongPress: _busy
          ? null
          : () =>
              isExport ? _onDeleteExport(f) : _onDeleteSnapshot(f),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
