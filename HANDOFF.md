# 引き継ぎメモ

## 現在の状況
- フォルダビューの細部仕上げ + メモグリッド + 並び替えモードまで完了
- Swift本家と並べて比較しながら順次再現中

## 今回（セッション#6）完了したこと

### フォルダ本体
- 下部の白帯削除（フォルダ色がホームインジケータまで届く）
- 件数バーを drawerBandHeight 37px に揃えて、上下バランスを本家準拠
- 「メモがありません」プレースホルダーを sticky_note_2 に変更、weight 800、Hiragino Sans
- メモ表示数(`GridSizeOption`)選択メニューをすりガラスポップオーバーで実装（本家と同じ6項目）
- 表示数からカード高さを `availableHeight - spacing × (rows + 0.2)` で自動計算
- メモカードは clipBehavior + Flexible でオーバーフロー抑止、日付を削除、(タイトルなし)を本家準拠で薄表示
- ボトムバー4ボタン（ゴミ箱/トップ移動/メモ作成/グリッド数）を本家準拠 Capsule + systemGray6 + 影
- グリッド数表示に square_grid_2x2 アイコン、フォントを Hiragino Sans w700/w800

### タブ
- 末尾に「+」追加タブ → ルーレットの親タグ追加と同じ NewTagSheet を使う
- 親タグ追加ウィンドウのプレビューを TrapezoidTabPainter のフォルダタブ形状に
- 非選択タブも色フルアルファ（本家準拠）
- _ZOrderedRow で「左ほど前面 + 選択中タブ最前面」のZ順制御
- 長押しメニュー（並び替え/編集/削除）をすりガラスポップオーバーで実装
- 「すべて」「タグなし」も長押しで「並び替え/色変更」メニュー
- 削除フローは CupertinoActionSheet → CupertinoAlertDialog で「メモも削除/メモは残す」選択
- 長押し時にタブを最前面に（選択状態を更新してからメニュー表示）
- 並び替えモード:
  - ReorderableListView.builder + AnimationController でwiggle + スムーズなmake-way
  - 「すべて」「タグなし」も含めて全タブ並び替え可能
  - フォルダ本体の上部に半透明グレーオーバーレイ + ⇄アイコン + 「ドラッグで並び替え」+ キャンセル/完了
  - キャンセルで元の順序にロールバック、完了後はスクロール位置復元
  - ドラッグ中、選択中タブが連動してフォルダ本体の色とメモが切り替わる

### 子タグドロワー
- 本家準拠で右上に「◀子タグ」グレー帯（閉じた状態）/ 開いて子タグチップ群
- AnimatedContainerで開閉アニメ、左角丸8、右角0
- 子タグ追加もNewTagSheet経由

### キーボード関連
- ホーム全体を `GestureDetector(translucent, onTap: unfocus)` で包んだ → 入力欄外タップでキーボード閉じる
- キーボード上に丸い青いキーボード収納ボタン（位置: bottom right）
- 長押しメニューのバリアが onLongPress も吸収して、別タブの長押しが下に届かないように
- メニュー閉じ後に明示的に `unfocus()` で入力欄に戻らないように

### 設定画面 + ラボ
- 設定画面追加（右上ギアから遷移）
- アイコンラボ（ゴミ箱/グリッドアイコン候補比較）
- フォントラボ（17種類×4 weightで「このフォルダにメモ作成」ボタン比較）
- ダミーデータ投入（親タグ8個 + 子タグ15個 + 約60メモ）
- 全データ削除

### DB
- `deleteTagWithMemos` 追加: タグと紐づくメモを再帰削除
- `reorderParentTags` 追加: 親タグの sortOrder 一括更新
- `wipeAll` 追加: 全データ削除（dev用）

## 次のアクション

### フォルダビュー フェーズ2以降
- **「よく見る」タブ特殊レイアウト**: Swift版で2列表示・特殊配色
- **検索結果モード**: タブ風セクション表示
- **CardWithTabShape**: タブとカード本体を1パスで描く（フォルダ表紙的な完全連結）
- **特殊タブ色の永続化**: 今は Riverpod StateProvider のみで、アプリ再起動でデフォルトに戻る

### その他
- メモのピン留め/ロック機能の実装
- グリッド (1全文 / タイトルのみ) の本格的な専用レイアウト
- 検索バーの実装
- **8. Firebase同期** — Firestore ↔ SQLite
- **9. iCloud同期** — CloudKit ↔ SQLite
- **多言語対応** — ARBファイル、日英中西仏

## 技術メモ
- **ビルド回避策**: `/tmp/memolette-run` に rsync コピーしてビルド (Google Drive 上だと codesign エラー)
- **シミュレータ並べ**:
  - Swift版（本家）: `021FC865-074D-4979-9556-1F2CEDF0F0F3`
  - Flutter版: `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C`
- **すりガラス標準値**: blur sigma 12, 白 alpha 0.65（new_tag_sheet.dart 準拠で統一）
- **タブの z-order**: 普段の `_ZOrderedRow`（カスタム RenderBox）で paint 順を制御。並び替え時は `ReorderableListView`
- **GridView の上端ズレ**: `MediaQuery.removePadding(removeTop: true, removeBottom: true)` で吸収する自動 padding を消す
- **長押しメニューバリア**: `onTap` だけでなく `onLongPress` も吸収しないと、下のタブの長押しが素通りして二重メニューが開く
- **メニュー閉じ後のフォーカス復帰**: ダイアログ閉時にFlutterが元のフォーカスを戻すので、明示的に `unfocus()` を後で呼ぶ必要がある

## ファイル構成（追加・変更分）
```
lib/
  screens/
    home_screen.dart           — 大改修。タブ管理を _selectedTabKey に統一、並び替えモード追加
    settings_screen.dart       — 設定画面（ConsumerWidget化、ダミーデータ投入/全削除）
    icon_lab_screen.dart       — アイコン候補比較
    font_lab_screen.dart       — フォント候補比較
  widgets/
    memo_card.dart             — clipBehavior, Flexible化、(タイトルなし)対応
    move_to_top_icon.dart      — Swift版CustomPainter移植
    new_tag_sheet.dart         — 親タグはTrapezoidTabPainterプレビュー
  db/
    database.dart              — deleteTagWithMemos, reorderParentTags, wipeAll
  providers/
    database_provider.dart     — allTabColorIndexProvider, untaggedTabColorIndexProvider
```
