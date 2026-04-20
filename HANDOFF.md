# 引き継ぎメモ

## 現在の状況
- セッション#20 完了
- ブランチ: `main`（feature/block-editor をマージ済）
- 最終コミット: `0436fd0` bugfix + 微調整（grid1flex Infinity.floor 対策、最大20行に拡張、サブフィルタチラつき抑制）

## 今回（#20）完了したこと

### Phase 10: 画像取り込み + サムネ表示（採用版はブロックエディタ）
- image_picker / flutter_image_compress 導入、iOS権限追記
- DBスキーマ v3: MemoImages テーブル（1メモ:複数画像）
- 画像保存ユーティリティ（長辺1024px/JPEG 70%）
- Documents パスキャッシュ、Image.file cacheWidth 最適化
- 50メモ × 1〜3画像のダミー seeder（Canvas 生成）

### ブロックエディタ（実験 → 採用）
- `lib/widgets/block_editor.dart` 新規。本文を TextBlock/ImageBlock 配列で管理
- U+FFFC マーカーで画像IDを content に埋め込み、BlockEditor が parse/serialize
- 画像のインライン挿入: カーソル位置で TextBlock を分割 + 間に ImageBlock
- サムネは 120x120 インライン、メモカードは右端 22〜44px + 件数バッジ
- フルスクリーン画像ビューア（InteractiveViewer + PageView）

### メモカード
- 画像マーカーを画像アイコンでインライン描画 + 前後自動改行
- 右端小サムネ（グリッド連動）+ 2枚以上なら件数バッジ
- タイトルのみ/3x6 は photo アイコンだけ
- UUID マーカーがカード本文に漏れる問題を修正

### MDモード × BlockEditor 統合
- MDツールバーをフォーカス中 TextBlock controller に接続
- MarkdownTextController を TextBlock に採用（Bear 風インライン装飾）
- MDプレビュー: マーカー → `![](memolette:id)` 置換 + imageBuilder で実画像描画
- プレビュー → 編集の1タップ化（BlockEditor 常時マウント + Stack）
- プレビュー入る前のカーソル位置を保存、編集復帰時に復元
- 閲覧中→プレビュー→戻る場合はキーボード出さず閲覧継続
- プレビューのチェックボックスをタップでトグル可能
- MDプレビューのフォント/余白/左寄せを BlockEditor 側に揃える
- プレビュー ↔ 編集 の左右フリック切替（向き問わずトグル）
- MDオン時トーストに操作案内を追記
- MDプレビューで本文ゼロ時は薄いプレースホルダー表示

### Undo/Redo 改善
- atomic な text+selection セットで MDモード時の「カーソル飛び」を解消
- 共通 prefix/suffix で変化位置に追従するカーソル調整ロジック
- 画像マーカーの並びが同じならブロック破棄せず TextBlock.text だけ更新
  （フォーカス維持 = キーボードが閉じない）
- 画像の Undo/Redo は論理削除方式を試したが挙動不安定で一旦ペンド

### フッターツールバー刷新
- フォーカスで「編集/閲覧」レイアウトを分岐
  - 閲覧: 🗑 / MD / ⋯ / 🎨 / 📄 / 閉じる / Max
  - 編集: 🗑 / MD / 🖼 / Undo / Redo / Max
  - コンパクト(最大化): 🗑 / MD / 🖼 / Undo / Redo / Max
- 最大化 + フォーカス中にフッターを Overlay でキーボード直上に浮かせる
- KeyboardDoneBar に accessoryHeight ValueNotifier を追加、完了ボタンが
  カスタムツールバー群の上に出るよう押し上げ
- プレビューボタンを MD スイッチ右隣に移動、角丸を 14→6 に
- 確定ボタン廃止（完了ボタンと重複）、閉じるボタンは非フォーカス時のみ
- Max / 閉じる を SizedBox 内で右寄せ、Max SizedBox 幅 48→34
- 設定に「Undo/Redo アイコンラボ」追加

### バグ修正・UX微調整
- ビルド中 Overlay mutation で落ちる crash を _safeDefer で回避
- 閲覧モードで本文タップ1回目無反応を postFrame 撤去で修正
- 本文右下余白タップで focusLast（先頭ではなく末尾）
- TextBlock タップ時のカーソル位置は TextField native 任せ
- 「すべて」タブの件数表示を SizedBox(60) で幅固定（桁変わってもボタン不動）
- タブタップ時のスクロールを「画面外だけ最小スクロール」に変更
- 爆速モードのタグ履歴を枠外タップで閉じる
- 空メモ先行作成/自動削除が BlockEditor のフォーカス変化でも発火するよう
- UI微調整多数（padding、色、角丸など）

### セッション終了直前のバグ修正
- grid1flex (1×可変) で無限高さのとき Infinity.floor() が発生する問題を修正
- grid1flex の最大行数を 15→20 に拡張、ラベルも「1×可変（20行まで）」
- すべてタブのサブフィルタチップに ValueKey で State 保持、チラつき抑制

### 動作確認
- シミュレータ・実機ともにインストール OK

## 次のアクション

### 大型案件（次セッションの候補）
- **Phase 8 同期**（Firebase / iCloud ↔ SQLite）
- **Phase 11 AI機能**（タグ付け・要約）
- **Phase 12 テーマ・ダークモード**
- **Phase 13 リリース準備**（多言語、アイコン、サブスク）
- **Phase 9 Android対応**

### 保留中
- **画像 Undo/Redo**: 論理削除方式を試したが挙動不安定でペンド
- **リリース前実機確認 3点**: 最大化ボタンのタップ判定・フラッシュアニメ・タイトル紫味

## 技術メモ
- **ビルド回避策**: `/tmp/memolette-run` に rsync してから build（Google Drive で codesign エラー回避）
- **シミュレータ**: iOS 17.2 の iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF)
- **実機**: iPhone 15 Pro Max (30A153A2-9507-5499-8B3D-341320DA2AB3)
- **実機ビルド**: rsync → `flutter build ios --release` → `xcrun devicectl device install app`。codesign エラー出たら flutter clean から
- **flutter run 後に release build すると sim の objective_c.framework が壊れる** → `flutter clean` + 再ビルドで復活
- **transcript_export.py**: Mac では `python3 "<Mac版のフルパス>" --latest`
- **BlockEditor の content マーカー**: `\uFFFC{imageId}\uFFFC`（U+FFFC Object Replacement Character）
- **画像保存先**: `Documents/memo_images/{uuid}.jpg`（相対パスで DB に保存）
