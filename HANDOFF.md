# 引き継ぎメモ

## 現在の状況

- **セッション#39 完了**(2026-05-04、Phase 9 画像同期と関連 UX 改善を実装)
- ブランチ: **`main`**
- Phase 9 同期: **画像同期** まで完成（メモ・タグ・ToDo・画像 すべて双方向リアルタイム同期）
- Firebase: **Blaze プラン化済み**（請求先アカウント名「Memolette」を新規作成、予算 ¥750/月で予算アラート設定済み）
- 残: **画像削除の同期テスト / メモ削除の同期 / Step 4 サブスク**

## #39 サマリ（テーマ別）

### Firebase Storage 有効化
- Blaze プランへアップグレード（プロジェクト用に独立した「Memolette」Cloud 請求先アカウント新規作成）
- 予算アラート ¥750/月、メール通知 50%/90%/100%
- Storage バケット作成（`gs://memolette-3a68b.firebasestorage.app`、料金不要のロケーション US-EAST1、テストモード 30日）
- pubspec.yaml に `firebase_storage: ^13.0.0` 追加

### 画像同期 (Phase 9 残タスク)
- `MemoImages` テーブルに `remoteUrl` (text, nullable) 追加（schemaVersion 8→9）
  - ALTER で nullable なので普通の `m.addColumn` で OK（前回の `tags.updatedAt` のような罠なし）
- メモ doc に `images: [{id, url, sortOrder}, ...]` 配列を埋め込む設計
- Storage パス: `users/{uid}/memo_images/{imageId}.jpg`（imageId はメモ画像 DB の id と一致）

#### `SyncService` に追加した処理
- `_imageToMap` / `_extractImages` / `_RemoteImageMeta`
- `_uploadOneImage`: 画像本体を Storage に上げて URL を MemoImages.remoteUrl に保存
- `_ensureMemoImagesUploaded`: 指定メモの未アップ画像を全部上げて最新 List<MemoImage> を返す
- `_syncImagesFromRemote(memoId, remoteImages)`: 受信メタに合わせてローカルを差分同期
  - リモートのみ → Storage から `getData()` で DL → `ImageStorage.saveBytes` → DB upsert
  - ローカルのみ → `removeMemoImageLocalOnly` で実ファイル + DB から消す
  - 両方ある → sortOrder / url 違いがあれば upsert
- `_memoToMap` に `images` パラメータ追加。`uploadOneMemo` / `uploadAllMemos` で images 配列含めて書き込み
- `downloadAllMemos` / リアルタイム購読の memos で `_extractImages` + `_syncImagesFromRemote` 呼び出し

#### `database` 補助関数
- `addMemoImage` / `deleteMemoImage` / `deleteAllMemoImages` 内で `memos.updatedAt` 更新 + `SyncService.scheduleUpload` 即時呼び出し
- `setMemoImageRemoteUrl(id, url)`: アップロード完了後の URL 反映
- `upsertMemoImageFromRemote(...)`: リモート受信用の upsert（id があれば update、なければ insert）
- `removeMemoImageLocalOnly(id)`: 同期受信由来の削除でリモート再 trigger しない版
- `watchMemoById(id)`: メモ単体の購読用 stream（memo_input_area が同期反映に使う）

### 編集中メモへの同期反映 (UI 側)
画像同期だけでは「メモを開きっぱなしの相手端末で content が古いまま」になるので、
入力画面側のリアクティブ化が必要だった。

- **`memo_input_area` に `watchMemoById` 購読**
  - 受信時に `_contentController.text` / `_titleController.text` を `_applyMemoData` で反映
  - 自端末の更新由来は値一致で skip → リモート更新だけ反映
  - フォーカスチェックは外した（自分の更新で値同じなのでループしない、競合は競合履歴で対応）
- **`block_editor` に `watchMemoImages` 購読**
  - 画像セット変化（DL 後追い等）を検知して再構築
  - 再構築時は `db.getMemoById(memoId)` で **DB の最新 content** を使う
    - `_serialize()` を使うと block_editor の現状（古いマーカー列）になり新規画像が末尾に集まる
  - `_initialized` 前は無視（初回 listener で `_blocks` 空のうちに発火 → initialContent 消失バグ防止）
  - `_resubscribeToImagesIfNeeded` を `_initAsync` 完了後に呼ぶ
  - `_suppressImagesWatch` フラグ: 自分の `addMemoImage` / `deleteMemoImage` 中は購読を一時停止
    （DB insert が `_blocks` 反映より先に listener 発火して末尾追加 / 重複削除を起こすため）

### `block_editor` の細かい UX 改善
- **画像挿入時の改行吸収**
  - 「か / 空行 / さ」の空行頭で挿入すると「か / 空行 / 画像 / 空行 / さ」になる問題
  - 画像ブロック自体が padding で1行分の空きを持つので、挿入位置直前の `\n` と直後の `\n` を1つずつ削る
- **画像 ×ボタン**
  - 編集モード時のみ表示（`!widget.readOnly` でガード）
  - ヒット領域拡大（外見 24px、padding `(8,4,8,8)` で 36×40px 相当）
  - 上方向は 4px に抑える（直上の TextBlock 末尾と干渉しない）
