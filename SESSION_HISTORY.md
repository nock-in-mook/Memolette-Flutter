# セッション履歴

---
## Memolette-Flutter_001_Drift実装_Tag管理_基盤構築 (2026-04-05)

- Drift（SQLite）による全8テーブル定義 + Memo CRUD実装
- 72色タグカラーパレット移植、親子階層タグ管理
- タブ付きメモ一覧（すべて/タグなし/親タグ別バッグ表示）
- メモ編集画面（自動保存 + タグ付け機能）
- Riverpodプロバイダー構築
- シミュレータ動作確認済み


### 追加作業（同セッション内）
- 爆速モード（QuickSort）実装: フィルター→カルーセル→結果サマリー
- マークダウン対応: プレビュー、ツールバー、isMarkdown切替
- ToDo機能: リスト一覧、階層アイテム、チェーン編集
- ボトムナビ追加（メモ / ToDo / 爆速整理）

---
## Memolette_002_ルーレットUI再現 (2026-04-05)

- ラバーバンド修正（ドラッグターゲット確定で親↔子切り替わり防止）
- 線の色・太さをSwift版と完全一致（グラデーション弧、仕切り線）
- テキスト: 文字数制限(親12/子10)、フォントサイズ自動縮小
- セクター背景色のfade廃止、選択タグにドロップシャドウ
- ポインター: グラデーション+ハイライト線、最前面描画
- トレーとルーレット分離構造、左60ptはみ出し、トレー幅300pt
- TrayWithTabShape移植（タブ+ボディ一体型、凹カーブ付き）
- インナーシャドウ（上・下・右三辺）
- 収納ボタン「›」+ トレー全体タップで開閉
- タップでセクター選択（easeInOutCubicアニメーション）
- 外周弧の影をClipRect外にStack方式で描画
- ダミータグ挿入機能（開発用）
- 次回: トレーをスライド方式に変更（Swift版のoffsetアプローチ）
---
## Memolette_003_トレースライド実装 (2026-04-05)

- ルーレット位置修正（トレー上端=タイトル下端）
- トレーをスライド方式に変更（AnimatedContainer offset）
- チラ見え時専用表示（タブ短縮、bodyPeek、ポインター非表示）
- 上部ラベル・下部ボタン位置をSwift版準拠に調整
- テキスト透明度調整

---
## #4 入力欄UIをSwift版と視覚的に一致させる (2026-04-07)

- タイトルプレースホルダー色を `grey × 0.4` に薄く
- 背景色を純白 `#FFFFFF` に修正
- タイトル横にタグアイコン + 縦区切り線を常時表示
- 色をSwiftUI `Color.gray (142,142,147)` ベースに統一
- 入力欄のドロップシャドウ削除（Swift版準拠）
- タイトル下 / フッター上の水平線を追加（外枠密着）
- フッター高さ 28→34、枠線太さ 1→1.5
- ヘッダーの＋ / 設定ボタンをiOS標準青 `#007AFF` に統一
- 本家Swift版とFlutter版を2台のシミュレータで並べて比較できる環境構築

---
## #5 Memolette-Flutter_005_タグ追加機能_フォルダビュー基礎 (2026-04-08)

- タグ表示の親+子重ね合わせデザイン（Row + Transform.translate -4pt）
- 枠線色を選択タグ色に連動（AnimatedContainer 300ms）
- _pendingParentTag/Child で事前選択状態保持
- タグエリア全体タップ判定（行40pt使い切り、Row crossAxisEnd）
- NewTagSheet（すりガラス背景、72色パレット、画面55%固定高）
- 親/子タグ追加ボタン実装、子タグなし警告は中央フロストガラスダイアログ
- 追加タグの自動選択 + ルーレット位置スナップ
- FrostedAlertDialog 共通化
- TrapezoidTabClipper/Painter（Swift addArc(tangent1:tangent2:radius:) を tan/sin/atan2 で再現）
- フォルダタブ実装: 1.08倍スケール、影、太字、選択中は不透明
- フォルダ本体を選択タブ色で塗りつぶし
- 下部ボタンをフォルダ内 Positioned フロートに移行

---
## Memolette-Flutter_006 (2026-04-09)
フォルダUI仕上げ: ボトムバー本家準拠、メモ表示数メニュー、カード高さ自動計算、メモカード書き換え、+タブ、Z順制御、長押しメニュー（並び替え/編集/削除/色変更）、削除フロー、並び替えモード（wiggle+make-way+全タブ対応）、子タグドロワー右上配置、キーボード収納、設定画面+アイコン/フォントラボ+ダミーデータ投入、DB拡張

---
## #8 (2026-04-09〜04-10)
### Memolette_008_検索・スワイプ・入力欄ブラッシュアップ

**フォルダ周り大幅強化:**
- 子タグドロワー: Spring物理アニメ + グリッド連動スライド + フォルダ切替時自動収納
- NewTagSheet統合 (編集/色変更を全UI共通化), TagEditDialog/ColorPickerDialog削除
- メモ長押し: CupertinoContextMenu断念 → ボトムシート+プレビュー方式 (本家準拠5項目)
- 複数選択モード (削除/トップ移動): チェックマーク+ガイドテキスト+取消/実行ボタン
- メモカード: 右上Pin/Lock overlay, 右下子タグバッジ, gridSize別フォント/行数
- よく見るタブ: 2列レイアウト, FrequentGridOption, カード高さ自動計算
- 全文モード廃止 → 1×可変 (max15行)
- タイトルのみモード (HStack 1行)

**検索:**
- 全フォルダ横断検索: タグ別セクション + 黄色ハイライト + 全/半角正規化
- フォルダ内検索: 虫眼鏡ボタン → 専用モード
- 閉じるボタン + 自動クリア

**スワイプ:**
- メモグリッド左右フリック → タブ切替 (両端ループ) + スライドインアニメ

**入力エリア:**
- Undo/Redo (スナップショット方式max50), 5万字制限+通知
- 閲覧モード (readOnly → タップで編集), MemoEditScreen削除・統合
- 確定=キーボード閉じ / メモを閉じる=クリア
- 最大化/縮小ボタン + キーボード上フロート縮小
- 消しゴムボタン (CustomPainter線画)
- PingFang JP + 行間1.25
- 新規作成 → 入力欄フォーカス

**その他:** メモソート改善, DB拡張, 1万件上限, タブoverlap, ダミーデータ各種

---
## #10 (2026-04-11)
最大化レイアウト改修・台形タブ・フォント統一・シェブロン引き上げ・タグ操作修正

- 入力欄最大化: 95%高さ、戻る矢印+確定ボタン、AnimatedContainer 180msアニメーション
- フォルダ引き上げ: シェブロン▲▼で全画面化/入力欄最大化、フォルダ全画面からメモ全画面表示
- ルーレット台形タブ: 閉じ時台形（ベジェ曲線角丸）、開き時従来型、ルーレット位置調整
- タグ操作: タグなし選択対応、親タグ変更時子タグリセット（アニメ付き）、タグ履歴機能
- フォント統一: PingFang JP全体適用、タイトルw700/本文w500
- ヘッダーUI: タグ欄可変幅、タイトル省略表示、検索欄中央寄せ
- バグ修正: IME下線残り、コンテキストメニュー、新規メモ変換確定キーボード引っ込み
- メモハイライト（薄オレンジ）、スクロール余白、シェブロンCustomPaint化
- ラボ追加: フォントウェイト、設定アイコン
- ブランチ feature/todo 作成（次セッションでToDo機能実装予定）

---
## Memolette_011_ToDo詳細画面実装 (2026-04-12)
- ToDo一覧画面/詳細画面の原型実装
- TextMenuDismisserヘルパー追加（全TextField対策）
- 連続入力の安定化（独自StatefulWidget化）

