# 引き継ぎメモ

## 現在の状況
- ルーレット（TagDialView）のUI再現がほぼ完了
- 残り: 閉じ時のトレースライド方式への変更

## 今回完了したこと
- **ラバーバンド修正**: ドラッグ開始時にターゲット確定、親↔子切り替わり防止
- **線の色・太さ**: 外周/内周弧をSwift版と同じグラデーションに
- **仕切り線**: 端セクターの両端に仕切り線追加
- **テキスト**: 文字数制限(親12/子10)、フォントサイズ自動縮小
- **セクター背景色**: fadeによる透明度変化を廃止
- **選択タグにドロップシャドウ**
- **ポインター**: Swift版準拠のグラデーション+ハイライト線+ベタ影、最前面描画
- **子タグなし表記**を「子タグなし」に修正
- **トレーとルーレット分離**: 左60ptはみ出し、トレー幅300pt
- **TrayWithTabShape**: タブ+ボディ一体型CustomPaint（凹カーブ付き）
- **インナーシャドウ**: 上・下・右三辺
- **収納ボタン「›」**: トレー右端、トレー全体タップで開閉
- **タップでセクター選択**: easeInOutCubicアニメーション
- **外周弧の影**: ClipRect外にStack方式で描画
- **トレー・ルーレットのドロップシャドウ**
- **ダミータグ挿入機能**（開発用）

## 次のアクション（最優先）
- **トレーをスライド方式に変更**: Swift版と同じく、常に300ptのトレーをoffsetで右にスライドさせて隠す方式に変更。閉じ時にtrayWidthを28にするのではなく、タブ(22pt)だけ見える位置までスライドアウト。これにより:
  - 閉じ時のタブタップが自然に動作
  - 開閉アニメーションがスムーズ
  - 閉じ時のルーレット専用描画が不要に
- 参考: Swift版 `MemoInputView.swift` 1118-1126行目 `dialArea`

## その後のアクション
- **8. Firebase同期** — Firestore ↔ SQLite
- **9. iCloud同期** — CloudKit ↔ SQLite
- **多言語対応** — ARBファイル、日英中西仏

## 技術的注意
- **Google Driveビルド問題**: `/tmp/` にコピーしてビルドするか、Xcodeから直接Run
- **Driftコード生成**: テーブル変更後は `flutter pub run build_runner build --delete-conflicting-outputs`
- **シミュレータ**: iPhone 17 Pro Max (021FC865) にFlutter版、iPhone 17 Pro Max (Flutter) (29B0ACCA) にSwift版
- **ダミータグ**: 起動時にタグ0件なら8個の親タグを自動挿入

## ファイル構成
```
lib/
  main.dart                       — エントリポイント + ダミータグ挿入
  constants/
    design_constants.dart          — 72色パレット、角丸、シャドウ
  db/
    tables.dart                    — Driftテーブル定義（8テーブル）
    database.dart                  — AppDatabase（全CRUD操作 + seedDummyTags）
    database.g.dart                — 自動生成
  providers/
    database_provider.dart         — Riverpodプロバイダー
  screens/
    home_screen.dart               — タブ付きメモ一覧
    memo_edit_screen.dart          — メモ編集（自動保存+タグ+MD）
    quick_sort_screen.dart         — 爆速モード
    todo_lists_screen.dart         — ToDoリスト一覧
    todo_list_screen.dart          — 個別ToDoリスト
  widgets/
    memo_card.dart                 — メモカード
    memo_input_area.dart           — メモ入力エリア + TrayWithTabShape + DialArcShadow
    tag_edit_dialog.dart           — タグ作成・編集ダイアログ
    tag_dial_view.dart             — タグルーレット（扇形ダイヤル）
    markdown_toolbar.dart          — MDツールバー
```
