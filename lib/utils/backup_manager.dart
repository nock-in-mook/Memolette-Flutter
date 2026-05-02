import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// SQLite データベースのバックアップ管理。
/// Phase 9 同期実装に先立つデータ保護のセーフティネット。
///
/// - スナップショット作成: 起動時 1日1回 + ユーザー手動
/// - 復元: 任意のスナップショットから上書き（要アプリ再起動）
/// - エクスポート: SQLite ファイルを Documents 直下にコピー
///   （iOS は Files App、Android はファイラーから救出可能）
class BackupManager {
  static const _dbFileName = 'memolette.sqlite';
  static const _backupDirName = 'backups';
  static const _backupPrefix = 'memolette.sqlite.bak.';
  static const _exportPrefix = 'memolette-export-';
  static const _maxSnapshots = 7;
  static const _autoSnapshotIntervalHours = 24;

  /// SQLite 本体のパス
  static Future<String> dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  /// バックアップディレクトリ（存在しなければ作成）
  static Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _backupDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 現在の DB を別ファイルにコピー
  /// 戻り値: 作成したファイルのパス（DB が無ければ null）
  static Future<String?> createSnapshot() async {
    final src = File(await dbPath());
    if (!await src.exists()) return null;
    final dir = await _backupDir();
    final ts = _timestamp(DateTime.now(), withSeconds: true);
    final destPath = p.join(dir.path, '$_backupPrefix$ts');
    await src.copy(destPath);
    return destPath;
  }

  /// 起動時セーフティネット: 最後のスナップショットから 24 時間以上経って
  /// いれば作る。作成後、古いものは _maxSnapshots を超えた分削除。
  /// 何もしない場合は null を返す（呼び出し側でログ出すか判断）。
  static Future<String?> createSnapshotIfNeeded() async {
    final snapshots = await listSnapshots();
    if (snapshots.isNotEmpty) {
      final last = snapshots.first;
      final age = DateTime.now().difference(last.statSync().modified);
      if (age.inHours < _autoSnapshotIntervalHours) return null;
    }
    final path = await createSnapshot();
    if (path != null) {
      await pruneOldSnapshots(_maxSnapshots);
    }
    return path;
  }

  /// スナップショット一覧（更新日時降順）
  static Future<List<File>> listSnapshots() async {
    final dir = await _backupDir();
    final entries = await dir.list().toList();
    final files = entries
        .whereType<File>()
        .where((e) => p.basename(e.path).startsWith(_backupPrefix))
        .toList();
    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// 古いスナップショットを削除（最新 keep 個を残す）
  static Future<int> pruneOldSnapshots(int keep) async {
    final list = await listSnapshots();
    var removed = 0;
    for (var i = keep; i < list.length; i++) {
      try {
        await list[i].delete();
        removed++;
      } catch (_) {}
    }
    return removed;
  }

  /// バックアップから復元（現在の DB を上書き）。
  /// 復元前に現在の状態を「直前バックアップ」として残しておく安全装置あり。
  /// 呼び出し側でアプリ再起動の案内が必要。
  static Future<void> restoreSnapshot(File backup) async {
    if (!await backup.exists()) {
      throw Exception('バックアップファイルが見つかりません: ${backup.path}');
    }
    // 念のため、復元前に現在の DB をスナップショット
    await createSnapshot();
    final dst = File(await dbPath());
    await backup.copy(dst.path);
  }

  /// SQLite ファイルを Documents 直下にコピー（iOS Files から見える場所）。
  /// 戻り値: コピー先のパス
  static Future<String> exportToDocumentsRoot() async {
    final src = File(await dbPath());
    if (!await src.exists()) {
      throw Exception('DB ファイルがありません');
    }
    final docs = await getApplicationDocumentsDirectory();
    final ts = _timestamp(DateTime.now(), withSeconds: false);
    final destPath = p.join(docs.path, '$_exportPrefix$ts.sqlite');
    await src.copy(destPath);
    return destPath;
  }

  /// 過去のエクスポート一覧（更新日時降順）
  static Future<List<File>> listExports() async {
    final docs = await getApplicationDocumentsDirectory();
    final entries = await docs.list().toList();
    final files = entries
        .whereType<File>()
        .where((e) => p.basename(e.path).startsWith(_exportPrefix))
        .toList();
    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// 表示用のラベル: "2026/05/03 01:23 (123.4 KB)"
  static String formatLabel(File f) {
    final stat = f.statSync();
    final t = stat.modified;
    final ts = '${t.year}/${_p2(t.month)}/${_p2(t.day)} ${_p2(t.hour)}:${_p2(t.minute)}';
    final kb = (stat.size / 1024).toStringAsFixed(1);
    return '$ts ($kb KB)';
  }

  static String _p2(int v) => v.toString().padLeft(2, '0');

  static String _timestamp(DateTime t, {required bool withSeconds}) {
    final base = '${t.year.toString().padLeft(4, '0')}'
        '${_p2(t.month)}${_p2(t.day)}'
        '-${_p2(t.hour)}${_p2(t.minute)}';
    if (withSeconds) return '$base${_p2(t.second)}';
    return base;
  }
}