---
## Memolette_012_ToDo階層・ドラッグ・メモ・削除モード (2026-04-12〜13)
- 階層構造: 最大5階層、展開/折りたたみ、階層色帯（緑→紫→オレンジ→青→茶）、L字罫線、祖先縦線
- ドラッグ並び替え: ReorderableListView、同じ親内のみ、子アイテムスキップの正しい挿入位置算出
- スワイプ削除: ボタン式、子孫再帰削除、ValueNotifierで一斉クローズ
- メモ機能: 3段階表示（折りたたみ→展開→編集）、メモアイコングロー、削除確認ダイアログ
- 選択削除モード: 親選択で子連動、+ボタン非表示、確認ダイアログ、全件削除2段階確認
- 全展開/全収納ボタン: メモあり時ダイアログ選択、初期全展開
- キーボード完了ボタン: main.dart builderでグローバル適用、旧ボタン統合削除
- フッター: ヒントテキスト＋削除ボタン
- +ボタンレイアウト改善、シェブロン向き調整、メモフォントw500

---
## #13 Memolette_013_ToDoタグ付け・ルーレット・履歴実装 (2026-04-13)

### 完了項目
- ToDo編集画面: リセット確認ダイアログ、削除ボタン改善、タイトル2行レイアウト
- ToDo一覧画面: リッチカード2列、長押しメニュー（ピン/ロック/削除）
- DB整備: TodoList↔Tag多対多リレーション（6メソッド）
- メモ一覧混在表示: _GridItem sealed classでメモとToDoを統合ソート
- タグルーレット: ToDo画面にトレー付きルーレット、アニメーション、タグ追加ボタン
- タグ履歴: 両画面で重ねタグ表示、スクロールシェブロン、ダミーデータ生成
- タグバッジ: 本家準拠の重ねめり込み表示、下端揃え
- 完了ボタン重複修正: SuppressKeyboardDoneBar
- ルーレット外タップで収納: メモ・ToDo両画面
- メモ一覧ToDoカード長押しメニュー: ピン/ロック/削除

### コミット
- 1899798 ToDo一覧リッチ化 + メモ一覧へのToDo混在表示 + タグDB整備
- 29fe4cd ToDo編集画面にタグルーレット実装 + ROADMAP既知問題追記
- 7bf50d9 タグ表示・ルーレットUI改善 + 完了ボタン重複修正
- b0e1654 タグ履歴UI実装 + タイトルレイアウト改善 + ルーレット外タップで収納
- 1420315 メモ一覧のToDoカード長押しメニュー実装

### 次回予定
- 爆速整理モード（QuickSortView）の移植

---
## #14 (2026-04-15)

### 爆速整理モード UI完成
- カード最大化機能（LayoutBuilder採用）、編集機能（_CardController）
- タイトル省略表示、弧型コントローラー、操作パネル改善、フロートボタン
- ×ボタンの本家準拠終了確認ダイアログ、デバッグショートカット撤去

### 本文TextFieldのキーボード追従問題を解決
- SingleChildScrollView + ConstrainedBox + TextField(maxLines:null, expands:false)
- ToDoと同じ構造にすることで scrollPadding が祖先Scrollableで本来通り機能
- 文末タップでもカーソルが自動でキーボード上にスクロール

### メモ一覧
- ダブルタップで即最大化
- 戻り時に「開いた場所」に戻る（通常/フォルダ最大化を使い分け）
- 通常復帰時は選択メモを入力欄に保持

### その他
- 長文テストダミー3件、フロートボタン位置修正、padding調整

---
## Memolette-Flutter_015_爆速整理終了画面_ルーレット_入力欄修正 (2026-04-16)

### 爆速整理モード — 終了画面
- 本家Swift版準拠のリッチUI（オレンジseal、戦績カード、ボタン）
- 削除ディファコミット化（整理画面に戻ると取消可）
- 削除メモ確認ダイアログ（個別復元）、削除確認ダイアログ追加
- ゴミ箱アイコン統一、完了→intro画面に戻す

### 爆速整理モード — 50件分割
- セット確認画面、ロードはセット開始時に挿入、件数セット単位

### 爆速整理モード — タグルーレット
- Todo版完全移植（トレー+ダイヤル+ラベル+シェブロン+ボタン）
- 右スライドイン/アウト、カード縮小+上詰め
- 親/子タグ追加→NewTagSheet、履歴ボタン→タグ履歴overlay
- タグフッタータップでルーレット開閉（旧リスト式廃止）

### メモ入力欄
- フォーカス時プレースホルダー非表示、タイトル位置合わせ
- 縮小時キーボード追従無効化（上跳ね防止）

### DB修正
- memo_tagsカスケード削除、孤児レコード除外

### その他
- カラーラボ完全削除、弧ボタンタップ領域拡大、カード位置調整

---
## Memolette_016_MD編集モード実装_UI大幅改善 (2026-04-17)

- マークダウン編集モード実装（Bear風インラインプレビュー + ツールバー + プレビュー切替）
- カスタムキーボードの空欄+日本語確定でテキスト消失バグ修正
- 編集コンパクトモード（入力中は機能バー・タブ・メモ一覧すべて非表示）
- メモカードUI改善（仕切り線・フォント濃度・行数動的計算・「無題」）
- タブ長押しメニュー位置改善（上に表示）+ フォーカス復元バグ修正
- ルーレット台形タブ非表示化、タグアイコン強化
- キーボード開閉時のフッターガタつき修正（viewInsetsゼロ化）
- メモロード高速化（loadMemoDirectly）
- TODOリスト新規作成ダイアログをキーボード上に固定配置
- 最大化時の確定ボタン削除、完了ボタンでの最大化維持
- 2台目Mac: Flutter環境構築

---
## #17 (2026-04-18)

### メモ背景色機能（新規）
- DB: Memo に bgColorIndex カラム追加（schemaVersion 2 + MigrationStrategy）
- 31色のカタカナ名パステルパレット（lib/constants/memo_bg_colors.dart）
- 色選択ダイアログ: 8×4グリッド + サンプルパネル + 色名表示
- 入力欄 + メモカード両方で色反映
- 色付きメモはフォーカス外れ削除から除外（キーボード完了で色消失防止）

### 「すべて」タブ改造（統合）
- `_AllTabSubFilter` enum（all/frequent/recent/untagged）
- 仕切り線区切りのフィルタUI（件数+フィルタ：すべて|よく見る|最近見た|タグなし）
- トップタブから「よく見る」「タグなし」を削除、サブフィルタに統合

### フッターUI大改造
- 最大化ボタンをフッター右端に移植（zoom_out_map/zoom_in_map トグル）
- 消しゴムを入力欄内部から撤去、編集中専用バーに
- MDトグル縦並び、Switch.adaptive でAndroid対応
- コピーはアイコンのみ、確定/閉じるは幅固定(72px)

### 機能バー / 編集中バー分離
- 非編集: 爆速 | ToDo [Spacer] 上シェブロン [Spacer]
- 編集中: 消しゴムのみ
- 最大化ボタンはフッター内に統合

### 空メモ削除ルール強化
- dispose / purgeEmptyMemos / _onChanged で全経路カバー
- 起動時クリーンアップ（home_screen initState）
- 色付きはフォーカス外れだけスキップ

### MDモード保持
- トグル操作以外で解除しない
- clearInput に keepMarkdown 引数、全経路統一

### ダイアログ / 画面遷移
- 本文クリア・削除ダイアログ中のフォルダビュー復活を抑制
- 閲覧中のゴミ箱タップはフォルダ維持
- 起動時・他画面復帰時のフォーカス自動クリア
- タグ削除: メモ0件なら確認ダイアログだけ
- 「タグなしに移動」→「タグなしに変更」

### フォルダ関連
- タップでタブバー自動中央スクロール
- 上下フリックで最大化/縮小トグル
- フォルダ最大化時シェブロンを中央+余白拡大
- 子タグドロワー: 編集中は非表示

### 検索バー
- フォーカス中（クエリ空）は機能バー・親タブ・フォルダ本体すべて非表示
- grid size メニュー前に unfocus（フォーカス復帰バグ対策）

### メモカード
- 選択ハイライトを背景塗り→半透明黒枠(1.5px)に変更
- KeyedSubtree でハイライト変化を瞬時に

### その他
- 最大化アイコン選定ラボ画面追加
- 設定画面の多機能ボタン準備
- プレビューボタンを入力欄下端中央に枠付きで配置
- 実機接続時の codesign 問題対策で /tmp/memolette-run フロー確立
- 新マシン（2台目）環境同期

