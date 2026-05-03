import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/frosted_alert_dialog.dart';

/// アカウント画面: ログイン状態 + ログイン / ログアウト UI
/// 同期 (Phase 9) を ON にするにはここでログインが必要
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('アカウント'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
        data: (user) => user == null
            ? _buildSignedOut(context)
            : _buildSignedIn(context, ref, user),
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 24),
          child: Text(
            'ログインすると、複数のデバイスでメモを同期できます。\n'
            'ログインしなくても、このデバイス内ですべての機能が使えます。',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        // Firebase UI Auth が用意するソーシャルログイン用のボタン群。
        // GoogleProvider / AppleProvider を Service 側で登録済みのため、
        // このウィジェット自体は何も渡さなくても動く。
        fui.LoginView(
          action: fui.AuthAction.signIn,
          providers: authProviders(),
          showAuthActionSwitch: false,
          // メール/パスワード等を使わないので showTitle=false
          showTitle: false,
        ),
      ],
    );
  }

  Widget _buildSignedIn(BuildContext context, WidgetRef ref, User user) {
    final providerIds =
        user.providerData.map((e) => e.providerId).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 28, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? '(名前なし)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? '(メールアドレスなし)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 24),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('連携プロバイダ'),
          subtitle: Text(providerIds.join(', ')),
        ),
        ListTile(
          leading: const Icon(Icons.fingerprint),
          title: const Text('UID'),
          subtitle: Text(user.uid,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: const Text('Firestore 接続テスト'),
          subtitle: const Text('users/{uid} に lastPingAt を書き込んで読み戻す'),
          onTap: () async {
            try {
              final ts = await SyncService.pingFirestore();
              if (!context.mounted) return;
              await showFrostedAlert(
                context: context,
                title: '接続成功',
                message: 'サーバ時刻: ${ts?.toLocal() ?? "(取得失敗)"}',
              );
            } catch (e) {
              if (!context.mounted) return;
              await showFrostedAlert(
                context: context,
                title: '接続失敗',
                message: e.toString(),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: const Text('メモを Firestore にアップロード（一方向）'),
          subtitle: const Text('Step 5b: ローカルの全メモをサーバへ書き込み'),
          onTap: () async {
            try {
              final db = ref.read(databaseProvider);
              final count = await SyncService.uploadAllMemos(db);
              if (!context.mounted) return;
              await showFrostedAlert(
                context: context,
                title: 'アップロード完了',
                message: '$count 件をサーバに書き込みました',
              );
            } catch (e) {
              if (!context.mounted) return;
              await showFrostedAlert(
                context: context,
                title: 'アップロード失敗',
                message: e.toString(),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: const Text('メモを Firestore からダウンロード（一方向）'),
          subtitle: const Text(
              'Step 5c: 同 id は updatedAt 比較で新しい方を採用、ローカルだけのものはそのまま残す'),
          onTap: () async {
            try {
              final db = ref.read(databaseProvider);
              final result = await SyncService.downloadAllMemos(db);
              if (!context.mounted) return;
              await showFrostedAlert(
                context: context,
                title: 'ダウンロード完了',
                message: '新規: ${result['inserted']} 件\n'
                    '更新: ${result['updated']} 件\n'
                    'スキップ（ローカルが新しい）: ${result['skipped']} 件\n'
                    '不正: ${result['invalid']} 件',
              );
            } catch (e) {
              if (!context.mounted) return;
              await showFrostedAlert(
                context: context,
                title: 'ダウンロード失敗',
                message: e.toString(),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('今すぐ同期（双方向）'),
          subtitle: const Text(
              'Step 5d: ダウンロード → アップロードを連続実行'),
          onTap: () async {
            try {
              final db = ref.read(databaseProvider);
              final result = await SyncService.syncOnce(db);
              if (!context.mounted) return;
              if (result == null) {
                await showFrostedAlert(
                  context: context,
                  title: '同期スキップ',
                  message: '既に同期中、または未ログインです',
                );
              } else {
                await showFrostedAlert(
                  context: context,
                  title: '同期完了',
                  message: 'DL 新規: ${result['inserted']} / 更新: ${result['updated']}\n'
                      'スキップ: ${result['skipped']} / 不正: ${result['invalid']}\n'
                      'UL: ${result['uploaded']} 件',
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              await showFrostedAlert(
                context: context,
                title: '同期失敗',
                message: e.toString(),
              );
            }
          },
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextButton.icon(
            onPressed: () async {
              final ok = await showConfirmDeleteDialog(
                context: context,
                title: 'ログアウト',
                message: 'ログアウトします。\n'
                    'ローカルデータはそのまま残ります。',
                confirmLabel: 'ログアウト',
              );
              if (ok && context.mounted) {
                await AuthService.signOut();
              }
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'ログアウト',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '同期機能は現在開発中です。ログインしても、同期はまだ動作しません。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
