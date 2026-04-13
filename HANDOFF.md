# 引き継ぎメモ

## 現在の状況
- セッション#13完了: ToDo機能タグ付け・ルーレット・履歴・一覧リッチ化
- ブランチ: `feature/todo`

## 今回（セッション#13）完了したこと

### ToDo編集画面
- リセット確認ダイアログ（チェック1つ以上で「リセット」表示、確認後に全解除）
- 削除ボタン: グレー背景+赤文字+w600に変更
- タイトル2行レイアウト: 1行目タイトル+円グラフ、2行目完了数+タグバッジ+リセット
- タグバッジ: 本家準拠の親+子タグ重ねめり込み表示（下端揃え）
- タグルーレット: メモ入力画面と同じTagDialView+グレートレー、スライドアニメーション
- トレー上端=仕切り線位置、高さ固定(22+211+40)
- 親タグ追加・子タグ追加ボタン（NewTagSheet連携）
- 履歴ボタン: タグ履歴ポップアップ（重ねタグ表示、スクロールシェブロン）
- ルーレット外タップで収納

### ToDo一覧画面
- リッチカード2列（プレビュー5件+ミニドーナツ+完了数+「他○件」）
- 長押しメニュー（ピン固定/ロック/削除）ボトムシート方式
- カードにピン・ロックアイコン表示
- 「リストを作成」ボタン（リストあり時も表示）

### DB整備
- TodoList↔Tag多対多リレーション（6メソッド: add/remove/get/watch/watchForTag/watchUntagged）
- Provider: allTodoLists/todoListsForTag/untaggedTodoLists/tagsForTodoListStream
- ダミータグ履歴データ生成（seedDummyTagHistory）

### メモ一覧混在表示
- _GridItem sealed classでメモとToDoを統合ソート（isPinned→manualSortOrder→createdAt）
- TodoCardウィジェット（しおり+タイトル+ToDo件数+ピン/ロック）
- ToDoカード長押しメニュー（ピン/ロック/削除、確認ダイアログ付き）

### メモ入力画面改善
- タグバッジ: 親+子タグの重ねめり込み表示を本家準拠に修正（padding/角丸/下端揃え）
- タグ履歴: 重ねタグ表示、スクロールシェブロン、onTagHistoryChangedコールバック
- ルーレット外タップで収納（Column全体のGestureDetector）

### その他
- SuppressKeyboardDoneBar: モーダル内で完了ボタン重複を防止
- ROADMAP: 既知の問題セクション追加（履歴ボタン振る舞い、キーボードジッタ）

## 次のアクション

### 爆速整理モード（次セッション）
- Swift版QuickSortView/QuickSortFilterView/QuickSortResultViewの移植
- カルーセルUIでメモを高速仕分け
- フィルタ条件設定、完了サマリー

### ロードマップ（残タスク）
- URL自動検出リンク（閲覧モードのみ、MD対応後）
- タグ削除時のロック中メモ自動移動通知
- 特殊タブ色の永続化
- Firebase同期 / iCloud同期 / 多言語対応

### 既知の問題
- 履歴ボタンの振る舞い: ポップアップが消えない問題
- 連続追加時、キーボードが一瞬閉じて開き直すジッタ

## 技術メモ
- **ビルド回避策**: `/tmp/memolette-run` に rsync コピーしてビルド (Google Drive 上だと codesign エラー)
- **シミュレータ**: Flutter版 `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C`、本家 `021FC865-074D-4979-9556-1F2CEDF0F0F3`
- **すりガラス標準値**: blur sigma 12, 白 alpha 0.65
- **TextField新規追加**: 必ず `TextMenuDismisser` を使うこと
- **連続入力UI**: 独自 StatefulWidget で行を分離
- **キーボード完了ボタン**: main.dart の builder でグローバル適用済み
- **SuppressKeyboardDoneBar**: モーダルシート内で完了ボタン非表示にする InheritedWidget

## ファイル構成（追加・変更分）
```
lib/
  main.dart                        — seedDummyTagHistory追加
  db/
    database.dart                  — TodoList↔Tag リレーション、タグ履歴ダミーデータ
  providers/
    database_provider.dart         — ToDoリスト用Provider追加
  screens/
    home_screen.dart               — メモ一覧混在表示、ToDoカード長押しメニュー、ルーレット外タップ収納
    todo_list_screen.dart          — タグルーレット、履歴、タイトルレイアウト改善
    todo_lists_screen.dart         — リッチカード2列、長押しメニュー
  widgets/
    todo_card.dart                 — メモ一覧用ToDoカード（新規）
    memo_input_area.dart           — タグ表示改善、onTagHistoryChanged
    new_tag_sheet.dart             — SuppressKeyboardDoneBar適用
  utils/
    keyboard_done_bar.dart         — SuppressKeyboardDoneBar追加
```
