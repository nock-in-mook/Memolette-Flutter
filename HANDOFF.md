# 引き継ぎメモ

## 現在の状況
- セッション#8完了: フォルダ周り大幅強化 + 検索 + 入力欄ブラッシュアップ
- MemoEditScreen削除 → メモ閲覧/編集を入力エリアに統合 (本家準拠)

## 今回（セッション#8）完了したこと

### 子タグドロワー
- Unicode三角ハンドル (◀/▶) + Spring物理アニメ
- ドロワー展開でメモグリッド/件数バーが下にスライド (AnimatedBuilder同期)
- フォルダ切替時にドロワー自動収納

### 件数バー
- 子タグフィルター中「親-子」カプセルバッジ表示 (darkenedColor)

### タグ編集UI統一
- NewTagSheet に編集モード/特殊タブ色変更モードを統合
- TagEditDialog 削除、_ColorPickerDialog 削除

### メモカード長押しメニュー
- CupertinoContextMenu → レイアウトバグで断念 → ボトムシート+プレビュー方式
- 本家準拠5項目: トップに移動/固定/コピー/ロック/削除
- ロック中は「削除ロック中」disabled

### 複数選択モード (削除/トップ移動)
- チェックマークUI (Row配置, crossAxisAlignment: stretch)
- ガイドテキスト + 取消/実行ボタン (中央配置, 削除は赤背景白文字)
- スクロール余白120px

### メモカード表示
- Pin/Lock → 右上overlay (orange 0.6)
- 子タグバッジ → 右下overlay (StackFit対応)
- グリッドサイズ別 titleFont/bodyFont/bodyLines/cardPadding
- タイトルのみモード (HStack 1行)
- 本文 ellipsis (fade廃止)

### よく見るタブ
- 2列レイアウト (よく見る/最近見た)
- 専用 FrequentGridOption (2×5/2×3/2×可変/タイトルのみ)
- カード高さ自動計算
- ボトムバー: トップ移動/メモ作成 非表示
- 長押しメニュー: トップに移動/固定 非表示
- タブ長押し: 並び替え+色変更のみ

### グリッドサイズ変更
- 全文モード廃止 → 1×可変 (本文max15行, ListView lazy build)
- よく見る用 2×可変

### 検索
- 全フォルダ横断検索: TextField化した検索バー + タグ別セクション + ハイライト
- 全/半角・大小文字正規化 (normalizeForSearch)
- フォルダ内検索: 虫眼鏡ボタン → 専用モード → 現フォルダのメモのみ検索
- 検索モード閉じるボタン (タブ右端)
- 検索自動クリア (メモ開く/新規作成/メモ作成時)

### スワイプタブ切替
- メモグリッド左右フリック → タブ切替 (両端ループ)
- AnimatedSwitcher でスライドインアニメ (フリック時のみ, タップは即時)

### 入力エリア
- Undo/Redo: スナップショット方式 (本文+タイトル+タグ), max50段
- 本文5万字制限 + SnackBar通知
- 確定=フォーカス外すだけ / メモを閉じる=クリア (本家準拠)
- 閲覧モード: カードタップでreadOnly表示, 本文タップで編集モード
- MemoEditScreen削除, 入力エリアに統合
- 最大化/縮小ボタン + キーボード上フロート縮小ボタン
- 消しゴムボタン: CustomPainter線画 (スリーブ+ゴム先端)
- PingFang JP + 行間1.25
- 新規作成ボタン → 入力欄フォーカス (DB即作成しない)

### その他
- メモソート: isPinned → manualSortOrder → createdAt
- DB: moveMemoToTop, moveMemosToTop, deleteMemos, countMemos, searchMemos
- メモ全件数1万件上限
- タブ重なり: _ZOrderedRow overlap パラメータ (現在0)
- 設定: ダミーデータ各種 (子タグもりもり/Claude検索/長文)

## 次のアクション

### 次セッションの優先候補
1. **確定ボタン → 閲覧モード復帰**: 現在は確定=フォーカス外すだけだが「閲覧モードに戻す」がSwift準拠
2. **文字数カウント表示**: showCharCountフラグでフロートバッジ
3. **入力欄の拡大/縮小のSpringアニメーション**
4. **MDトグル初回説明ダイアログ**: mdToggleFirstSeen
5. **マークダウンプレビュー**: プレビューボタンで切替
6. **メモ詳細画面 (全画面エディタ)**: 最大化ボタンの代替/拡張

### フォルダ周り残タスク
- タグ削除時のロック中メモ自動移動通知
- 特殊タブ色の永続化 (現在はメモリのみ)

### その他
- 8. Firebase同期 / 9. iCloud同期 / 多言語対応
- メモのピン留め/ロック機能の入力エリアからのUI
- 検索結果モード内の検索バーでの絞り込み

## 技術メモ
- **ビルド回避策**: `/tmp/memolette-run` に rsync コピーしてビルド (Google Drive 上だと codesign エラー)
- **シミュレータ並べ**:
  - Swift版（本家）: `021FC865-074D-4979-9556-1F2CEDF0F0F3`
  - Flutter版: `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C`
- **すりガラス標準値**: blur sigma 12, 白 alpha 0.65
- **CupertinoContextMenu**: レイアウトバグ (keyboard+小領域で負制約クラッシュ) のため使用中止。ボトムシート+プレビュー方式に代替
- **検索正規化**: normalizeForSearch() で全角ASCII→半角+小文字化。provider側でDartフィルタ
- **MemoEditScreen**: 削除済み。メモ閲覧/編集は入力エリアに統合

## ファイル構成（追加・変更分）
```
lib/
  screens/
    home_screen.dart           — 大改修。検索・スワイプ・選択モード・よく見るタブ等
    memo_edit_screen.dart      — 削除
    settings_screen.dart       — ダミーデータ各種追加
  widgets/
    memo_card.dart             — 子タグバッジ・Pin/Lock overlay・gridSize別フォント
    memo_input_area.dart       — Undo/Redo・閲覧モード・最大化・消しゴム
    new_tag_sheet.dart         — 編集/特殊タブ色変更モード統合
    tag_edit_dialog.dart       — 削除
  db/
    database.dart              — searchMemos, moveMemoToTop, countMemos 等追加
  providers/
    database_provider.dart     — normalizeForSearch, searchMemosProvider 等追加
```
