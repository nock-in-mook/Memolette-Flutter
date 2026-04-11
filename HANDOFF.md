# 引き継ぎメモ

## 現在の状況
- セッション#11完了: フォルダ最大化ブラッシュアップ + ToDo一覧/詳細画面の原型実装
- ブランチ: `feature/todo`

## 今回（セッション#11）完了したこと

### フォルダ最大化のブラッシュアップ
- 最大化中も検索バーを残す（+ボタンは入力欄最大化遷移へ）
- 最大化時のグリッド: カードサイズはそのままに行数だけ動的に増加
- グリッド選択肢ラベルも最大化時は動的に「cols×N」表示（例: 2×5 → 2×9）
- 機能バー中央シェブロンのタップ判定を 56×44pt に拡大
- 検索結果セクションヘッダー（親タグ+件数）を本家準拠サイズに調整

### ToDo一覧画面 (todo_lists_screen.dart)
- 緑「TODO」台形タブ + 緑色全画面背景（白背景＋上部ツールバー）
- リッチ新規作成ダイアログ（アイコン+タイトル+説明+TextField+作成ボタン）
- 簡易リスト一覧（タップ可能な白カード、しおりアイコン+タイトル）
- 空状態UI（アイコン+「ToDoリストはまだありません」+「リストを作成」白ボタン）
- 遷移アニメ無効化（即時表示）

### ToDo詳細画面 (todo_list_screen.dart)
- ヘッダー: 戻るボタン（角丸背景）+ 中央「ToDo リスト」タイトル
- タイトル行: しおりアイコン+タイトル+「タグなし」ピル
- タイトル下: 「○/○ 完了」進捗テキスト
- 右上: 円グラフ（パーセント表示）+「✓リセット」ボタン
- 仕切り線: タイトル下/項目間（黒0.08）
- 項目行: systemGreen 10% 帯、左右16ptマージン、チェックボックス40pt
- チェックボックス: iOS systemGreen (#34C759)
- テキスト: 18pt w700 PingFang JP
- 項目編集: タップでインライン入力、空のまま確定で削除
- **連続入力**: Enterで次の行を即作成して入力継続。空のままEnterで終了
- +ボタン: アイコン26pt（systemGreen 50%）+ テキスト14pt w600 (60%)

### TextMenuDismisserヘルパー (lib/utils/text_menu_dismisser.dart)
- iOSのコピー/ペーストポップアップが消えない問題を全TextFieldで対策
- 全10箇所のTextFieldに `onTap: TextMenuDismisser.wrap(...)` + `contextMenuBuilder: TextMenuDismisser.builder` を適用
- メモリに「新規TextFieldは必ず付ける」ルールを記録

### 連続入力の安定化（重要）
- 当初: 親State上で _editFocusNode/_editController を使い回し → 行切替時にランダムでフォーカスが入らない
- 解決: 編集中の TextField を独自 StatefulWidget `_EditingItemField` にラップ
- 行ごとに新しい State インスタンス → initState で確実にフォーカス取得
- ValueKey('edit_${item.id}') で行が変わったら必ず作り直される
- メモリに「連続入力UIは独自StatefulWidget化」ルールを記録

### バグ修正
- 仕切り線と最初の項目の間に隙間ができる問題 → MediaQuery.removePadding(removeTop)

## 次のアクション

### ToDo機能の続き（feature/todoブランチ）
1. **階層構造**: 子アイテムの追加・展開/折りたたみ（最大5階層、Swift版 depth 0〜4）
2. **ドラッグ並び替え**: 同じ親内のみ移動可（Swift版は List.onMove）
3. **メモ機能**: 各項目に補足メモ（1行プレビュー＋タップ展開）
4. **タグ機能**: ToDoリスト・項目にタグ付け
5. **削除モード**: スワイプ削除、選択削除モード（親選択で子孫連鎖）
6. **詳細サマリ**: 一覧画面のカードに進捗ドーナツ・ルートアイテムプレビュー追加
7. **長押しメニュー**: 一覧でピン固定/ロック/削除/トップに移動

### キーボード関連の既知の問題
- 連続追加時、キーボードが一瞬閉じて開き直すジッタがまだ残る（Swift版でも完全には解決できなかった）
- `resizeToAvoidBottomInset: false` を試したが副作用あり、現状は付けていない
- ListView下部余白200ptで多少緩和。scrollPadding 100pt で +ボタンも見える位置に

### その他残タスク（メモ機能側）
- URL自動検出リンク（閲覧モードのみ、MD対応後）
- タグ削除時のロック中メモ自動移動通知
- 特殊タブ色の永続化
- Firebase同期 / iCloud同期 / 多言語対応

## 技術メモ
- **ビルド回避策**: `/tmp/memolette-run` に rsync コピーしてビルド (Google Drive 上だと codesign エラー)
- **シミュレータ**: Flutter版 `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C`
- **すりガラス標準値**: blur sigma 12, 白 alpha 0.65
- **AnimatedContainerオーバーフロー**: デバッグモード限定の赤い帯。リリースビルドでは出ない
- **TextField新規追加**: 必ず `TextMenuDismisser` を使うこと（メモリ参照）
- **連続入力UI**: 独自 StatefulWidget で行を分離（メモリ参照）

## ファイル構成（追加・変更分）
```
lib/
  screens/
    home_screen.dart             — 最大化時検索バー残し、動的グリッド、シェブロンタップ判定拡大、検索結果ヘッダー
    todo_lists_screen.dart       — 全面書き換え: 緑TODOタブ、新規作成リッチダイアログ、リスト一覧
    todo_list_screen.dart        — 全面書き換え: タイトル/円グラフ/項目CRUD/連続入力 + _EditingItemField
    quick_sort_screen.dart       — TextMenuDismisser適用
  widgets/
    memo_input_area.dart         — TextMenuDismisser適用（既存ロジックを置換）
    new_tag_sheet.dart           — TextMenuDismisser適用
  utils/
    text_menu_dismisser.dart     — 新規: TextField用ヘルパー
```