### 技術メモ
- 空メモ起動時クリーンアップ: `purgeEmptyMemos()` を home_screen initState で
- 色付きメモはフォーカス外れ削除対象外（キーボード完了で色消失防止）
- `_isDialogOverEditing` フラグでダイアログ中のフォルダビュー復活抑制
- Switch.adaptive で iOS/Android プラットフォーム対応
- Phase 9 (Android対応) で Cupertino UI を adaptive 化する提案を memory に登録

---
## #18 (2026-04-19): 細部の根治と UX 洗練ラッシュ

### 大きな根治系
- **ダイアログ閉時のキーボード復活バグを根治**: `lib/utils/safe_dialog.dart` に `focusSafe` 共通ラッパー新設し、全 30 箇所のダイアログを統一ラップ（Navigator のフォーカス自動復元を unfocus で抑制）
- **トースト通知整備**: SnackBar 全廃、自前 `showToast`（オレンジ色のすりガラス中央バー）と `showFrostedAlert` の 2 系統に統一
- **タグ名重複阻止**: DB 層 `createTag` で同じ親スコープの同名検知して既存返却。ダイアログでも赤枠＋警告を目立たせる

### UI 全般の整備
- メモ入力欄の枠 / 仕切り線を 0.5px / 黒寄り (RGBO 40,40,40,0.55) に統一
- メモ枠線をタグカラーで染めるのを廃止（爆速モードのカードも同様）
- ルーレット位置を上端＝タイトル下の仕切り線に揃える
- ルーレットタブを「Tag」テキスト表示、内部ラベル「親」「子」に短縮
- ルーレット親/子のタップ判定境界を視覚と一致するよう修正
- ルーレットでタグ確定時に該当タグバッジをオレンジ縁取りでフラッシュ
- 「すべて」タブ上部フィルタ: 比較ラボ（7案）を作って選定 → 「アイコン+チップ塗り」のハイブリッドに刷新
- メモ一覧タイトル色を黒 → 紫寄り (`Color(0xFF2D1F50)`)
- 入力欄右下の最大化ボタンのタップ判定を 48x40 に拡張

### 編集モード周り
- 編集中の枠外タップで編集を抜ける
- 選択・並び替えモード中は入力欄・新規作成・検索バー・設定アイコンを IgnorePointer で全部無効化
- メモ削除時に入力欄もクリア（長押し削除 / 選択削除の両方）
- メモ長押し削除に確認ダイアログ追加

### 選択モード UX 大幅刷新
- 「トップに移動」実行ボタンを青縁取り（赤削除と差別化）
- メモゼロ件のタグでは選択モード入りボタン（ゴミ箱・トップ移動）をグレーアウト
- 選択モード中の機能バーに大きな枠付きバッジを表示（案内文 + リアルタイム件数）。Transform で入力欄に少しかぶせて存在感
- トップに移動実行後: フォルダ先頭にスクロール + 対象メモを **オレンジ枠でジワッと2回フラッシュ** + トースト
  - 単発長押しの「トップ」「ロック」「固定」、複数選択削除のトップ移動 全てでフラッシュ
  - 複数選択時は対象全部光る (`Set<String>` 対応)
  - フラッシュは `foregroundDecoration` で重ね描画してレイアウトを動かさない（width/alpha を 8 ステップ補間で滑らかに）

### 「このフォルダにメモ作成」改善
- 押下時に先にキーボード表示してフォルダを消してからメモ作成（カードチラ見え抑制）
- `_selfCreatedMemoId` 経路でも DB からタグ再取得して UI に反映

### 親タブ周り
- 末尾の「+」追加タブで作った親タグのフォルダを自動で開く
- 親タグ削除時、選択中なら左隣（なければ右隣）に切替。タブバースクロール位置を保存→post frame 復元で先頭に戻るのを防止

### 設定画面
- 「すべてフィルタタブラボ」追加（現状/Segmented/アンダーライン/ピル/アイコン+テキスト/チップ/ドット の 7 案比較）

### 技術メモ
- `focusSafe(context, () => show...)` で showGeneralDialog / showDialog / showCupertinoDialog / showModalBottomSheet / showCupertinoModalPopup を全部統一
- `_flashingMemoIds: Set<String>` + `_flashLevel: double` で複数メモ同時 2 回フェードイン/アウト
- メモカードの flash は `foregroundDecoration` で中身に重ねるため、border 分でレイアウトが縮まない
- iOS 17.2 シミュレータ (`iPhone 15 Pro Max`) 中心で動かす。iOS 26.3 だと objective_c プラグイン読み込み失敗が頻発
- flutter run は `< /dev/null` で起動して、変更時は kill → rsync → 再起動の流れに統一

---
## #19 (2026-04-19)

### 実機インストール安定化
- objective_c.framework の adhoc 署名問題は単発codesign再署名ではダメ → `flutter clean` で解消

### 複数選択をToDoに統合
- `moveMemosToTop` → `moveItemsToTop` (memo+todo)
- ロックは **削除モード時のみ** ブロック
- `_selectedTodoIds`/`_toggleTodoSelection`/`_resetSelection()` 追加
- TodoCard にもフラッシュ対応
- 件数バッジ・グレーアウト判定も memo+todo 合算

### 選択モードバーをフォルダに被せる絶対配置
- 機能バー枠は Opacity(0)+IgnorePointer で高さ維持、選択モードバーは Positioned で重ねる
- Transform.translate(0, -65) で入力欄に大きく被せる
- 文言は「メモを選択してください」に統一

### TodoCard をメモ準拠に
- 仕切り線追加、gridSize連動の可変 font/padding/しおりサイズ
- メモと並べたとき完全に揃う

### 新規作成 sortOrder 統一
- `nextItemSortOrder()` ヘルパーで memos+todoLists 通しの max+1
- createMemo・createTodoList・moveMemoToTop・moveItemsToTop で使用
- 「上に移動」したアイテムの下に新規メモが入る問題を解消

### すべてタブのフィルタ刷新
- ラボ3ピル状を採用（青塗り＋白文字 / 透明＋グレー、テキストのみ）
- `_MemoCountText` に subFilter 追加でフィルタ連動の件数表示
- 件数は memo+todo 合算

### 次セッション
- Phase 10 画像取り込み（image_picker、DBマイグレーション、圧縮、サムネ表示）

---
## Memolette_020_ブロックエディタ統合 (2026-04-20)

- Phase 10 画像取り込み + サムネ表示を実装、ブロックエディタで仕上げて main にマージ
- 本文を TextBlock/ImageBlock 配列で管理、カーソル位置に画像をインライン挿入
- メモカードに右端コーナーサムネ + 件数バッジ、画像マーカーをアイコンでインライン描画
- MD × BlockEditor 統合: MarkdownTextController で Bear 風装飾、MDツールバーを focusedController 経由に、プレビューでチェックボックストグル・画像インライン描画
- プレビュー ↔ 編集の左右フリック切替、カーソル位置保存/復元、1タップ遷移
- Undo/Redo のカーソル追従ロジック刷新（共通 prefix/suffix で変化位置に寄せる）
- フッターツールバー刷新: フォーカス連動で閲覧/編集/コンパクトの3レイアウト、最大化時はキーボード直上に浮かせる
- KeyboardDoneBar の完了ボタンがカスタムツールバー群の上に出るよう accessoryHeight を通知
- 既知の問題: 履歴ポップアップ枠外タップ閉じ / すべてタブ件数桁のずれ / 閲覧1回目タップ無反応 などまとめて修正
- Documents パスキャッシュ + cacheWidth など画像表示の最適化
- ダミー画像付きメモ50件の seeder を追加 (Canvas で PNG 生成)

---
## #21 (2026-04-20) iPad対応 Phase 8 Step A

