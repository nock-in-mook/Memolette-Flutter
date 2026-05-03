# 引き継ぎメモ

## 現在の状況

- **セッション#37 完了**（2026-05-02 〜 05-03、超長め・27コミット）
- ブランチ: **`main`**
- Phase 9 同期実装に着手。Step 1〜3 と Step 5a〜5d まで実装。タグ・ToDo・画像同期 / 競合解決 / サブスクは未対応
- iPad 13 mini SE シミュで動作確認

## #37 サマリ（テーマ別）

### 爆速モードのカード本文 BlockEditor 化
- TextField を BlockEditor に置換、画像インライン表示・追加対応
- 爆速モード用ツールバー widget 新規（消しゴム / 画像 / Undo / Redo）+ Overlay 表示
- 「完了」ボタンは KeyboardDoneBar 任せ（accessoryHeight 設定）
- memo_input_area の `_syncAccessoryHeight` で「自分のフォーカスがない時は触らない」ガード追加（爆速 Overlay と完了ボタンが重なる問題）
- 画像追加: ライブラリは 5 枚まで複数選択可（pickMultiImage）
- 消しゴムで画像も削除（DB の deleteAllMemoImages 追加）

### メモカードの画像サムネを右端固定
- 本文の長短に依らず常に「タイトル+区切り線直下、右端」に配置
- 外側 Stack で Positioned 絶対配置（top = `_bodyTopY`）

### 爆速モードカード以外の余白フリック / ToDo 余白タップで unfocus
- 爆速モード: Expanded 全体を GestureDetector(translucent) で wrap
- ToDo: 既存 Listener.onPointerDown に primary.unfocus() を統合（Positioned.fill 方式は ListView の hit test に阻まれて動かなかった）

### iPad 回転時に編集モードを維持
- `_HomeScreenState` に `WidgetsBindingObserver` mixin 追加
- `didChangeMetrics` で size 変化を MediaQuery 更新前に検知 → `_suppressFalseFocus` を 2 フレーム立てる
- `onFocusChanged` で suppress 中は true→false 上書きを無視
- `didChangeDependencies` で orientation 変化を検知して refocusContent / refocusTitle
- `refocusContent` を `_blockEditorKey.currentState?.focusFirst()` に書き換え（_contentFocusNode はダミー化済み）

### iPad 選択モードバナー位置調整
- 縦画面 iPad: 中央寄せ + maxWidth 600
- 横画面 iPad: ルート Stack に Positioned 配置で前面化、left:0 / right: maxWidth/2 で左カラム内に制限、top = viewPadTop + 6

### ToDo iPad 横画面の左カラム緑背景
- Stack に StackFit.expand 追加で画面下端まで塗る

### 多機能ボタン → Icons.more_horiz
- 27 候補を「多機能アイコンラボ」で比較、Material 標準の more_horiz を採用
- size 20 → 22（円が無くなった分の比重補正）

### データ保護機能（Phase 9 Step 1）
- `lib/utils/backup_manager.dart` 新規
  - createSnapshot / createSnapshotIfNeeded（24h 経過時のみ）
  - listSnapshots / pruneOldSnapshots（最新7個まで保持）
  - restoreSnapshot（復元前に現在状態も自動 snapshot）
  - exportToDocumentsRoot（iOS Files App から救出可能）
- `lib/screens/data_protection_screen.dart` 新規（一覧 / 手動バックアップ / エクスポート / 復元 / 削除）
- 設定 > データ保護 エントリ追加
- HomeScreen.initState で `BackupManager.createSnapshotIfNeeded()` を fire-and-forget

### Firebase 連携（Phase 9 Step 2-3）
- Firebase プロジェクト `memolette-3a68b` 作成
- flutterfire configure で iOS / Android / Web 3プラットフォーム登録
- Authentication: Google + Apple 有効化（メール/パスワードは見送り）
- iOS Info.plist に GoogleSignIn 用の URL Scheme（REVERSED_CLIENT_ID）追加
- Firestore Database 作成（asia-northeast1、テストモード）
- pubspec: firebase_core / firebase_auth / cloud_firestore / google_sign_in (v6) /
  sign_in_with_apple / firebase_ui_auth / firebase_ui_oauth_google / firebase_ui_oauth_apple
