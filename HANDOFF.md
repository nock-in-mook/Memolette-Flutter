# 引き継ぎメモ

## 現在の状況
- トレーのスライド方式への変更が完了
- チラ見え時の専用表示（タブ短縮、bodyPeek、ポインター非表示）が完了
- 上部ラベル・下部ボタン（親タグ追加・子タグ追加・履歴）の位置調整が完了
- ルーレット位置修正（トレー上端=タイトル下端、円盤上寄せ）が完了

## 今回完了したこと
- **ルーレット位置修正**: トレー上端をタイトル下端(42pt)に一致、円盤を上寄せ
- **スライド方式に変更**: AnimatedContainerでoffsetスライド開閉（trayBodyWidth=300固定）
- **チラ見え専用表示**:
  - タブ幅: 22→19pt
  - bodyPeek: 5pt（ボディ左辺が少し覗く）
  - ルーレットはみ出し: 開き60pt / 閉じ55pt
  - ポインター: 閉じ時非表示
  - 三角マーク: テキストベース(◀/▶, 12pt)
- **上部ラベル配置**: 「親タグ」right:221、「子タグ」right:104（size 10, white 75%）
- **下部ボタン配置**:
  - 「親タグ追加」right:191, top:-17（size 14, white 90%）
  - 「子タグ追加」right:78, top:-17（size 13, white 80%）
  - 「履歴」right:8, top:-8（size 11, white 80%）独立配置
- **シャドウぼかし**: 3（トレー・外周弧両方）

## 次のアクション
- **開いた時の見た目の残り調整**（ユーザーが「次に開いた時の見た目を直していく」と言っていた）
- **ボタン機能実装**: 親タグ追加・子タグ追加・履歴ボタンの実際の機能
- **8. Firebase同期** — Firestore ↔ SQLite
- **9. iCloud同期** — CloudKit ↔ SQLite
- **多言語対応** — ARBファイル、日英中西仏

## 技術的注意
- **Google Driveビルド問題**: `/tmp/memolette_build` にコピーしてビルド
- **文字化け注意**: Google Drive上のDartファイルで日本語が壊れることがある。Writeツールで全体書き直しが必要な場合あり（Unicodeエスケープ `\uXXXX` を使うと安全）
- **Driftコード生成**: テーブル変更後は `flutter pub run build_runner build --delete-conflicting-outputs`
- **シミュレータ**: iPhone 17 Pro Max (021FC865) にFlutter版

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
