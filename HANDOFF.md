# 引き継ぎメモ

## 現在の状況
- セッション#14完了: 爆速整理モード UI完成 + キーボード追従問題を解決
- ブランチ: `feature/todo`

## 今回（セッション#14）完了したこと

### 爆速整理モード
- **カード最大化機能**: 右下青丸ボタンでトグル、LayoutBuilderで利用可能空間いっぱいに
- **編集機能**:
  - タイトル/本文を常駐TextField化（タップ位置にカーソル）
  - `_CardController`でフォーカス・クリア・ピッカー開閉を外部から制御
  - 弧型コントローラー（タイトル/本文/タグボタン）からフォーカス可能
- **タイトル省略表示**: TextField(透明)+IgnorePointer(Text ellipsis)で「…」表示
- **操作パネル改善**:
  - 三角ナビボタンの影を真下固定（方向別パス描画）
  - 影のぼかしを1pt（本家クッキリ感）
  - 削除・ロックボタンは元の位置をキープ（カード変形でも動かない）
- **フロートボタン**: 最大化+キーボード表示時に縮小・消しゴムがフロート
- **消しゴムボタン**: カード内常時表示、編集時オレンジ、確認ダイアログ
- **×ボタン**: 本家準拠の終了確認ダイアログ（すりガラス・オレンジ警告アイコン）
- **デバッグショートカット撤去**: intro→filter→loading→carouselの正規ルート復元

### 本文TextFieldのキーボード追従（両方）
- ToDoリストと同じ構造に：SingleChildScrollView + ConstrainedBox + TextField(maxLines:null, expands:false)
- これで `scrollPadding` が祖先Scrollableで本来通り機能
- 通常メモ入力: `scrollBottom=kb+10` / `cursorBuffer=kb-10`
- 爆速整理カード: `scrollBottom=180` / `cursorBuffer=160`（固定値）
- 文末タップでもカーソルが常にキーボード上にスクロール

### メモ一覧
- **ダブルタップで最大化**: MemoCard.onDoubleTap追加、_openMemoExpanded実装
- 開いた場所（通常/フォルダ最大化）に応じて戻り先を使い分け
- 通常画面への復帰時は `_editingMemoId` 保持 → メモが入力欄に残る

### その他
- 長文テスト用ダミーメモ3件（800/1600/3200文字）をseed
- フロート縮小ボタン位置修正（完了ボタン幅72pt考慮）
- メモ入力エリア上paddingを9pt（左右と揃え）

## 次のアクション

### 爆速整理モードの残タスク
- **50件分割**: メモが50件超えたとき複数セットに分割する動作の実装
- **終了画面**: 完走時のサマリー表示（整理件数・タグ付け・削除など）
- **リセット**: セットやり直し機能

### ロードマップ（残タスク）
- URL自動検出リンク
- タグ削除時のロック中メモ自動移動通知
- 特殊タブ色の永続化
- Firebase同期 / iCloud同期 / 多言語対応

### 既知の問題（前セッションから持ち越し）
- 履歴ボタンの振る舞い: ポップアップが消えない問題
- 連続追加時、キーボードが一瞬閉じて開き直すジッタ

## 技術メモ
- **ビルド回避策**: `/tmp/memolette-run` に rsync してから build（Google Driveで codesign エラー回避）
- **シミュレータ**: Flutter版 `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C`
- **ホットリロード**: `kill -SIGUSR1 <flutter_tools_pid>`
- **TextFieldのキーボード追従**: 外側SingleChildScrollViewが必須。`expands:true`だとscrollPaddingが効かない
- **すりガラス標準値**: blur sigma 12, 白 alpha 0.65
- **キーボード完了ボタン**: main.dartのbuilderでグローバル適用
- **SuppressKeyboardDoneBar**: モーダル内で完了ボタン非表示

## ファイル構成（今回の主な変更）
```
lib/
  main.dart                          — _DQSデバッグ遷移を撤去
  db/database.dart                   — seedDummyLongMemos追加
  screens/
    home_screen.dart                 — ダブルタップ最大化、_minimizeWithCommit改善
    quick_sort_screen.dart           — 最大化、編集、終了ダイアログ、キーボード追従
  widgets/
    memo_card.dart                   — onDoubleTapプロパティ追加
    memo_input_area.dart             — SingleChildScrollView方式に刷新
```
