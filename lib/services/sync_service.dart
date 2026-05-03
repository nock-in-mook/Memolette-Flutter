import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';

/// Firestore との同期を担うサービス層。
/// Phase 9 Step 5 で段階的に拡張する：
///   - 5a: ping (この段階)
///   - 5b: メモ アップロード one-way
///   - 5c: メモ ダウンロード one-way
///   - 5d: 双方向同期
///   - 5e: 競合解決
class SyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ユーザードキュメント参照（未ログインなら null）
  static DocumentReference<Map<String, dynamic>>? _userDocRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// 動作中のプラットフォーム識別子
  static String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Firestore 接続テスト: users/{uid} に lastPingAt と platform を書き込み、
  /// その後 get で読み戻してサーバ時刻を確認する。
  /// 戻り値: サーバ側で記録された時刻 (取得失敗なら null)
  /// 例外: ログインしていない場合
  static Future<DateTime?> pingFirestore() async {
    final ref = _userDocRef();
    if (ref == null) {
      throw Exception('ログインしてください');
    }
    await ref.set({
      'lastPingAt': FieldValue.serverTimestamp(),
      'lastPingPlatform': _platformLabel(),
    }, SetOptions(merge: true));
    final snap = await ref.get();
    final ts = snap.data()?['lastPingAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  /// Memo を Firestore へ書く Map に変換
  /// DateTime は Firestore Timestamp 経由でサーバ側に保存する
  static Map<String, dynamic> _memoToMap(Memo m) {
    return {
      'id': m.id,
      'title': m.title,
      'content': m.content,
      'isMarkdown': m.isMarkdown,
      'isPinned': m.isPinned,
      'isLocked': m.isLocked,
      'manualSortOrder': m.manualSortOrder,
      'viewCount': m.viewCount,
      'bgColorIndex': m.bgColorIndex,
      'createdAt': Timestamp.fromDate(m.createdAt),
      'updatedAt': Timestamp.fromDate(m.updatedAt),
      if (m.lastViewedAt != null)
        'lastViewedAt': Timestamp.fromDate(m.lastViewedAt!),
      if (m.eventDate != null) 'eventDate': Timestamp.fromDate(m.eventDate!),
      // 同期用メタ
      'syncedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Step 5b: ローカル DB の全メモを Firestore へアップロード（one-way）
  /// users/{uid}/memos/{memoId} に batch write する。
  /// 戻り値: アップロード件数
  /// 例外: 未ログイン / ネットワーク失敗 / Firestore 書込み失敗
  static Future<int> uploadAllMemos(AppDatabase db) async {
    final userRef = _userDocRef();
    if (userRef == null) {
      throw Exception('ログインしてください');
    }
    final memos = await db.select(db.memos).get();
    if (memos.isEmpty) return 0;
    // batch write: 1 batch あたり最大 500 件まで
    const chunkSize = 400;
    var written = 0;
    for (var start = 0; start < memos.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, memos.length);
      final batch = _firestore.batch();
      for (final m in memos.sublist(start, end)) {
        final ref = userRef.collection('memos').doc(m.id);
        batch.set(ref, _memoToMap(m), SetOptions(merge: true));
      }
      await batch.commit();
      written += end - start;
    }
    // メタ情報も更新
    await userRef.set({
      'lastUploadAt': FieldValue.serverTimestamp(),
      'lastUploadCount': written,
      'lastUploadPlatform': _platformLabel(),
    }, SetOptions(merge: true));
    return written;
  }

  /// Firestore Map から Memo（drift insert/update 用 companion）に変換。
  /// 不正な形式は null を返す（id 必須）。
  static MemosCompanion? _mapToMemoCompanion(Map<String, dynamic> data) {
    final id = data['id'];
    if (id is! String || id.isEmpty) return null;
    DateTime? readDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final createdAt = readDate(data['createdAt']);
    final updatedAt = readDate(data['updatedAt']);
    if (createdAt == null || updatedAt == null) return null;
    return MemosCompanion(
      id: drift.Value(id),
      title: drift.Value((data['title'] as String?) ?? ''),
      content: drift.Value((data['content'] as String?) ?? ''),
      isMarkdown: drift.Value((data['isMarkdown'] as bool?) ?? false),
      isPinned: drift.Value((data['isPinned'] as bool?) ?? false),
      isLocked: drift.Value((data['isLocked'] as bool?) ?? false),
      manualSortOrder:
          drift.Value((data['manualSortOrder'] as num?)?.toInt() ?? 0),
      viewCount: drift.Value((data['viewCount'] as num?)?.toInt() ?? 0),
      bgColorIndex:
          drift.Value((data['bgColorIndex'] as num?)?.toInt() ?? 0),
      createdAt: drift.Value(createdAt),
      updatedAt: drift.Value(updatedAt),
      lastViewedAt: drift.Value(readDate(data['lastViewedAt'])),
      eventDate: drift.Value(readDate(data['eventDate'])),
    );
  }

  /// 競合判定の時間しきい値（Step 5e）。
  /// ローカル・リモート両方がこの時間以内に更新されていた場合に競合扱い。
  static const Duration conflictWindow = Duration(hours: 6);

  /// Step 5c: Firestore からメモをダウンロードしてローカル DB に upsert
  /// 同 id がある場合は updatedAt 比較で「リモートの方が新しい」ときのみ上書き。
  /// ローカルにあって Firestore にないメモは触らない（削除は別 Step で扱う）。
  /// Step 5e: 上書きで失われるローカル内容が直近 [conflictWindow] 以内に
  /// 編集されていた場合、conflict_histories テーブルに記録する。
  /// 戻り値: { 'inserted': N, 'updated': M, 'skipped': K, 'invalid': J, 'conflicts': C }
  static Future<Map<String, int>> downloadAllMemos(AppDatabase db) async {
    final userRef = _userDocRef();
    if (userRef == null) {
      throw Exception('ログインしてください');
    }
    final snapshot = await userRef.collection('memos').get();
    if (snapshot.docs.isEmpty) {
      return {
        'inserted': 0,
        'updated': 0,
        'skipped': 0,
        'invalid': 0,
        'conflicts': 0,
      };
    }
    // ローカル既存メモを id → updatedAt の Map に
    final localMemos = await db.select(db.memos).get();
    final localById = {for (final m in localMemos) m.id: m};

    var inserted = 0;
    var updated = 0;
    var skipped = 0;
    var invalid = 0;
    var conflicts = 0;
    final companions = <MemosCompanion>[];
    final conflictRecords = <_ConflictRecord>[];
    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      final companion = _mapToMemoCompanion(doc.data());
      if (companion == null) {
        invalid++;
        continue;
      }
      final id = companion.id.value;
      final remoteUpdated = companion.updatedAt.value;
      final local = localById[id];
      if (local == null) {
        inserted++;
        companions.add(companion);
      } else if (remoteUpdated.isAfter(local.updatedAt)) {
        // 競合判定: ローカルが直近 conflictWindow 以内に編集されていて、
        // かつ title / content の中身が異なる場合のみ「失われる側」として記録。
        // updatedAt だけ違うがタイトル/本文が同じ場合は単なる先行更新の取り込みなので
        // 競合扱いしない（履歴ノイズを避ける）。
        final remoteTitle = companion.title.value;
        final remoteContent = companion.content.value;
        final hasContentDiff =
            local.title != remoteTitle || local.content != remoteContent;
        if (hasContentDiff &&
            now.difference(local.updatedAt) <= conflictWindow) {
          conflictRecords.add(_ConflictRecord(
            memoId: id,
            lostSide: 'local',
            lostTitle: local.title,
            lostContent: local.content,
            lostUpdatedAt: local.updatedAt,
            winnerUpdatedAt: remoteUpdated,
          ));
          conflicts++;
        }
        updated++;
        companions.add(companion);
      } else if (local.updatedAt.isAfter(remoteUpdated)) {
        // ローカルが新しい：このダウンロードでは何もしないが、続く uploadAllMemos
        // でリモートが上書きされる。リモートが直近 conflictWindow 以内 + 内容違い
        // なら「失われる側 = リモート」として履歴記録する。
        // これにより同期した側の端末でも「相手の内容を上書きした」を確認できる。
        final remoteTitle = companion.title.value;
        final remoteContent = companion.content.value;
        final hasContentDiff =
            local.title != remoteTitle || local.content != remoteContent;
        if (hasContentDiff &&
            now.difference(remoteUpdated) <= conflictWindow) {
          conflictRecords.add(_ConflictRecord(
            memoId: id,
            lostSide: 'remote',
            lostTitle: remoteTitle,
            lostContent: remoteContent,
            lostUpdatedAt: remoteUpdated,
            winnerUpdatedAt: local.updatedAt,
          ));
          conflicts++;
        }
        skipped++;
      } else {
        // 同 updatedAt: 何もしない
        skipped++;
      }
    }
    if (companions.isNotEmpty) {
      // 既存メモは replace（UPDATE）、 新規メモのみ insert にする。
      // insertOrReplace を使うと SQLite の REPLACE 動作で
      // 「既存行を DELETE してから INSERT」になり、memo_tags など
      // 外部キーで参照する子レコードが孤児化（=タグが全部外れる）する。
      // これがデータ消失の直接原因なので、必ず分岐する。
      await db.batch((batch) {
        for (final c in companions) {
          final id = c.id.value;
          if (localById.containsKey(id)) {
            batch.replace(db.memos, c);
          } else {
            batch.insert(db.memos, c);
          }
        }
      });
    }
    if (conflictRecords.isNotEmpty) {
      // 競合履歴を batch insert
      await db.batch((batch) {
        for (final r in conflictRecords) {
          batch.insert(
            db.conflictHistories,
            ConflictHistoriesCompanion.insert(
              memoId: r.memoId,
              lostSide: r.lostSide,
              lostTitle: drift.Value(r.lostTitle),
              lostContent: drift.Value(r.lostContent),
              lostUpdatedAt: r.lostUpdatedAt,
              winnerUpdatedAt: r.winnerUpdatedAt,
            ),
          );
        }
      });
    }
    await userRef.set({
      'lastDownloadAt': FieldValue.serverTimestamp(),
      'lastDownloadCount': inserted + updated,
      'lastDownloadPlatform': _platformLabel(),
    }, SetOptions(merge: true));
    return {
      'inserted': inserted,
      'updated': updated,
      'skipped': skipped,
      'invalid': invalid,
      'conflicts': conflicts,
    };
  }

  /// 同時実行ガード。 syncOnce が 2 重に走らないようにする。
  static bool _syncing = false;

  /// Step 5d: 双方向同期。 「ダウンロード → アップロード」 の順で1往復。
  /// 既に走っている場合は no-op。
  /// 戻り値: 成功時に { 'downloaded': N, 'uploaded': M, ... } / 未ログインなら null
  /// 例外: 失敗時に re-throw（呼び出し側で握りつぶす場合あり）
  static Future<Map<String, int>?> syncOnce(AppDatabase db) async {
    if (_syncing) return null;
    if (FirebaseAuth.instance.currentUser == null) return null;
    _syncing = true;
    try {
      final dl = await downloadAllMemos(db);
      final upCount = await uploadAllMemos(db);
      return {
        ...dl,
        'uploaded': upCount,
      };
    } finally {
      _syncing = false;
    }
  }
}

/// 競合検出時に一時保持する内部レコード（batch insert 用）
class _ConflictRecord {
  final String memoId;
  final String lostSide;
  final String lostTitle;
  final String lostContent;
  final DateTime lostUpdatedAt;
  final DateTime winnerUpdatedAt;

  const _ConflictRecord({
    required this.memoId,
    required this.lostSide,
    required this.lostTitle,
    required this.lostContent,
    required this.lostUpdatedAt,
    required this.winnerUpdatedAt,
  });
}
