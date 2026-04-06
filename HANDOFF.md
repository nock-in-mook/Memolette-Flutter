# 引き継ぎメモ

## 現在の状況
- 入力欄のUIをSwift版（本家）と視覚的に一致させる調整を実施
- 本家Swift版を021FC865シミュレータ、Flutter版を29B0ACCA(Flutter)シミュレータで並べて比較できる環境構築済み

## 今回完了したこと
- **タイトルプレースホルダー色**: `grey × opacity 0.4`（Swift版準拠）に薄く
- **背景色**: `0xFFFAFAFA` → `#FFFFFF`（純白）に修正
- **タイトル横タグ欄**: タグアイコン（`sell_outlined`）+ 縦区切り線を常時表示
- **色の統一**: SwiftUI `Color.gray (142,142,147)` ベースに統一
  - 枠線: `rgba(142,142,147, 0.4)`、width 1.5
  - 区切り線: `rgba(142,142,147, 0.35)`
  - タグアイコン: `rgba(142,142,147, 0.45)`
- **ドロップシャドウ削除**: Swift版準拠（枠線のみ）
- **水平仕切り線追加**:
  - タイトル下 / フッター上の2本
  - 外枠に密着（左右マージン0）
- **フッター高さ**: 28 → 34に拡大
- **ヘッダーボタン色**: `blueAccent` → iOS標準青 `#007AFF`
- **設定アイコンサイズ**: 26 → 22

## 次のアクション
- **開いた時（タグ選択時）の見た目調整**
- **ボタン機能実装**: 親タグ追加・子タグ追加・履歴ボタンの実際の機能
- **8. Firebase同期** — Firestore ↔ SQLite
- **9. iCloud同期** — CloudKit ↔ SQLite
- **多言語対応** — ARBファイル、日英中西仏

## 技術的注意
- **Google Driveビルド問題**: `/tmp/memolette_build` にコピーしてビルド
- **シミュレータ2台並べて比較**:
  - Swift版（本家）: `021FC865-074D-4979-9556-1F2CEDF0F0F3` (iPhone 17 Pro Max)
  - Flutter版: `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C` (iPhone 17 Pro Max (Flutter))
- **Swift版ビルド**: `xcodebuild -project SokuMemoKun.xcodeproj -scheme SokuMemoKun -sdk iphonesimulator -destination "id=021FC865..." -derivedDataPath /tmp/swift_build build`
- **Swift版バンドルID**: `com.sokumemokun.app`
- **Flutter版バンドルID**: `com.memolette.memolette`
- **色の知見**: SwiftUIとFlutterでは同じ不透明度でも見た目が変わる。本家との比較では数値を視覚で合わせる必要あり

## ファイル構成
```
lib/
  main.dart                       — エントリポイント + ダミータグ挿入
  constants/
    design_constants.dart          — 72色パレット、角丸、シャドウ
  db/
    tables.dart                    — Driftテーブル定義（8テーブル）
    database.dart                  — AppDatabase
    database.g.dart                — 自動生成
  providers/
    database_provider.dart         — Riverpodプロバイダー
  screens/
    home_screen.dart               — タブ付きメモ一覧
    memo_edit_screen.dart          — メモ編集
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
