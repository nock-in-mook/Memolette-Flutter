# 引き継ぎメモ

## 現在の状況

- **セッション#38 完了**（2026-05-03、Phase 9 同期の核心部分を一気に実装）
- ブランチ: **`main`**
- Phase 9 同期: **Step 5e 競合履歴 + Phase A 即時同期 + タグ同期 + ToDo 同期** まで完成
- 残: **画像同期 / 削除の同期 / Step 4 サブスク**
- iPhone 13 mini / iPhone SE 3 シミュで実競合・実時同期テスト済み

## #38 サマリ（テーマ別）

### Step 5e: 競合解決 UI
- 新テーブル `ConflictHistories`（schemaVersion 6→7）
- `downloadAllMemos` で「両方が直近6時間以内 + 内容差分」を競合判定 → 履歴記録
- 競合一覧/詳細画面 (`conflict_history_screen.dart`)、上限 200件、超過分は古いもの自動削除
- 「現在のメモをこの内容で上書き」復元ボタン（復元前に現在内容も履歴に残す）
- 設定 → データ保護 → 「競合履歴」エントリから到達
- 全削除アイコン: `CupertinoIcons.delete_simple` (赤) で他画面と統一

### 競合検出の双方向化
- `downloadAllMemos` で「ローカル勝ち」分岐でもリモートを失われた側として記録
- 結果、同期した端末で「相手の編集を上書きした」を即時把握できる
- 一覧表示は **端末非依存**（現在のメモタイトル + 日時のみ）に統一
- 詳細から lostSide ラベル撤去（タップすれば負けた本文表示）

### Phase A: 即時同期（リアルタイム購読 + debounce アップロード）
- `SyncService.startRealtimeSync`: users/{uid}/memos / tags / todoLists を `snapshotChanges()` で購読
- `SyncService.scheduleUpload`: 編集 1.5秒 debounce でメモ単体アップロード
- 自端末アップロード由来の発火は fingerprint で除外
- 初回 snapshot の全件 added 通知は抑制（`syncOnce` 既取り込み済みなので）
- HomeScreen で `authStateProvider` を ref.listen → ログイン状態変化で自動 start/stop
- リアルタイム受信時のトースト通知は **撤去**（メモ自体が即時反映されるので不要）

### タグ同期 (T1: マスター + T2: メモ-タグ関連)
- `Tags.updatedAt` カラム追加（schemaVersion 7→8）
  - SQLite の ALTER TABLE が「NOT NULL + 非const デフォルト」を許さないため、
    `customStatement` で `DEFAULT 0` 追加 → 既存行を `strftime('%s','now')` で UPDATE
- `SyncService` にタグ系メソッド一式（uploadAllTags / downloadAllTags / uploadOneTag / scheduleUploadTag）
- `syncOnce` は **タグ → メモ → ToDo** の順で同期（メモ側のタグ参照が解決される順序）
- リアルタイム購読 `_realtimeTagsSub` 追加
- `createTag / updateTag / reorderParentTags / addTagToMemo / removeTagFromMemo` で `scheduleUploadTag` を即時呼び出し
- メモ doc に `tagIds: [...]` 配列を含める（`_memoToMap` に optional 引数）
- ダウンロード/リアルタイム受信時に `setTagIdsForMemo` でローカル memo_tags を全置換
- 未到着タグは skip（タグマスター先行が前提）

### ToDo 同期（TodoLists + TodoItems + TodoListTags）
- 設計: **TodoLists doc に items + tagIds を埋め込む（A 案）**
  - 1リスト=1ドキュメント、items の孤児化なし
  - `_todoListToMap(list, items, tagIds)` / `_extractTodoItems(data, listId)`
  - TodoItemTags（アイテム個別タグ）は今回スコープ外
- `SyncService.scheduleUploadTodoList(db, listId)`: 内部で `touchTodoListUpdatedAt` → debounce upload
- リアルタイム購読 `_realtimeTodoListsSub` 追加
- `database` の補助関数: `setTodoItemsForList` / `setTagIdsForTodoList` / `getTagIdsForTodoList` / `touchTodoListUpdatedAt`
- 既存 ToDo 関数（`createTodoItem` / `mergeTodoLists` / `createTodoList` / `addTagToTodoList` / `removeTagFromTodoList` / `setTodoListEventDate` / `setTodoListBgColor` / `setTodoItemEventDate`）で `scheduleUploadTodoList` 即時呼び出し
- UI 側散在箇所も対応:
  - `todo_list_screen.dart`: アイテム追加/編集/削除/チェック/メモ保存/タイトル保存/全リセット/全削除/並び替え すべて
  - `home_screen.dart` / `todo_lists_screen.dart`: ピン留め/ロック切替

### バグ修正
- **同名タグ複数で `getSingleOrNull` 例外** (起動時クラッシュ)
  - `seedDummyBulkMemos` / `seedLongMemos` / `createTag` の同名検索を `get()` に変更し
    `isNotEmpty` / `first` で扱う

### コミット履歴 (#38 全7本)
1. `feat(sync): Phase 9 Step 5e 競合履歴 UI 実装`
2. `feat(sync): 競合検出を双方向化 + 履歴ラベルを意味ベースに`
3. `feat(sync): Phase A 即時同期（リアルタイム購読 + debounce アップロード）`
4. `feat(sync): リアルタイム受信トースト表示を撤去`
5. `feat(conflict): 競合履歴を端末非依存表示 + 200件上限 + 全削除赤色化`
6. `fix(conflict): 削除アイコンを CupertinoIcons.delete_simple に統一`
7. `feat(sync): タグ同期 (T1: タグマスター + T2: メモ-タグ関連)`
8. `fix(migration): tags.updatedAt の追加で SQLite ALTER 制約を customStatement で回避`
9. `feat(sync): ToDo 同期 (TodoLists + TodoItems + TodoListTags)`
10. `fix(seed): 同期で同名タグが複数存在する場合 getSingleOrNull が例外を投げるバグ修正`