- **画像削除後のフォーカス復帰**
  - `_removeImageBlock` でマージ後の TextBlock にフォーカス + カーソル復帰
  - 画像があった位置にカーソルが戻り編集モード継続（キーボード閉じない）

### 詰まりポイント / 教訓
- `flutter run` のビルドキャッシュ（dill）が古いまま起動するケースあり
  - 症状: 修正済みの seedDummyBulkMemos でクラッシュ → 行番号が古いソース版
  - 対処: `rm -rf build/ .dart_tool/build` + シミュアプリ uninstall + flutter run 再起動
- `watchMemoImages` の listener 発火タイミングは drift の trigger ベースで非同期
  - addMemoImage の戻り値受け取り前に listener が走るので、ローカル状態と DB に乖離が出る
  - フラグ管理 + `_initialized` ガードで対応
- リスナー再構築は `_serialize()`（自身の現状）ではなく **`memo.content`（DB の真実）** を使う

### コミット履歴 (#39)
1. `feat(sync): Phase 9 画像同期 (Firebase Storage + memo doc に images 配列)`
2. `feat(block_editor): 同期受信時の再構築 + UX 改善`
3. `docs(roadmap): サブスク プラン設計と画像 UX アイデア追記`

## 次のアクション（次セッション #40）

### Phase 9 残タスク
- [ ] **画像削除の同期テスト**（実機で双方向動作確認）
- [ ] **メモ削除の同期**（tombstone 方式 / `users/{uid}/deletedMemos/{memoId}`）
- [ ] **Step 4: サブスク** (RevenueCat or in_app_purchase)
  - プラン設計 ROADMAP に記録済み: 無料(同期なし) / お試し1ヶ月(同期可・100枚) / Pro 月500円(7000枚) / Premium 月1500円(7万枚)
  - 容量カウント: Firestore に metadata 記録、アプリで「あと○MB」表示

### 既知の事象
- 両端末で独立 seed → 同名タグ・メモが別 id で重複作成（リリース時は seed しないので非問題）
- リアルタイム購読の memo doc 受信が画像 DL より先に走るケース → block_editor の画像 watch が後追いで再構築（実装済み）

### 残タスク（ROADMAP「備忘」より）
- データ保護画面のダイアログ文言検討
- Firestore セキュリティルールを本番ルールに書き換え（30日以内、テストモード残期間注意）
- データ保護画面の「復元」ワンクッション化

### 実機検証の積み残し
- 13 mini シミュ起動済み（pipe: `/tmp/flutter_pipe_13`）
- iPhone SE 3 シミュ起動済み（pipe: `/tmp/flutter_pipe_se`）
- iPad / 15 Pro Max wireless 接続不安定

## 技術メモ

### 画像同期のフロー（送信側）
1. ユーザーが画像挿入 → `addMemoImage` で MemoImages レコード作成、`memos.updatedAt` 更新、`SyncService.scheduleUpload(memoId)`
2. 1.5秒 debounce → `uploadOneMemo`
   - `_ensureMemoImagesUploaded(memoId)` で remoteUrl == null の画像を Storage に上げて URL を DB に保存
   - 最新 List<MemoImage> 取得
   - `_memoToMap(memo, tagIds, images)` で memo doc 構築
   - `_registerSelfUpload(memoId, updatedAt)` で fingerprint 登録（30秒キャッシュ）
   - Firestore `users/{uid}/memos/{memoId}` に書き込み

### 画像同期のフロー（受信側）
1. `_realtimeMemosSub` の listener が memo doc を受信
2. 自端末 fingerprint と一致なら skip
3. ローカル DB の memos を update（content にマーカー含む最新版）
4. `_syncImagesFromRemote(memoId, remoteImages)` で画像差分同期
   - 未取得画像 → Storage `refFromURL` + `getData(20MB上限)` → `ImageStorage.saveBytes` → `upsertMemoImageFromRemote`
   - ローカル余剰画像 → `removeMemoImageLocalOnly`
5. memo_input_area の `watchMemoById` が発火 → `_applyMemoData` → `_contentController.text` 更新
6. block_editor の `didUpdateWidget` で `initialContent` 変化検知 → `replaceContent` → `_loadBlocksFromContent`
7. `_loadBlocksFromContent` がマーカーから ImageBlock を構築（DB に画像あり前提）
8. 画像 DL 後追いの場合 → block_editor の `watchMemoImages` が発火 → DB から最新 content 取得 → 再構築

### Storage コスト試算（再掲）
- 1ユーザー画像100枚 = 約15MB
- 5GB Free Tier 内なら無料、340ユーザー相当
- 無料ユーザーは同期不可（Phase 4 サブスク導入後）→ 課金者だけ Storage 使うので暴走リスク極小

### Firestore コスト
- 1ユーザー約 $0.10/月 (Blaze)、Spark の無料枠でも数百ユーザーまでは問題なし

### Firebase Console 設定状況
- プロジェクト: `memolette-3a68b`
- 請求先: 「Memolette」(Cloud 請求先アカウント、独立、クレカ既存)
- Storage バケット: `gs://memolette-3a68b.firebasestorage.app` (US-EAST1, Standard)
- 予算アラート: ¥750/月、メール通知有効
- セキュリティルール: テストモード（30日後に本番ルール書換え必要）

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
