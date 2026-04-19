# 引き継ぎメモ

## 現在の状況
- セッション#19 完了
- ブランチ: `feature/todo`
- 最終コミット: `a88545b` すべてタブのフィルタをラボ3ピル状に + 件数をフィルタ連動 + ToDo合算

## 今回（#19）完了したこと

### 実機インストールの安定化
- `objective_c.framework` の adhoc 署名で実機インストール失敗 → `flutter clean` + 再ビルドで解消（過去にも有効）
- 単発の codesign 再署名は Runner.app 全体ハッシュ不整合で起動直後クラッシュするので避ける（cleanリビルドが最短）

### 複数選択モードを ToDo にも統合
- DB: `moveMemosToTop` → `moveItemsToTop({memoIds, todoListIds})` に統合
- ロック中は **削除モード時のみ** 操作不可。トップ移動モードでは選択可能
- `_selectedTodoIds` / `_toggleTodoSelection` / `_resetSelection()` ヘルパー追加
- TodoCard も `flashLevel` 対応（オレンジ枠フラッシュ）
- 件数バッジ・グレーアウト判定も memo + todo 合算

### 複数選択バーをフォルダに被せる絶対配置
- 機能バー枠は `Opacity(0)+IgnorePointer` で高さ維持
- 選択モードバーは `Stack` 内 `Positioned` で重ねる（フォルダが押し下げられない）
- `Transform.translate(0, -65)` で入力欄に大きく被せる
- 文言は「メモを選択してください」に統一

### TodoCard をメモカードに揃える
- 仕切り線（0.5px グレー）追加
- gridSize 連動の可変 font/padding（MemoCardと完全一致のロジック）
- しおりアイコンは title font - 2 で連動

### 新規作成時の並び順を上に
- `nextItemSortOrder()` ヘルパーで memos+todoLists 通しの最大+1 を共通化
- `createMemo`・`createTodoList`・`moveMemoToTop`・`moveItemsToTop` で使用
- 「上に移動」したアイテムの下に新規メモが入る問題を解消

### すべてタブの上部フィルタを刷新
- ラボ3「ピル状」採用（青塗り＋白文字 / 透明＋グレー）
- アイコン廃止、テキストのみで簡潔に
- 件数表示（`_MemoCountText`）に `subFilter` 追加でフィルタ連動
- ToDo件数も合算

## 次のアクション

### 次セッションの本命
- **Phase 10 画像取り込みとサムネ表示**
  - image_picker パッケージ追加
  - DBスキーマに imagePath 等を追加（マイグレーション要）
  - 圧縮+リサイズ（長辺1024px, JPEG 70%, 1枚100-200KB）
  - サムネイル遅延ロード
  - メモカードでの表示

### 残備忘
- リリース前リマインドの3つ（実機確認）— ROADMAP に記載済み
  - 最大化ボタンのタップ判定
  - フラッシュアニメーション複数対応
  - タイトル文字色の紫味の濃さ

## 技術メモ
- **実機ビルド**: rsync → `flutter build ios --release` → `xcrun devicectl device install app`。codesign エラー出たら flutter clean から
- **シミュレータビルド**: `flutter run -d 95C8A8C5-0972-4BB0-B793-5219096697DF < /dev/null > /tmp/memolette-run.log 2>&1 &` で起動。stdin 閉じてるので hot reload 不可、変更時は kill→rsync→再起動
- **ビルド回避策**: `/tmp/memolette-run` に rsync してから build（Google Drive で codesign エラー回避）
- **シミュレータ**: iOS 17.2 の `iPhone 15 Pro Max` (95C8A8C5-0972-4BB0-B793-5219096697DF) 使用中
- **実機**: iPhone 15 Pro Max (`30A153A2-9507-5499-8B3D-341320DA2AB3`)
- **transcript_export.py**: Mac では `python3 "<Mac版のフルパス>" --latest`
- **sortOrder 設計**: memos と todoLists の manualSortOrder を「通し番号」として扱う。`nextItemSortOrder()` 経由で取得すれば両テーブルで衝突しない
