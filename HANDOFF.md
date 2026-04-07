# 引き継ぎメモ

## 現在の状況
- 入力欄UI、ルーレット選択、タグ追加機能、フォルダビューの基礎が完成
- Swift版とFlutter版を並べて比較しながら順次再現中

## 今回完了したこと

### 入力欄まわり
- **タグ表示の親+子重ね合わせデザイン**: Swift版 `HStack(.bottom, spacing: -4)` を Row + `Transform.translate(-4, 0)` で再現
  - 親の右padding 10ptが「めり込み余白」になり、子の幅に関わらず4pt固定で重なる
- **枠線色を選択タグ色に連動**: AnimatedContainer 300ms easeInOutで遷移、`_pendingParentTag` で事前選択状態を保持
- **タグエリア全体タップ判定**: タグマーク上下の余白も含めてタップ可能に（親Containerの上下padding 0化、Rowを40pt使い切り）
- **タグバッジのフォント・中央寄せ**: SF Pro Rounded、`height: 1.0` + strut + leadingDistribution.even

### タグ追加機能
- **NewTagSheet (lib/widgets/new_tag_sheet.dart)**: 下から出るモーダル
  - すりガラス背景（BackdropFilter blur sigma 12, 白0.65）
  - 画面55%の固定高、キーボード表示時はpadding分上に伸びる
  - 72色パレット、重複チェック、確定/キャンセル
- **親タグ追加・子タグ追加ボタン**: ルーレット下のボタンをタップ → シート表示
  - 下部ボタンエリアのSizedBox高さを 20→36 に拡張、負のオフセットを正に修正してタップ判定を有効化
- **追加したタグ自動選択**: 作成完了後にそのタグの位置にルーレットがスナップ
  - `_onTagSelected` でDB直接取得をfallback、`didUpdateWidget` で options.length 変化も検出

### 警告ダイアログ
- **FrostedAlertDialog (lib/widgets/frosted_alert_dialog.dart)**: 中央配置のすりガラスダイアログ
  - showGeneralDialog ベース、Materialで囲んで黄色下線(debug警告)を抑制
  - 子タグ追加で親未選択時に表示

### フォルダビュー（フェーズ1）
- **TrapezoidTabClipper / TrapezoidTabPainter (lib/widgets/trapezoid_tab_shape.dart)**: Swift版 `addArc(tangent1:tangent2:radius:)` 相当を tan/sin/atan2 で再現
- **タブのスタイル**: 選択中は1.08倍スケール（下端基点）、影 `(-3,3) blur 4 black 0.3`、太字
- **タブ⇄本体の連結**: Row + `crossAxisAlignment: end` で下端揃え、SizedBox高さ40
- **フォルダ本体の背景**: 選択中タブの色で塗りつぶし
- **下部ボタンのフロート化**: フォルダ本体内Stackで `Positioned(bottom: 8)`、グリッドに下56pt余白

## 次のアクション

### フォルダビュー フェーズ2以降
- **「よく見る」タブ特殊レイアウト**: Swift版で2列表示・特殊配色
- **タブの並び替えモード**: 長押しでwiggle、ドラッグで順序入れ替え、自動スクロール
- **タブの長押しメニュー**: 編集・削除・色変更・並び替え開始
- **子タグドロワーの引き出しアニメーション**: ドラッグで開閉
- **検索結果モード**: タブ風セクション表示
- **CardWithTabShape**: タブとカード本体を1パスで描く（フォルダ表紙的な完全連結）

### その他
- **NewTagSheet 親タグプレビューを TrapezoidTabShape に差し替え**（暫定でバッジ仮実装中）
- **8. Firebase同期** — Firestore ↔ SQLite
- **9. iCloud同期** — CloudKit ↔ SQLite
- **多言語対応** — ARBファイル、日英中西仏

## 技術的注意
- **Google Driveビルド問題**: `/tmp/memolette-run` にコピーしてビルド（rsync --excludeでbuild/.dart_tool/Pods除外）
- **シミュレータ2台並べて比較**:
  - Swift版（本家）: `021FC865-074D-4979-9556-1F2CEDF0F0F3` (iPhone 17 Pro Max)
  - Flutter版: `29B0ACCA-D4C6-4A55-BD2F-CDB13CF5917C` (iPhone 17 Pro Max (Flutter))
- **タップ判定のFlutter特性**: GestureDetector(opaque)はchild bounds内のみ。親Containerにpaddingがあると、その領域はタップが届かない。Rowの crossAxisAlignment + ContainerやSizedBoxの height 制御でフル領域を確保する
- **Stack内Positionedの負オフセット**: Stack(clipBehavior: Clip.none)でも、子のヒットテストは親bounds内のみ。視覚的にはみ出しても、タップ判定は届かない
- **swift addArc(tangent1:tangent2:radius:)** はFlutterに無いので tan/sin/atan2 で実装

## ファイル構成（追加・変更分）
```
lib/
  screens/
    home_screen.dart               — フォルダタブ / フォルダ本体 / フロートボトムバー
  widgets/
    memo_input_area.dart           — タグ表示・タグ追加ボタン・ルーレット連動
    tag_dial_view.dart             — didUpdateWidgetでoptions.length変化を検出
    new_tag_sheet.dart             — タグ追加シート（すりガラス）
    frosted_alert_dialog.dart      — 中央すりガラスダイアログ
    trapezoid_tab_shape.dart       — 台形タブShape
```