- main.dart で Firebase.initializeApp（失敗時もアプリ続行）
- `lib/services/auth_service.dart` 新規（authStateProvider, GoogleProvider/AppleProvider）
- `lib/screens/account_screen.dart` 新規（未ログイン: LoginView / ログイン済み: ユーザー情報+ログアウト）

### Firestore 同期（Phase 9 Step 5a-5d）
- `lib/services/sync_service.dart` 新規
  - 5a: `pingFirestore` — users/{uid} に lastPingAt 書き込み読み戻し
  - 5b: `uploadAllMemos` — ローカル全メモを users/{uid}/memos に batch write（merge=true）
  - 5c: `downloadAllMemos` — Firestore→ローカル、updatedAt 比較で新しい方を採用、既存は `batch.replace`(UPDATE) / 新規は `batch.insert`
    - **重要**: `insertOrReplace` は SQLite REPLACE で「DELETE→INSERT」になり、memo_tags が孤児化（タグ全削除）するため必ず分岐する
  - 5d: `syncOnce` — ダウンロード→アップロード を順次。同時実行ガード `_syncing`
- HomeScreen の initState postFrame と `didChangeAppLifecycleState(resumed)` で `_autoSync` を fire-and-forget
- AccountScreen に動作確認用4ボタン（接続テスト / アップロード / ダウンロード / 今すぐ同期）

### データ消失バグ対策（多重ガード）
1. `downloadAllMemos`: insertOrReplace → 既存 replace(UPDATE)（タグ孤児化防止）
2. `_onChanged` の空メモ削除: タグ・eventDate・bgColor ガード追加（BlockEditor reload 中の一瞬空でタグ付き削除されないように）
3. `_onFocusChange` の空メモ削除: 同様ガード追加 + activeMemoId が `widget.editingMemoId ?? _selfCreatedMemoId` を見るように
4. `loadMemoDirectly`: タグ反映ガード緩和（editingMemoId が null=親未更新でも反映、縮小ビューでタグバッジが表示されない問題）
5. `purgeEmptyMemos`: タグ・色・eventDate 持ちは候補から除外
6. `_clearInput`: `_selfCreatedMemoId = null` クリア追加（次の入力で確実に新メモ作成）
7. `_onChanged`: `widget.editingMemoId ?? _selfCreatedMemoId` で memoId 判定し、自作メモにも updateMemo を走らせる（onMemoCreated 通知後の数フレーム間の入力ロスト防止）
8. DB 削除系関数（deleteMemo / deleteMemos / purgeEmptyMemos / removeTagFromMemo）に StackTrace 付き print を仕込み（再現時にフローを追える）

### dummy seed 増殖バグ修正
- `seedDummyBulkMemos` が「同名タグがあっても、タイトル付きメモが count 未満なら補充」していた → メモが何かの理由で減ると毎起動で 70 件まるごと再投入されてダミー増殖
- 修正: 同名タグがあれば一切 seed しない
- main.dart の起動 seed をダミー70・長文・画像のみに絞る（仕事/日記等の親タグ・子タグ・タグ履歴は外す）

### 全データ削除（Firestore 連携対応）
- 既存ボタンが `db.wipeAll` のみだったので、Firestore users/{uid}/memos の batch 削除も含めるよう拡張
- 削除後はアプリ完全終了→再起動で seed が再実行されて綺麗な初期状態に

## 次のアクション（次セッション #38）