- Responsive ヘルパ新規（isTablet/isWide/contentMaxWidth）
- GridSizeOption に iPadColumns 追加。iPad は列数を個別指定（6×6 / 4×5 / 4×3 / 2×可変 / タイトルのみ2列）
- titleOnly は iPad で 2列 GridView 化、grid1flex は iPhone/iPad 共に 1列（長文読みモード）
- グリッドメニューは iPad時に grid1x2 除外、ラベルは iPadColumns 基準に上書き
- 入力欄の縦幅を iPad 時は画面の約半分（constraints.maxHeight × 0.5）
- サブフィルタ（すべて/よく見る/最近/タグなし）を中央寄せ + max 600px
- 入力欄下ツールバーを右寄せに統一（UNDO/REDO 含む。左利き対応の土台）
- AppDelegate.application(supportedInterfaceOrientationsFor:) を `.all` で明示実装（実機用）
- iPhone は portrait-only に固定（Info.plist から landscape 除外）
- viewPadding.top - 4 が負値になるケースで Padding アサーション失敗→クラッシュする問題を non-negative clamp で修正
- iPad 実機（のっくりのiPad / iOS 26.2.1）で動作確認、横画面も動く（Step B の下準備）
- Step B (スプリットビュー) は既存 Column が巨大なためリファクタ必要、次セッションで丁寧に設計

### 次セッション
- Phase 8 Step B: iPad 横画面スプリットビュー（左: 一覧 / 右: 入力）
- `_buildMainContent` の 5要素を private method に切り出し → isWide時に Row 構成で組み直す
- Step C（⌘ショートカット、D&D、サイドバー）は Step B 後

---
## #22 (2026-04-21) Phase 8 Step B + Step C 前半

### Step B: iPad 横画面スプリットビュー
- `_buildMainContent` を isWide 分岐で Row (左:一覧 / 右:入力) に組み替え
- 検索バー/入力エリア/機能バー/タブ/フォルダ本体を private メソッドへ抽出
- 横画面では最大化/縮小・シェブロン非表示、機能バー常時表示、下端余白、キーボード上ツールバー有効
- `_buildNarrowLayout` / `_buildWideLayout` に構造を分離

### 横画面用グリッド
- enum に `iPadWideColumns` / `iPadWideRows` 追加。選択肢を `5×6` / `4×5` / `3×4` / `2×3` / `1×可変` / `タイトルのみ` に
- iPad カードの本文表示行数を緩和（LayoutBuilder ベース、`_bodyLinesFor(context)` で動的化）
- `Responsive.isWide` に `width > height` 条件追加（iPad Pro 13 縦画面誤発動を防ぐ）

### Step C 前半: ⌘ショートカット 7種
- `⌘N` / `⌘F` / `⌘1-9` / `⌘Return` / `Esc` / `⌘Z` / `⇧⌘Z`
- `MemoInputArea` に `triggerUndo` / `triggerRedo` 公開
- `build` を `CallbackShortcuts + Focus` でラップ

### フッター・レイアウト微調整（iPad）
- 左グループ (ゴミ箱/MD/プレビュー) と右グループを Spacer で分離、間隔 1.5 倍
- Undo/Redo と最大化ボタンの左右余白強化（独立感）
- 「閉じる」とコピー/最大化の距離を対称に
- iPhone は元の配置維持

### 状態不整合の修正
- 枠外タップ判定を `isInputFocused` に（フローティングキーボード対応）
- 入力エリア以外の各セクションに `Listener(PointerDown)` ベースの `_wrapUnfocusOnTap` を被せ、Wide/Narrow 共通で一律 unfocus

### 選択モードバー
- 横画面で 7 割幅 + 画面上端〜タブ上端の中央に計算配置
- 縦画面は従来どおり

### iPad シミュ回転対応
- `Info.plist` に `UIRequiresFullScreen=true` を追加（Flutter の iPad シミュ既知バグ回避）
- 副作用として Split View / Slide Over / Stage Manager が無効化 → Phase 8 完了後に外す

### 次セッション
- 動作確認: Mac キーボード経由で⌘ショートカット検証、iPhone 実機、iPad 縦画面 Pro 13
- Step C 後半: `⌘B` / `⌘I`（太字・斜体、MD モード時）
- Step C 他要素: D&D、右クリック/長押しメニュー、サイドバー


---
## Memolette_023_iPad爆速モード仕上げ (2026-04-22)

新しい Mac でセッション開始。iPhone 実機 release ビルド + iPad Pro 13 シミュで作業。

### ⌘ショートカット完成（Step C 前半 + 後半）
- 非編集状態で⌘N等が反応しないバグ → `HardwareKeyboard.instance.addHandler` の
  グローバルハンドラに移行（フォーカス非依存）
- ⌘B (太字 `**`) / ⌘I (斜体 `*`) を MD モード時のみ発火するよう実装
- ⌘Z は TextField 編集中でも独自スナップショット Undo を優先

### 検索バー UX
- フォーカス中の hintText「検索ワードを入力」表示
- 検索フォーカス時の枠外タップで抜けるよう `_wrapUnfocusOnTap` を拡張、
  フォルダ非表示時の空白領域も unfocus 対象化

### 消しゴムボタン統合
- フロート消しゴム + 編集中機能バー (`_buildEditingBar`) 廃止
- 入力エリアフッターのゴミ箱の右に集約（編集時のみ、濃いめオレンジ）
- narrow 編集コンパクト時は機能バー全体非表示で爆速モード誤タップ解消

### ToDo / 爆速遷移アニメ短縮
- `_FastMaterialPageRoute` (150ms) に差し替え。デフォルト 300ms から半減

### 爆速モード iPad レイアウト全面調整
- オープニング / フィルタ / セット確認 / 結果 / カルーセル 全画面で
  「画面幅いっぱい・下端張り付き」系を解消
- セット確認画面に左上戻るボタン追加
- メモカード / 日付 / 弧状コントローラ / 下部操作パネル全部に max-width
- 弧の幅を iPhone 相当 (max 480) に制限して曲率維持、ボタンが沿うように
- 下部操作パネルの `MediaQuery.size.width` を `LayoutBuilder.constraints.maxWidth` に
- 削除ボタンとロックボタンの隙間を広めに (54→72)
- 弧ラインを画面端まで延長（`_ArcDividerPainter.arcWidth`）

### iPhone 実機ビルド時の罠（Mac 移動後）
- iproxy が SIP で拒否されて debug モード起動が即クラッシュ → release モードで起動
- 次セッション以降も `--release` を使う必要あり

### 次セッション
- ToDo 画面の iPad 対応（縦画面/横画面でレイアウト方針を決める）
- ToDo 画面に検索窓追加
- iPhone 実機で⌘1-9 動作確認

---
## Memolette_024 (2026-04-23)

### 成果
- 入力欄フッターの整備（閲覧/編集とも右寄せ統一、+6px シフト、等間隔化、プレビュー時の押し出し対策）
- MDトグル トースト位置をフッター上端の5px上に（親指と被らない）
- ダイアログ「上から降ってくる」挙動を修正（viewInsets 0 上書き）
- 消しゴム/削除ダイアログのキャンセル後に編集カーソルへ自動復帰（focusSafe 外し）
- `_isDialogOpen` フラグでダイアログ中のフッター切替チラつきを抑制
- iPhone 15 Pro Max 実機（release wireless）でインストール・動作確認
- Apple Developer Program 承認報告あり（TestFlight/App Store 提出が可能に）

### メインコミット
- `79cee4f` 入力欄フッター整備 + ダイアログ挙動修正

### 次セッション
- ToDo 画面の iPad 対応を本格的に（縦/横両方）

---
## Memolette-Flutter_025 (2026-04-23)

### 成果
- メモタップ→閲覧窓反映の体感速度を大幅改善（最大 ~308ms 短縮）
  - `addPostFrameCallback` を撤廃して `loadMemoDirectly` を同期実行に（~8ms @ 120Hz）
  - `GestureDetector.onDoubleTap` を外して `kDoubleTapTimeout` (300ms) 撤廃
  - ダブルタップは親側 `_handleMemoTap` で前回タップからの経過時間で自前検出
- iPhone 15 Pro Max 実機（release wireless）で体感「めちゃくちゃ早くなった」と確認

### Flutter の罠メモ
- `onDoubleTap` を GestureDetector に渡すと kDoubleTapTimeout で onTap が 300ms 遅延する
- タップ応答が重要な UI では onDoubleTap を外して親で自前検出（今回のパターンが基本形）

### メインコミット
- `3963ae2` メモタップ→閲覧窓反映の体感速度を大幅改善

### 次セッション
- ToDo 画面の iPad 対応（縦/横両方）← 前セッションからの持ち越し

---
## Memolette-Flutter_026 (2026-04-23)

