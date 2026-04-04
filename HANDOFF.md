# 引き継ぎメモ

## 現在の状況
- Flutter版Memolette、移植順1〜4の基盤が完成
- Drift（SQLite）によるローカル保存、Riverpodによる状態管理が稼働中
- シミュレータでの動作確認済み

## 完了済み
1. **Memo CRUD + ローカル保存（Drift）** — 全8テーブル定義、メモのCRUD・ピン留め・ロック・���覧カウント
2. **Tag管理（親子階層、多対多）** — 72色パレット移植、親子タグCRUD、中間テーブル
3. **タブ付きメモ一覧（バッグ表示）** — すべて/タグなし/親タグ別タブ、グリッド表示
4. **メモ入力・編集画面** — 自動保存（debounceなし）、タグ付け機能

## 次のアクション（移植順5〜7）
- **5. 爆速モード** — カルーセルUI、50件ずつ処理、タグ振り分け
- **6. マークダウン対応** — リアルタイムプレビュー、ツールバー
- **7. ToDo機能** — ToDoリスト、階層アイテム、タグ紐づけ

## 技術的注意
- **Google Driveビルド問題**: Google Drive上では `flutter build ios` がcodesignエラーになる。`/tmp/` にコピーしてビルドするか、Xcodeから直接Runすること
- **Driftコード生成**: テーブル変更後は `flutter pub run build_runner build --delete-conflicting-outputs` が必要
- **Swift版バグ対策**: ダイアログ前のキーボード閉じ（#20）は実装済み

## ファイル構成
```
lib/
  main.dart                      — エントリポイント（Riverpod ProviderScope）
  constants/
    design_constants.dart         — 72色パレット、角丸、シャドウ定数
  db/
    tables.dart                   — Driftテーブル定義（8テーブル）
    database.dart                 — AppDatabase（CRUD操作）
    database.g.dart               — 自動生成コード
  providers/
    database_provider.dart        — Riverpodプロバイダー
  screens/
    home_screen.dart              — タブ付きメモ一覧
    memo_edit_screen.dart         — メモ編集（自動保存+タグ付け）
  widgets/
    memo_card.dart                — メモカード（グリッド用）
    tag_edit_dialog.dart          — タグ作成・編集ダイアログ
```

## 環境
- Flutter 3.41.6 (stable)
- CocoaPods 1.16.2
- Xcode 26.3
- 実機: iPhone 15 Pro Max (iOS 26.3.1)