### Phase 9 残タスク
- [ ] **Step 5e: 競合解決 UI**（最終更新優先 + 競合履歴の閲覧）
- [ ] **タグ・ToDo・画像の同期**（メモ本体だけしか同期していないため、別デバイスで「タグなし」状態になってしまう）
- [ ] **削除の同期**（ローカル削除しても Firestore には残るため、再ダウンロードで復活する）
- [ ] **Step 4: サブスク**（RevenueCat / in_app_purchase）

### 同期で発生中の既知の現象
- 「ダミー70-069」 のタイトルを編集 → スイッチャーOFF → 再起動 で1度メモが消える事象を観測（タグも外れて「すべて」フォルダにも出ない、ただし Firestore には残ってて再同期で復活）
- 多重ガード追加で再現しなくなったが、タイミング依存の競合状態が他にも潜んでいる可能性あり
- 削除系関数のログ仕込みは残してあるので、再現時はフローを追跡可能

### 残タスク（ROADMAP「備忘」より）
- データ保護画面のダイアログ文言検討（バックアップ作成成功時 / Documents エクスポート成功時 / 復元前の確認 / 復元後の再起動案内）
- Firestore セキュリティルールを「テストモード」から本番ルールに書き換える（30日以内、Phase 9 同期実装と並行）
- データ保護画面の「復元」改修: 一覧から直タップではなく、「復元」ボタンを置いて押した先でバックアップ一覧→選択→確認ダイアログ、のワンクッション構成に

### 実機検証の積み残し
- 13 mini シミュは起動したまま（pipe: `/tmp/flutter_pipe_13`）
- iPad Pro 12.9 シミュも起動可（pipe: `/tmp/flutter_pipe_ipad`）。この session 中は kill 済み
- iPhone SE 3 シミュ（pipe: `/tmp/flutter_pipe_se`）。同期検証用に起動した
- 15 Pro Max / iPad は wireless 接続が前回不安定で実機未確認

## 技術メモ

### Firebase プロジェクト情報
- プロジェクト ID: `memolette-3a68b`
- iOS Bundle: `com.memolette.memolette`
- Auth プロバイダ: Google + Apple（テストモード SecurityRules、30日間オープン）
- Firestore リージョン: asia-northeast1（東京）

### iOS Sign-In セットアップ手順
1. flutterfire configure で `lib/firebase_options.dart` 自動生成
2. iOS の場合は xcodeproj gem 必要 → `gem install --user-install xcodeproj`
3. ios/Runner/Info.plist に CFBundleURLTypes で REVERSED_CLIENT_ID を追加
4. pod install で Firebase pods (40件くらい)

### SQLite REPLACE の罠
- `Batch.insert(table, companion, mode: InsertMode.insertOrReplace)` は内部的に
  REPLACE で「既存行 DELETE → INSERT」になる。ここで子テーブル（memo_tags 等）の
  外部キーが ON DELETE CASCADE でないと孤児化（タグが全部外れる）する
- 既存は `batch.replace(table, companion)` (UPDATE)、新規は `batch.insert` に
  分岐する。`localById.containsKey(id)` で判定

### 起動時 dummy seed のガード設計
- 既存タグの存在チェックだけで判断。「件数比較で補充」 はバグの温床（メモが減ると再投入される）
- main.dart で seed を絞る方針（タグ・履歴は手動投入に）

### シミュ / 実機 ID
- iPhone SE 3rd iOS26: `47003836-6426-4AB1-90FC-C5E73DA251C1`
- iPhone 13 mini iOS26: `B5B2C694-8EAB-4C14-AA4D-8BCE464CE49D`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`
- iPad（のっくりのiPad、wireless）: `00008103-000470C63E04C01E`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`

### Mac で `py` コマンドはない
- グローバル CLAUDE.md の Python 実行ルールは Windows 用。Mac では `python3` で代用

## 関連メモ（自動メモリ）

- `feedback_dialog_style.md`: AskUserQuestion の選択肢形式は使わず自然な対話
- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウトは新機能で動かさない
- `build_workaround.md`: Google Drive 上では codesign エラー → `/tmp/memolette-run` 経由