### 成果
- **iPhone 縦画面固定を SystemChrome でも制御**
  - Info.plist + UIRequiresFullScreen=true だけだと効かないケースがあるため main.dart で shortestSide < 600pt なら portraitUp 固定を呼ぶように
- **ToDo 画面を iPad 横画面で左右分割レイアウトに対応**
  - メモ側 `_buildWideLayout` と同じ型で「左=リスト一覧 / 右=選択中リスト詳細」
  - `TodoListScreen` に `embedded` パラメータ追加（Scaffold 外・戻るボタン非表示）
  - `TodoListsScreen` の `_selectedListId` で選択管理、`_openList` / `_createListAndOpen` を isWide 分岐
- **横幅いっぱい問題を一掃**（iPad 横で広がっていた UI を maxWidth で制限）
  - トースト 400 / 長押しメニュー・タグピッカー 500 / 新規リスト作成 440 / 削除確認 400 / リスト長押し 500
- **タグ追加シートの位置を引き上げ**
  - 画面高 55% → 85%（最初からカラーパレットまで見える）
  - `Padding(bottom: keyboardH)` を SizedBox の外→内に移動（シート外枠はキーボードで動かず、内側コンテンツだけ上に詰める）
- **メモ入力ツールバー残留問題を修正**
  - BlockEditor 内 TextBlock にフォーカスがある状態でタグシート等を開いた時、メモ入力エリアのキーボード上ツールバーが残る不具合
  - `FocusManager.instance.addListener(_onFocusChange)` をグローバル登録、`_isInputFocused` / `_isBlockEditorFocused` を primaryFocus ベースの厳密判定に変更
- **効かない SuppressKeyboardDoneBar を削除**
  - InheritedWidget は `showModalBottomSheet` / `showGeneralDialog` 越しには参照が届かないため元々抑制が効いておらず（完了ボタンは常に出ていた）、コードの意図と動作を一致させるため削除

### Flutter の罠メモ
- `Info.plist` の向き制限は `UIRequiresFullScreen=true` と組み合わさると効かない場合あり。`SystemChrome.setPreferredOrientations` で Flutter 側でも制御すべき
- `InheritedWidget` は `Navigator.push` / `showModalBottomSheet` / `showGeneralDialog` 越しには参照が届かない。Route 跨ぎの制御には使えない
- BlockEditor のように動的に FocusNode が増減するケースは `FocusManager.instance.addListener` でグローバル監視が必要
- `FocusNode.hasFocus` はフォーカスパス上にあれば true になる緩い判定。厳密に「今入力を受けているか」判定したいときは `FocusManager.instance.primaryFocus` 比較

### メインコミット
- `293f291` iPhone 縦画面固定
- `3b7595b` ToDo iPad 横で左右分割
- `ba17e6c` トースト maxWidth 400
- `0b27b83` 長押し/タグピッカー maxWidth 500
- `c58c56c` ToDoリスト系ダイアログ/シート maxWidth
- `dedf3c5` タグ追加シート位置引き上げ
- `c855c26` タグ追加シート高 85%
- `d002295` メモ入力ツールバー残留問題
- `8590e7b` 効かない SuppressKeyboardDoneBar 削除

### 次セッション
- iPhone 実機（wireless）で最新ビルドの全体動作確認（今回 wireless が不安定でシミュ検証のみ）
- ToDo 画面に検索窓追加、複数リスト結合機能
- iPad 実機で全体動作確認

---
## #27 (2026-04-24): TODO UI 仕上げ + session-recall プロジェクト発足

### Memolette 本体の作業
- TODO リスト結合マーク位置を微調整（しおり上端寄り `top: 4`、結合モード時は `left: 22` へ右シフト）
- 結合モード中のチェックボックスと結合マークの重なり回避
- 結合モード上部バー余白タップで結合モード抜ける
- メモ一覧 select モード時も `TodoCard` に `selectModeActive` 引数で右シフト対応
- 親タグタブのフィルタボタンを `Stack + Align` で中央固定化（件数桁数で位置がずれる問題解消）
- メインコミット: `cecb85a 結合マーク位置とチェックボックス配置の調整 + フィルタボタンを中央固定`

### 動作検証
- iPhone 15 Pro Max 実機 (wireless) + iPad Pro 13-inch シミュ、両方でデプロイ検証済
- devicectl 経由の install は今回は安定、wireless でも問題なし

### 関連プロジェクト立ち上げ: session-recall
- X 経由で claude-mem (OSS) の記事を共有され試用 → バグ多・ノイズ多・週 quota 3%/往復のコスト過大で撤退判断
- 既存の `SESSION_HISTORY.md` / `HANDOFF.md` 等の手動メンテ資産を活用した自作版を計画
- `_Apps2026/session-recall/` を新規作成 (`git init` + GitHub push 済)
- 全フェーズ計画（Lv.0〜Lv.3 セマンティック検索まで、Mac/Windows 横断）を `HANDOFF.md` に詳述
- リポジトリ: https://github.com/nock-in-mook/session-recall
- 次セッションはこのプロジェクトで Phase 1 (Lv.0: CLAUDE.md 指示追加) から着手予定

### claude-mem の撤去
- セッション終了直前に完全撤去実施（session-recall 完成を待たずに撤去）
- 手順: `npm uninstall -g claude-mem`、`~/.claude-mem/` 削除、`~/.claude/plugins/marketplaces/thedotmack/` および cache 削除、`settings.json` の `enabledPlugins.claude-mem@thedotmack` と `extraKnownMarketplaces.thedotmack` 削除、worker プロセス停止
- バックアップ `~/.claude-backup-pre-claude-mem/` は残置（保険）
- 副産物の `~/.bun/`（claude-mem が自動導入）は残置、他用途で使えるので不要時のみ削除

### 学び
- claude-mem の数字（GitHub 6.6万スター、v12.3.9）は実際には盛られていなかった。一次情報で確認して判断すべき
- 上流が急速に発展中（4日で 7 リリース）で critical バグ多数の時期は時期尚早。数週間待つのも手
- のっくりさんの手動メンテドキュメント資産は claude-mem の自動要約より情報密度が圧倒的に高い

---
## #28 (2026-04-25 〜 26): iPad 実機検証 → Phase 15 カレンダービュー Step 1〜6 実装

### iPad 実機検証（main で実施）
- iPad 実機 (のっくりのiPad / iOS 26.2.1) を USB 接続して `flutter run --release`
- セッション #25〜#27 で入った変更（iPad 横分割・横幅制限・ToDo 結合 UI 等）を 9 項目チェック → 全 OK
- 機能バー入口アイコン（爆速 / ToDo）のタップ判定が 22pt しかなくシビア → 44pt のヒットエリアに拡張（main にコミット済）

### ROADMAP に Phase 15 追加 → ブランチ `feat/calendar-view`
- 「カレンダービュー」の機能要望（フォルダタイプの 1 つとして縦スクロール月別カレンダー、日付ごとに +ボタン）
- 仕様確定: 対象 = メモ + ToDoリスト + ToDoアイテム / 別カラム `eventDate` 新設 / 「全カレンダー」特別フォルダ 1 つに集約
- Plan エージェントで 9 ステップの詳細実装計画を作成
- 大物機能なので `feat/calendar-view` で作業

### Step 1: DB Migration v5
- Memos / TodoLists に `eventDate (DateTime?)` 追加
- TodoItems の `dueDate`（UI 未使用だった）を `eventDate` にリネームして統合
- `customStatement` で `ALTER TABLE ... RENAME COLUMN` （Drift 高レベル API に rename なし）
- iPad 実機で migration 動作確認、既存メモ・ToDo データ保持

### Step 2: CRUD ヘルパ + Riverpod Provider
- `createMemo` / `createTodoList` / `createTodoItem` に `eventDate` 引数
- `setMemoEventDate` / `setTodoListEventDate` / `setTodoItemEventDate`
- `watchEventCountsForRange`（3テーブル UNION ALL の raw SQL、ローカル日付グルーピング、空アイテム除外）
- `watchMemosForDay` / `watchTodoListsForDay` / `watchTodoItemsForDay`
- `eventCountsForRangeProvider` 等の Provider、`calendarTabColorIndexProvider`

