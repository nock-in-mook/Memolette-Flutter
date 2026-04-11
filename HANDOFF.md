# 引き継ぎメモ

## 現在の状況
- セッション#10完了: 最大化レイアウト・台形タブ・フォント統一・シェブロン引き上げ・タグ操作改善
- ブランチ `feature/todo` を作成済み（次セッションでToDo機能実装予定）

## 今回（セッション#10）完了したこと

### 最大化レイアウト改修
- 入力欄最大化: Expandedから95%高さに変更、戻る矢印+確定ボタン表示
- フォルダ引き上げ: シェブロン▲で全画面化、▼で入力欄最大化
- フォルダ全画面からメモタップ→アニメなしで入力欄最大化（擬似全画面表示）
- 戻るボタン→アニメなしでフォルダ全画面に復帰
- 全レイアウト遷移にAnimatedContainer 180msアニメーション
- シェブロンをCustomPaint化（太さ3.5pt、角度120度、角丸先端）

### ルーレット台形タブ
- 閉じ時: 台形タブ（タグ欄40ptに合わせた角丸台形、ベジェ曲線で自然なカーブ）
- 開き時: 従来の四角タブ（hit test制約のため）
- 台形先端の角丸: arcTo→quadraticBezierToで膨らまない自然な丸み
- ルーレット位置: top:0（ヘッダー上端）、bottom:フッター上端
- 円弧の上下端がトレーに完全に刺さるよう+4pxマージン追加
- ルーレット外タップで閉じる、台形タブのタップ開閉

### タグ操作修正
- タグなし選択: 親タグ全外し+子タグも外す動作追加
- 親タグ変更時: 子タグもDBから自動外し
- 子ルーレット: 親タグ変更時にアニメーション付きで「子タグなし」にリセット
- タグ履歴: ルーレット閉じ時に自動記録、履歴ボタンで一覧表示、タップで適用

### フォント・UI統一
- アプリ全体のデフォルトフォントをPingFang JPに設定
- タイトルw700、本文w500に統一（入力欄・メモカード両方）
- メモカードのHiragino Sans→PingFang JPに変更
- 設定アイコン: gear_big 26pt、黒色
- メモ追加/設定ボタン: 青→黒に変更

### ヘッダーUI改善
- タグ欄: 可変幅（Container alignment問題修正）、最大幅40%制限
- タグバッジ: フォント縮小（親11pt、子10pt）、パディング縮小、省略対応
- タイトル×ボタン: xmark_circle_fill、非フォーカス時はTextで「…」省略表示
- タグ×ボタン: 右に16px余白（ルーレットタブとの衝突回避）
- 検索欄: プレースホルダーをStackでド真ん中、入力中は左寄せ

### バグ修正
- 新規メモ変換確定でキーボードが引っ込む問題
- IME変換中の最大化/縮小で下線が残る問題
- コンテキストメニュー(Select All等)がタップで消えない問題
- 閲覧中メモを薄オレンジでハイライト（全場面対応）
- テキスト入力欄の下方向スクロール余白100pt追加
- 消しゴムダイアログテキストを本家に統一

### ラボ追加
- フォントウェイトラボ（w100〜w900比較）
- 設定アイコンラボ（16種類比較）
- 長タイトル+長タグ名ダミーメモ追加機能

## 次のアクション

### 次セッション: ToDo機能（feature/todoブランチ）
1. **ToDoリスト一覧画面**: リストのCRUD、ピン固定、ロック
2. **ToDoリスト詳細画面**: アイテムの階層構造、チェック、ドラッグ並び替え
3. **ToDoアイテム**: 期限、メモ、完了状態
4. **Swift版参照**: TodoListsView.swift, TodoListView.swift, TodoItem.swift, TodoList.swift

### その他残タスク
- URL自動検出リンク（閲覧モードのみ、MD対応後）
- タグ削除時のロック中メモ自動移動通知
- 特殊タブ色の永続化
- Firebase同期 / iCloud同期 / 多言語対応

## 技術メモ
- **ビルド回避策**: `/tmp/memolette-run` に rsync コピーしてビルド (Google Drive 上だと codesign エラー)
- **シミュレータ**: Flutter版 `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C`
- **すりガラス標準値**: blur sigma 12, 白 alpha 0.65
- **AnimatedContainerオーバーフロー**: デバッグモード限定の赤い帯。clipBehavior: Clip.hardEdgeで視覚的に隠すが、RenderFlexエラーは残る。リリースビルドでは出ない
- **台形タブhit test**: 展開時はルーレット本体のPositionedがhit testを食うため、台形タブの下半分が反応しない制約あり。閉じ時は別途GestureDetectorで対応済み

## ファイル構成（追加・変更分）
```
lib/
  main.dart                     — fontFamily: PingFang JP追加
  screens/
    home_screen.dart             — 最大化/引き上げ/アニメーション/シェブロン/検索欄/タグ履歴UI
    settings_screen.dart         — ラボ追加、ダミーデータ追加
    font_weight_lab_screen.dart  — 新規: フォントウェイトラボ
    settings_icon_lab_screen.dart — 新規: 設定アイコンラボ
  widgets/
    memo_card.dart               — PingFang JP統一、w700/w500、ハイライト対応
    memo_input_area.dart         — 台形タブ、タグ操作修正、ヘッダーUI改善、バグ修正多数
    tag_dial_view.dart           — 子ルーレットアニメリセット、円弧+4px
  db/
    database.dart                — getRecentTagHistory追加
```