## 次のアクション（次セッション #39）

### Phase 9 残タスク
- [ ] **画像同期** (タスク#2 残)
  - `MemoImages` テーブル + Firebase Storage に画像本体
  - 設計判断: 画像 base64 で Firestore (NG, 1MB制限) vs Storage URL（推奨、無料枠 5GB）
  - 同期されるのは `MemoImages` メタ情報 + Storage の URL
  - メモ doc に `imageUrls: [...]` を含めるパターンが自然
- [ ] **削除の同期** (タスク#3)
  - ローカル削除 → Firestore も削除（hard delete）or tombstone 方式
  - hard delete だと「同期前の他端末で復活」が起きる可能性 → tombstone 推奨
  - Tombstone collection `users/{uid}/deletedMemos/{memoId}` に削除時刻を記録
  - 各端末は tombstone を読んで該当メモをローカルからも削除
- [ ] **Step 4: サブスク** (タスク#4)
  - RevenueCat / in_app_purchase

### 既知の現象（運用上の注意）
- **両端末で独立 seed → 同名タグ・メモが別 id で重複作成**
  - createTag 重複防止は同端末内のみ。別端末から同名タグが流入 → 重複で並ぶ
  - 「全データ削除（Firestore も）→ 片端末だけ起動 → 他端末起動」でクリーンに同期される
  - リリース時は seed を入れない方針なので非問題
- リアルタイム受信時、別端末からの新規メモは「タグなし」で来ることがある（タグマスター未到着のタイミング）
  - 自動的に少し後で再同期されてタグ付くケースも、付かないケースもある
  - 暫定対処: 同期相手のタグマスター先行 + setTagIdsForMemo の skip ガード

### 残タスク（ROADMAP「備忘」より、引き継ぎ）
- データ保護画面のダイアログ文言検討（バックアップ作成成功時 / Documents エクスポート成功時 / 復元前の確認 / 復元後の再起動案内）
- Firestore セキュリティルールを「テストモード」から本番ルールに書き換え（30日以内）
- データ保護画面の「復元」改修: ワンクッション化

### 実機検証の積み残し
- 13 mini シミュ起動済み（pipe: `/tmp/flutter_pipe_13`）
- iPhone SE 3 シミュ起動済み（pipe: `/tmp/flutter_pipe_se`）
- iPad / 15 Pro Max wireless 接続不安定

## 技術メモ

### Phase A 即時同期のフロー
1. 編集 → `db.updateMemo()` (memos テーブル更新)
2. `_onChanged()` 内で `SyncService.scheduleUpload(db, memoId)` 呼び出し
3. 1.5秒 debounce → `uploadOneMemo` 実行
4. `_registerSelfUpload(memoId, updatedAt)` でフィンガープリント登録（30秒キャッシュ）
5. 別端末: `_realtimeMemosSub` の listener で受信
6. 自端末フィルタチェック → 一致なら skip、しなければローカル DB に upsert + tagIds 反映

### タグ同期の順序
- `syncOnce`: **download(タグ) → upload(タグ) → download(メモ) → upload(メモ) → download(ToDo) → upload(ToDo)**
- リアルタイムは並列起動（tags listener / memos listener / todoLists listener）
- メモ doc の tagIds 反映時、ローカルにタグマスターが無ければ skip
  - 通常はタグマスター同期が先に走るので問題ないが、タイミング依存
  - 暫定: `setTagIdsForMemo` の `knownIds` チェックで対応

### ToDo 同期の設計判断
- **TodoLists doc に items + tagIds 埋め込み** (A 案採用)
- 利点: 1リスト=1ドキュメント、孤児化なし、操作単位が認知単位と一致
- 欠点: 1MB 制限（数百項目まで OK、数千項目で破綻）
- 現実的な ToDo 規模（数十項目）には十分

### SQLite ALTER TABLE 制約の罠
- drift の `m.addColumn` は `currentDateAndTime` のような非const デフォルトを使うと
  `Cannot add a column with non-constant default` で失敗
- 対処: `customStatement` で `DEFAULT 0` で NOT NULL 追加 → `UPDATE` で初期値セット

### Firestore コスト見積（Phase A 導入後）
- 1ユーザー1日メモ100回更新 → 月 ~3000 書き込み
- 無料枠: 5万書き込み/日。圧倒的に余裕
- 同期上限の懸念は今のところなし（タグ・ToDo 含めても安全圏）

### シミュ / 実機 ID
- iPhone SE 3rd iOS26: `47003836-6426-4AB1-90FC-C5E73DA251C1`
- iPhone 13 mini iOS26: `B5B2C694-8EAB-4C14-AA4D-8BCE464CE49D`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`
- iPad（のっくりのiPad、wireless）: `00008103-000470C63E04C01E`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`

### Mac で `py` コマンドはない
- グローバル CLAUDE.md の Python 実行ルールは Windows 用。Mac では `python3` で代用
- 例: `python3 "/Users/nock_re/...マイドライブ/_claude-sync/transcript_export.py" --latest`

## 関連メモ（自動メモリ）

- `feedback_dialog_style.md`: AskUserQuestion の選択肢形式は使わず自然な対話
- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウトは新機能で動かさない
- `build_workaround.md`: Google Drive 上では codesign エラー → `/tmp/memolette-run` 経由