### Step 3: 「全カレンダー」特殊タブ追加
- `kCalendarTabKey`、`_SpecialKind.calendar`、`_isCalendarTab`
- `_syncTabOrder` で「すべて」直後に強制保持（並び替え可・削除不可）
- `_buildTabFromKey` / `_currentTabColor` / `_showSpecialTabActions` / `_changeSpecialTabColor` に分岐
- 並び替えモードで一部タブが振動しないバグも発見・修正（`_WigglingReorderTab` の Tween 式が奇数 index で振れ幅 0 になっていた）

### Step 4: 月別カレンダー Widget
- 新規 `lib/widgets/calendar_view.dart`
- 縦スクロール ListView（前 6 ヶ月〜後 12 ヶ月）、起動時は当月までスクロール
- 月見出し + 曜日ヘッダ + 7 列日付グリッド
- **`GridView` で曜日と日付の間に謎余白が出続けたので、Row × N の手動レイアウトに切替**（Flutter の罠メモ）
- 月カードは白角丸 + 上下左右にタブ色フレーム、各カード中央に大きな月数字を透かし表示

### Step 5: 当日アイテム一覧（シート/カラム）
- 新規 `lib/widgets/day_items_panel.dart`
- 縦画面 = `showModalBottomSheet` + `DraggableScrollableSheet`
- iPad 横画面 = `Row(flex: 5 + divider + flex: 3)` で右カラム常時
- ヘッダ「2026年4月25日(水)」+ メモ/ToDo 件数アイコン + 数字
- 3 セクション（メモ / ToDoリスト / ToDoアイテム）に分けて表示

### Step 6: 「+」アクション → eventDate プリセット
- 当初は全日付セルに「+」を置いたが、ノイズなので撤去
- 0件タップ → 直接アクションシート（メモ / ToDo の 2 ボタン）
- 1件以上タップ → 当日アイテムシート（下部に「メモ・ToDoを追加」ボタン）
- アクションシートは枠外タップ + `focusSafe` で閉じる、キャンセルボタン削除
- 「アイコン ラベル +」を 1 行横並びに収めた `_AddSquareButton`
- 新規メモは `_openNewlyCreatedMemo` で先行作成 + `_focusInputTrigger++` 即フォーカス
- 空メモ/空ToDoガード `purgeEmptyMemos` / `purgeEmptyTodoLists` を整備（eventDate のみのアイテムは消える仕様）

### 仕様メモ（次セッション以降で重要）
- 件数バッジは「内容あり」のみカウント（メモ: title/content/bgColor、ToDoリスト: title or アイテム1件以上、ToDoアイテム: title）
- eventDate のみのアイテムは「中身なし」扱いで非表示・自動削除
- iPad 横幅対策はデフォルトで（auto memory に feedback 保存済）

### 動作確認
- iPhone 15 Pro Max 実機（wireless、ヘッダ修正版まで）
- iPad のっくりのiPad 実機（wireless、Step 6 fix まで）
- iPhone 15 Pro Max シミュ + iPad Pro 13-inch (M5) シミュで最新版動作確認

### 次セッション
- `feat/calendar-view` ブランチ継続
- シート（DayItemsPanel）の細部調整続き
- Step 7（メモ入力UIに日付欄）/ Step 8（ToDoに日付欄）/ Step 9（仕上げ）
- 完了したら main マージ → release タグ → TestFlight 配布

---
## #29 (2026-04-26 〜 27): カレンダー日別シート刷新 + フォーカス根治 + 爆速整理整理 + iOS 16 + Step 7

### カレンダー日別シートをフローティングオーバーレイ化
- showModalBottomSheet → 非モーダル Material オーバーレイ（barrier タップで閉じる、上の入力エリア操作可）
- `calendarSelectedDayProvider` (StateProvider) で選択日保持、CalendarView remount 越しに残る
- DayItemsPanel: 縦 1 列に戻し、セクション見出し追加、しおり、仕切り線、横長 2 ボタン
- 「無題」「無題のリスト」表記撤去、ヘッダ件数アイコンも撤去
- 背景 lightBlue.shade50、白カードは枠外余白 24pt（フローティング感）

### NavigatorObserver で全画面共通の自動 unfocus（main.dart）
- `_UnfocusOnPopObserver`: pop 時 primaryFocus を強制 unfocus
- 「ToDo 開いて閉じたらメモ入力が勝手に編集状態」系のバグ根治
- 副作用検証用 `FOCUS_REGRESSION_CHECKLIST.md` 新設（90+ 項目）

### プレビューボタンのアイコン化
- フッターの「プレビュー」テキスト → `CupertinoIcons.eye`（size 22、ON オレンジ / OFF グレー）
- 393pt 幅機種でフッターオーバーフローしてた問題を解消
- 設定に「プレビューアイコンラボ」追加（13 候補比較）

### メモ入力カーソル追従の復活
- a7291663 で入れた `MediaQuery(viewInsets:0)` 上書きを撤去
- 833d842 の BlockEditor 統合で落ちていた scrollPadding を復活
- 最大化時のみ `viewInsets.bottom + 20` を加算（縮小時は標準）

### 爆速整理モード整理（quick_sort_screen.dart）
- **カード最大化機能を完全撤去**（state / トグルボタン / フロート系）
- カード上の消しゴムボタンも撤去
- フィルタ画面の死にボタン「閉じる」→「開始」ボタンに置換
- ルーレット位置 182 → 155、本文編集ボタンの直上に絶妙に収まる

### iOS deploy target 13 → 16
- iPhone 6/7/8/X が App Store 配信対象外（旧型 375×667pt の負担減）
- 残る最小サポート: iPhone SE 2/3rd（375×667pt）→ Phase 16 で対応

### Phase 15 Step 7: メモ入力 UI に日付欄追加
- 新規 `lib/widgets/date_picker_sheet.dart`（カスタム日付ピッカー）
  - 縦スクロール、月白カード + grey.shade200 背景、itemExtent + 6 週固定で正確な中央配置
  - 上部プレビュー「YYYY年M月D日(曜)」 + 「本日」ボタン
  - 二段ボタン: キャンセル/決定 + カレンダーから消去（initial あり時のみ）
  - 「決定」を押すまで eventDate は付与されない（DB 書き込み防止）
- 多機能ボタン（…）をメニュー化、「カレンダーに載せる」/「日付を変える」を eventDate 有無で切替
- フッターの枠外右下に eventDate 表示（カレンダーアイコン + YYYY/MM/DD、grey.shade600）
- 日付スペースは常時 18pt 確保（メモカード高さが動かない、機種非依存）

### Phase 16 ROADMAP 確定（リリース前必須）
- 全画面サイズ対応のレスポンシブ化（カード実幅から比率派生）
- 検証マトリクス: SE 3rd / 13 mini / 17 Pro / Pro Max / iPad

### 動作確認
- iPhone 17 Pro シミュ中心、SE 3rd / 17 Pro Max シミュにも install 比較
- 終盤は iPhone 17 Pro 一本（remote-control 接続）

### 次セッション
- Phase 15 Step 8: ToDoリスト/アイテムに日付欄（Step 7 のピッカー共通化）
- Step 9: 仕上げ（メモカードの eventDate バッジ等）
- main マージ → release タグ → TestFlight 配布
- リリース前リグレッションチェック (`FOCUS_REGRESSION_CHECKLIST.md`)


---
## #30 (2026-04-27 〜 29) — Phase 15 Step 8 + UI 全面整備 + データ保護方針

### Phase 15 Step 8（ToDo に日付欄）
- TodoListScreen のリストヘッダ右にカレンダーアイコン、各アイテムのメモボタン隣に日付ボタン
- 付与済みアイテムはタイトル下にバッジ
- `_showListDatePicker` / `_showItemDatePicker` で既存 CRUD ヘルパに接続

### 日付ピッカー UI 全面改修
- ヘッダ刷新: 「日付を指定」+「（カレンダーに表示されます）」+ 左上 refresh、本日ボタン廃止
- 月ブロック動的高さ（4-6 週）、ListView.itemExtent 撤廃、`_calcMonthHeight` で累積 offset
- セル高 40 → 36、月見出しフォント縮小
- ボタン 3 つ全部 OutlinedButton（グレー背景 + 色枠）
- 全体高さ 0.85 → 0.74、`Align(bottomCenter)` で下端固定 + 上端下げ

