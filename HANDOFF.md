# 引き継ぎメモ

## 現在の状況
- Flutter版Memolette、移植順1〜7の骨組みが完成
- 全機能がビルド成功・シミュレータ動作確認済み
- UIはプロトタイプ状態（機能の骨組み優先）

## 完了済み
1. **Memo CRUD + ローカル保存（Drift）** — 全8テーブル、メモCRUD・ピン留め・ロック・閲覧カウント
2. **Tag管理（親子階層、多対多）** — 72色パレット移植、親子タグCRUD
3. **タブ付きメモ一覧（バッグ表示）** — すべて/タグなし/親タグ別タブ、グリッド表示
4. **メモ入力・編集画面** — 自動保存、タグ付け機能
5. **爆速モード** — フィルター選択→カルーセル処理→結果サマリー、50件バッチ
6. **マークダウン対応** — flutter_markdownプレビュー、ツールバー、isMarkdown切替
7. **ToDo機能** — リスト一覧/個別リスト、階層アイテム（最大5階層）、チェーン編集

## 次のアクション
- **UI磨き込み** — Swift版を参照しながらデザインを合わせていく
- **8. Firebase同期** — Firestore ↔ SQLite
- **9. iCloud同期** — CloudKit ↔ SQLite
- **多言語対応** — ARBファイル、日英中西仏

## 技術的注意
- **Google Driveビルド問題**: `/tmp/` にコピーしてビルドするか、Xcodeから直接Run
- **Driftコード生成**: テーブル変更後は `flutter pub run build_runner build --delete-conflicting-outputs`
- **ボトムナビ**: メモ / ToDo / 爆速整理の3タブ構成

## ファイル構成
```
lib/
  main.dart                       — エントリポイント + ボトムナビ
  constants/
    design_constants.dart          — 72色パレット、角丸、シャドウ
  db/
    tables.dart                    — Driftテーブル定義（8テーブル）
    database.dart                  — AppDatabase（全CRUD操作）
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
    tag_edit_dialog.dart           — タグ作成・編集ダイアログ
    markdown_toolbar.dart          — MDツールバー
```