### カレンダー日付セルに帯表示（オレンジ=メモ / 緑=ToDo）
- `DaySummary` 型 + `watchEventSummariesForRange` (UNION ALL、TodoList はタイトル空時に最初のアイテム名フォールバック)
- `eventSummariesForRangeProvider` を月単位購読
- 既存件数バッジ撤去 → 各セルに帯（横幅いっぱい、複数件は右端バッジ、テキスト clip）

### DayItemsPanel 横 2 列化 + 円形フロート FAB
- 左メモ / 中央仕切り / 右 ToDo（独立スクロール）
- 各列下端右下に白円 FAB（アイコン+小さい+）
- カード背景 `#F1F1F1`、`_CardShell` に elevation 1.5 ドロップシャドウ
- カード内テキスト全体縮小（タイトル 14→11、本文 12→10）
- 日付ヘッダのフォント・上下 padding を 80% に

### メモ eventDate 表示の移譲（白カード縮みを根治）
- `MemoInputArea` から build 内日付スペース撤去 → 白カード 316 のまま
- `onEventDateChanged` callback で home_screen の `_currentMemoEventDate` を更新
- `_buildFunctionBarSection` の Stack の **外側** に Positioned で日付テキスト → 編集中（機能バー height 0）でも表示
- `addPostFrameCallback` で setState during build エラー回避
- 色オレンジ、右端は白カード右枠線と一致（`right: 10`）

### 機能バー縮小 + シート閉じる動作の拡張
- `_buildFunctionBar` の SizedBox 縦幅 44 → 28（フォルダビューが上がる）
- タブ切替 / 機能バー / ナビバータップでもカレンダーシートが閉じる（`_wrapUnfocusOnTap` の `onPointerDown` 内で `calendarSelectedDayProvider` を null 化）

### ROADMAP 拡充
- Phase 9 同期に **データ保護方針** セクション追加（多重防御策・絶対遵守・リリース不可ガード）
- アイデア: Google Calendar 連携 / リマインダー / 自分宛メール / メッセージ機能
- 備忘: 選択中フォルダタブの重なり順調整

### memory に行動則を追加
- `feedback_layout_immutable.md`: 既存レイアウトは新機能で 1px も動かさない、オーバーレイで実装
- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちに Monitor は使わない（チャット通知が溢れる）

### 学び
- `Stack(clipBehavior: Clip.none)` でも Positioned が bound 外なら **タップ判定が届かない**。タップが必要な要素は Stack の bound 内（or 親側で別 Stack 設置）
- `setState during build` は callback 経由で発生しやすい。`addPostFrameCallback` で遅延が安全
- /tmp/memolette-run の ios/ も rsync 同期対象。Podfile 古いと `objective_c.framework` が組み込まれず実行時例外

### コミット & マージ
- 4 コミットに分割: Phase 15 Step 8+ピッカー / カレンダー UI / home eventDate+機能バー+シート / ROADMAP
- `feat/calendar-view` から `main` に fast-forward マージ済み、push 完了
- 追加で「データ保護方針」コミットも main へ

### 動作確認
- iPhone 17 Pro シミュ中心
- 実機 / iPad は未確認（次セッション以降）

### 次セッション (#31)
- ToDo の細かい直し（ユーザー予告）:
  - 項目入力時の謎のインデント問題
  - TODO 選択削除の実装
  - TODO カードに背景色追加
  - 全件削除の確認を 1 回にまとめる

---
## #31 (2026-04-29) — ToDo 細部修正 4 本立て（インデント / 選択削除 / 背景色 / 全削除確認）

### ToDo 編集画面のインデント問題と保存後のチラつき解消
- `_EditingItemField` の `contentPadding` を `horizontal: 10` → `EdgeInsets.zero` に揃え、編集中だけ右にずれる現象を解消
- 保存直後に DB ストリームが古い空文字を返す瞬間「（空のアイテム）」が一瞬出る問題を、楽観的タイトル `_optimisticTitles: Map<String, String>` で吸収
  - `_commitEditWithText` 内で書き込み完了後にエントリ追加、DB ストリームが追いつくフレームで `addPostFrameCallback` 経由で破棄

### TODO フォルダに選択削除モード追加（メモ混在フォルダと同等の体験）
- 緑エリア左下に円形フロート削除ボタン（メモ一覧フッターのゴミ箱と同じスタイル: `_capsuleDeco` 相当）
- 選択削除モード時のヘッダー: [キャンセル] / N件 選択中 / [削除]（ボタンに件数なし、中央テキストに件数）
- TODO タブの中央付近に 1 行ポップアップ「削除するToDoを選択してください」（白背景・赤枠 2pt・影、Stack `clipBehavior: Clip.none` で TODO タブの 40pt 領域から下にはみ出させて配置、`top: 5`）
- カードタップで選択トグル、未選択カードは半透明（既存の結合モードと同じ overlay）、選択中カードは左上に赤チェックバッジ
- ロック中リストは選択不可（トースト警告）
- 削除確認ダイアログを 1 行構成に統一: タイトル「選択したToDoを削除」/ メッセージ「N件のToDoを削除します。よろしいですか？」（件数の重複を排除）
- メモ混在フォルダ側のダイアログも同形式（「選択したメモを削除」/「N件のメモを削除します。よろしいですか？」）に揃えた

### メモ・ToDoカードの長押しメニューに「背景色」を追加
- DB Migration v5 → v6: `TodoLists` テーブルに `bgColorIndex` (int, default 0) を追加
- `setTodoListBgColor(id, index)` を `database.dart` に新設
- `_BgColorPickerDialog` を `lib/widgets/bg_color_picker_dialog.dart` に切り出して `BgColorPickerDialog` として public 化（メモ・ToDo 両方から利用）
- メモ長押しメニュー（`home_screen._showMemoActions`）に「背景色」項目追加（パレットアイコン）
- ToDoリスト長押しメニュー（`home_screen._showTodoActions` / `todo_lists_screen._showListActions`）にも同項目を追加
- `TodoCard` と `todo_lists_screen` のカード描画で `bgColorIndex` を反映
- ToDoカードはチェックボックス可読性のため、メモカードよりさらに白に40%寄せて薄める: `Color.lerp(base, Colors.white, 0.4)`

### 項目全件削除の確認を 1 回に統合（todo_list_screen）
- `_showClearAllConfirm` を削除し、`_showClearAllDialog` の「全て削除する」から直接 `_clearAllItems` を呼ぶ
- 件数と注意書きは 1 回目のダイアログで既に表示しているため、2 回目の「本当によろしいですか？」は冗長

### 選択モードのカード見た目を旧 Row 形式に戻す（home_screen）
- 終了直前に発覚: 4/24 のコミット `cecb85a`「結合マーク位置とチェックボックス配置の調整」で Stack + Positioned(-6,-6) の「カード上に○を浮かべる」形式に変更されていた
- ユーザーから「カードに重なって見切れている」「以前のように左にチェックボックス・カード右シフトに戻したい」要望
- 3 箇所（`_FrequentTabContent` / `_MemoGridView._buildCard` / `_MemoGridView._buildTodoCard`）を旧 Row { Center(icon), SizedBox(6), Expanded(card) } 形式に復元

### ROADMAP 追記
- 備忘: メモ選択削除のUI崩壊修正 / フォルダ最大時の選択モードUI最適化 / 上記を Phase 8（iPad）チェック項目にも追加
- Phase 14（リリース準備）に「アクセシビリティ：文字サイズ拡大の影響箇所を全洗い出して塞ぐ」を追加（重点チェック箇所と方針付き）

### 開発フロー確立
- Google Drive 上でビルドできない問題は `/tmp/memolette-run` 経由で回避（既存運用）
- ホットリロード: FIFO `/tmp/flutter_pipe` を作って flutter run の stdin に流す
  - keeper: `nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe' &` で writer 端を常駐保持
  - リロード: `echo r > /tmp/flutter_pipe`
  - rsync 後にこれを送ると 0.5 秒程度で UI に反映できる（デバッグビルド前提）
- メモリに `feedback_no_monitor_for_build.md` 既存ルール: ビルド完了待ちで Monitor を使わない（チャット通知が溢れる）

### 次セッション (#32) 候補
- 実機 / iPad での今回変更の動作確認
- ROADMAP 備忘の整理:
  - メモ選択削除のUI崩壊修正
  - フォルダ最大時の選択モードUI最適化
- Phase 15 Step 9: メモカードに eventDate バッジ表示
- Undo/Redo スナップショットへの eventDate 統合
- Phase 14 のアクセシビリティ文字サイズ対応（リリース前タスク）

---
## #32 (2026-04-29)

### Phase 15 Step 9: メモ・ToDoカードにバッジ表示
- メモカード右上に eventDate（橙）/ MD（紫）/ Pin（青）/ Lock（赤）のバッジを Stack でオーバーレイ
- MD バッジは Swift 版の `containsMarkdown` を `lib/utils/markdown_detect.dart` に regex 移植して内容ベース判定
- ToDoカード（メモ一覧グリッド + ToDo一覧画面）にも同形式のバッジ追加
- サムネイル比率の潰れ修正: `Stack` + `Positioned` + `LayoutBuilder` で正方形セルにフィット
- バッジ操作時のサムネイル再ロードによるチラつき → `ImageStorage.absolutePathSync` を新設して同期取得し初フレームで決定

### Phase 16: レスポンシブ対応（SE 3rd / 13 mini / 標準）
- 機種別グリッドオプション: SE は 3×2/2×2、mini は 3×4/2×4、標準は 3×6/2×5
- `_phoneSizeClass` / `_gridRowsFor` / `_availableGridOptions` ヘルパーで分岐
- カレンダー初期スクロール: `_today` から `weekIndex` を算出して今日が常にビューポート中央に来るよう調整
- 爆速整理画面: 画面高 700px 未満で上部余白 70→30 にして SE 3rd の overflow 回避
- 爆速整理 最終カードの右下「完了」テキストボタン → 虹色グラデーション三角形（`_TriangleNavButton.rainbow`）に変更してロックボタンとの被り回避
- ToDo カードのセル高をメモカードと一致

### ToDo 編集画面の状態遷移修正（多数）
- アイテム編集中に他アイテム / タイトル / メモ をタップ → 自動コミットしてから次の操作へ
- `_committingIds: Set<String>` で per-id ガード（単一フラグだと Y commit が漏れる問題を解消）
- dispose 時の commit が次アイテムを上書きしないよう `if (_editingItemId == id)` ガード
- 「完了」 キーボードボタンで commit → `_focusNode.addListener(_handleFocusChange)` で focus loss 検知
- 親 GestureDetector の onTap が子のタップを奪う問題 → outer `Listener(onPointerDown:)` に変更
- onTapOutside は no-op（commit は dispose と focus listener に任せる）
- タイトル TextField の `contentPadding: zero` で左インデント解消
- 親項目の追加ボタンは emptyState のみ全幅、通常時はアイコン部のみタップ反応

### ダイアログデザイン共通化
- `lib/widgets/dialog_styles.dart` 新設: `title` / `message` / `actionLabel` / `bodyDecoration` / `accentButtonDecoration` / `textGrey` / `destructive` / `defaultAction` を一箇所集約
- `confirm_delete_dialog.dart` と `frosted_alert_dialog.dart` を `DialogStyles` 参照にリファクタ → 値変更で全ダイアログ一括反映
- 視認性向上: タイトル w600→w700 / 本文 w400→w500 / ボタン w500→w600、グレー alpha 0x99→0xCC（テキストより濃く）
- メモ上限（旧 CupertinoAlertDialog）→ `showFrostedAlert` に統一
- 設定画面の全データ削除（旧 AlertDialog）→ `showConfirmDeleteDialog` に統一
- 爆速整理の `_DeleteConfirmDialog` は独自デザイン（アイコン+Divider）として据え置き

### 選択モード見た目調整
- 「削除するメモを選択してください」バナー位置をフォルダタブより前面 + ノッチ回避位置に
- 選択削除ボタンのドロップシャドウ・不透明背景化（半透明だとシャドウが透けて灰色っぽく見える問題）
- ToDo 一覧の選択削除ラベル「削除」→「選択削除」、alpha 0.6→0.85
- 選択削除モードのカード見た目を旧 Row 形式（チェックボックス+カード横並び）に維持
- フォルダ最大化中の選択モード → 最大化を維持しつつ選択可能に

### タブ周り改善
- タブ z-index: 選択中=最前面、隣接=次、遠い=奥（`_ZOrderedRow._frontToBackOrder` で距離順制御）
- 親タグ追加直後にそのタブへ自動スクロール（リトライ付きで描画完了後に確実に移動）
- タグ表示の動的配分: TextPainter で自然幅を測り、短辺は自然 / 長辺に余白配分
- フォルダ最大化 → 新規メモ → 抜けられないループの根本修正（`_onFocusChange` で `widget.isExpanded` 中は `widget.onClosed()` をスキップ）
- ルーレットの親タグ削除後リセット（`_syncToSelection` に `selectedParentId == null` 分岐追加）

### ROADMAP 追記
- フィルタボタンに「名前順」ソート（昇/降順トグル）
- **NewTagSheet を Memolette オリジナル風に改修**（次セッション最有力タスク。現状は iOS ナビゲーションバー風 + 入力欄背景同化）
- アプリ全体の iOS 風 UI 要素を洗い出して脱却（Android リリース見据えて）

### 開発環境
- iOS 26.3 ランタイムを使った SE 3rd / 13 mini シミュを追加作成（iOS 17.2 サブイメージは Flutter 認識しないため）
- 二系統 FIFO（`/tmp/flutter_pipe` + `/tmp/flutter_pipe_13`）で SE と mini を並列ホットリロード
- 別 `/tmp/memolette-run-13` ディレクトリに rsync して並列 flutter run

### ブランチ運用
- `feature/phase-16-responsive` で Phase 16 を進めて main にマージ済み
- 一連のダイアログ統一作業も main で完了

### 次セッション (#33) 候補
- **NewTagSheet のオリジナル風改修（最有力）**
- アプリ全体の iOS 風要素の洗い出しと置き換え
- ダイアログ巡回の続き: フィルタプルダウン / 背景色ピッカー / グリッドサイズ選択メニュー / ピッカー / バナー
- 実機 / iPad での Phase 15 Step 9 + Phase 16 動作確認
- Phase 14: アクセシビリティ文字サイズ対応（リリース前タスク）

---
## #33 (2026-04-30 〜 05-01) — タグシート系総整備 + 重大バグ4件修正 + 回帰防止ルール追加

### 主な変更
- NewTagSheet のデザインを DialogStyles 統一（白背景・Hiragino Sans・w700/w500/w600・defaultAction）
- 親タグ削除の CupertinoActionSheet を Memolette オリジナルに置換（lib/widgets/tag_delete_choice_dialog.dart 新規）
- KeyboardDoneBar 二重表示の解消（main.dart で全画面に既掛かりのため、各画面・シート側を削除）
- ルーレット親タグ内側端が子タグ判定に吸われるバグ修正（垂直線判定→半径判定）
- ルーレット開時に入力欄/検索欄フォーカスで自動クローズ（共存はバグの元なので排他）

### 重大バグ修正
- **新規メモが保存されない**: 920c0bd の早期 return ガードが立ち上がりかけの onMemoCreated も弾いていた。`_pendingNewMemoCreation` フラグで両立
- **タグ残存（async レース）**: `_loadMemo` / `loadMemoDirectly` の await 中に別メモへ遷移すると古いタグで `_attachedTags` を上書きしていた。await 完了時に `widget.editingMemoId` 一致チェック
- **タグ残存（pending）**: editingMemoId が null→null だと `_clearInput` が呼ばれない。`focusRequest` 変化＋両方 null で明示クリア

### グローバル CLAUDE.md
- 「★ 回帰バグ防止ルール」追記。ガード追加・変更前の3項目チェックリスト

### 次セッション最有力タスク
- BgColorPickerDialog の DialogStyles 統一
- アプリ全体の iOS 風要素の追加洗い出し
- ダイアログ巡回の続き（C 選択肢メニュー / E ピッカー / F バナー）
