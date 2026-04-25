# 引き継ぎメモ

## ★ Mac 移動: iPhone 実機ビルド時の罠（次セッション以降も注意）

USB 経由で iPhone (00008130-0006252E2E40001C) に **debug モード** で
`flutter run` すると、`iproxy` ポートフォワードでエラー終了し、Dart VM に
接続できないままアプリが起動 → 即クラッシュ（EXC_BAD_ACCESS / SIGBUS、
クラッシュレポート確認済）。

**回避策**: `flutter run --release -d <iPhone UDID>` で起動する。

(再現条件: macOS Tahoe 26.3.1 + iOS 26.3.1。`sudo launchctl kickstart -k
system/com.apple.usbmuxd` も SIP で拒否される。)

iPad シミュ ID は HANDOFF 古い値 (`C6A8AF6B-...`) ではなく
現在は iPad Pro 12.9-inch (6th gen) = `1F181174-7768-44DB-9BDA-E9E9976695F0`。

wireless 接続だと iPhone がスリープするたびに `Installing and launching` が
「Could not run」で失敗する → iPhone を起こしてから再試行。
**今セッションでも wireless が非常に不安定で、起こした状態でも
`Installing` フェーズで Could not run になり続けた**。
古いバイナリだけ残って新版がインストールされていないのに「青いドット」が
出ることがあるので注意。次回は USB ケーブル or iPhone シミュで検証推奨。

---

## ★ Apple Developer Program 承認済み

2026-04-22 に Apple Developer Program 登録完了報告あり。TestFlight 配信 /
App Store 審査提出が可能な状態。

Flutter 側 `ios/Runner.xcodeproj` の Team 設定は個人 Team のまま
（CF34X3P59Y）。必要に応じて法人/個人 Developer Team へ切り替え。

関連資料: `/Users/nock_re/Library/CloudStorage/GoogleDrive-yagukyou@gmail.com/マイドライブ/_Apps2026/APP_RELEASE_GUIDE.md`

---

## 現在の状況

- **セッション#28 完了**（2026-04-25 〜 26）
- ブランチ: **`feat/calendar-view`**（main にマージ前、未完）
- 最終コミット: `e69971b` シート日付ヘッダ右端にメモ/ToDo件数をアイコン付きで表示
- セッション#27 から +27 コミット（Phase 15 カレンダービュー実装中）
- iPhone/iPad シミュ + iPad/iPhone 実機（wireless）で動作確認進めた

## #28 のサマリ: Phase 15 カレンダービュー Step 1〜6 完了 + UI 調整

新規ファイル
- `lib/widgets/calendar_view.dart` — 「全カレンダー」タブ本体（縦スクロール月別 + iPad 横スプリット）
- `lib/widgets/day_items_panel.dart` — 当日アイテム一覧パネル

ブランチ運用: 大物機能なので `feat/calendar-view` で作業中。次セッションで仕上げ→main マージ予定。

### Step 1: DB Migration v5
- Memos / TodoLists に `eventDate (DateTime?)` 追加
- TodoItems の `dueDate` を `eventDate` にリネーム（カレンダー紐付け日に統合、UIで未使用だった dueDate を流用）
- `customStatement` で `ALTER TABLE ... RENAME COLUMN`
- iPad 実機で migration 動作確認済

### Step 2: CRUD ヘルパ + Riverpod Provider
- `createMemo` / `createTodoList` / `createTodoItem` に `eventDate` 引数追加
- `setMemoEventDate` / `setTodoListEventDate` / `setTodoItemEventDate` 新設
- `watchEventCountsForRange` （3テーブル UNION ALL の raw SQL、ローカル日付で GROUP BY、空アイテム除外）
- `watchMemosForDay` / `watchTodoListsForDay` / `watchTodoItemsForDay`
- `eventCountsForRangeProvider`、`memosForDayProvider`、`todoListsForDayProvider`、`todoItemsForDayProvider`
- `calendarTabColorIndexProvider` (StateProvider, default 36 = 薄紫)

### Step 3: 「全カレンダー」特殊タブ追加
- `kCalendarTabKey = '__calendar__'`、`_SpecialKind.calendar`、`_isCalendarTab`
- `_syncTabOrder` で「すべて」直後に強制保持（並び替え可能・削除不可）
- `_buildTabFromKey` / `_currentTabColor` / `_showSpecialTabActions` / `_changeSpecialTabColor` に分岐追加
- `_buildFloatingBottomBar` は calendar タブで非表示

#### #28 副次バグ修正
- `_WigglingReorderTab` の Tween 式が奇数 index で振れ幅 0 になっていたバグ修正
  （並び替えモードで一部タブがプルプルしない問題）
- 機能バー入口アイコン（爆速/ToDo）のタップ判定を 22pt → 44pt に拡張

### Step 4: 月別カレンダー Widget
- 縦スクロール ListView（前 6 ヶ月〜後 12 ヶ月）
- 月見出し + 曜日ヘッダ + 7 列日付グリッド
- **GridView は shrinkWrap 下で曜日ヘッダと日付グリッドの間に謎余白が出たので、Row × N の手動レイアウトに変更**（重要な判断）
- 各セル: 日付数字（土日色分け）+ 件数バッジ（オレンジ）+ 「+」アイコン → Step 6 で動作配線後に「+」削除
- 当日セル: 青円 + 背景色強調
- 月カードは白角丸、上下左右にタブ色のフレームを見せる
- 各月カードの中央に `fontSize 200` の月数字を `Positioned.fill + Center + IgnorePointer` で透かし表示

### Step 5: 当日アイテム一覧（シート/カラム）
- `DayItemsPanel`: 日付タップで当日のメモ/ToDoリスト/ToDoアイテムを 3 セクションで表示
- iPad 横画面: `Row(flex: 5 + 1px divider + flex: 3)` で右カラム常時表示
- 縦画面: `showModalBottomSheet` + `DraggableScrollableSheet`
- アイテムタップで既存遷移（メモは `_openMemo`、ToDoリストは `_openTodoList`）
- ToDoアイテム個別の親リスト紐付けジャンプは将来対応（Step 5b）

### Step 6: 「+」アクション → eventDate プリセット
- 当初は全日付セルに「+」アイコンがあった → ノイズなので **撤去**
- 0件の日タップ → 直接アクションシート（メモ作成 / ToDo作成）
- 1件以上の日タップ → 当日アイテムシート（下部に「メモ・ToDoを追加」ボタン）
- iPad 横スプリットでも右カラム下部に追加ボタン常時
- アクションシート（`_AddActionSheet`）は枠外タップ + `focusSafe` で閉じる、キャンセルボタン削除
- 「アイコン ラベル +」を 1 行横並びにした `_AddSquareButton`（メモ ↔ ToDo の 2 ボタン）
- ヘッダ表記は「2026年4月25日(水)」形式、土日色分け（赤/青）
- シート右端にメモ/ToDo 件数をアイコン+数字で表示
- `_openNewlyCreatedMemo` を home_screen.dart に新設（`_focusInputTrigger++` で即フォーカス）
- 空メモ/空ToDoリストガードに `purgeEmptyTodoLists` を追加
- **eventDate のみのメモは「中身なし」扱いで非表示／自動削除**（仕様確定）
  - 件数バッジは入力後に増える、空のまま放置すると消えるのが正解

## 次のアクション（次セッション）

### Phase 15 続き（feat/calendar-view ブランチ継続）
- **シート（DayItemsPanel）の調整続き** — ヘッダ件数アイコン以外の細部
- **Step 7: メモ入力UIに日付指定欄追加**
  - `memo_input_area.dart` のフッターツールバーに日付ボタン
  - カスタム日付ピッカーシート（標準 showDatePicker は禁止ルール）
  - キーボード閉じてからピッカー（バグ #20 回避）
- **Step 8: ToDoリスト/アイテム編集に日付欄追加**
  - リストヘッダに「リスト全体の日付」、各アイテム行に日付アイコン
  - Step 7 のピッカーシートを共通化して再利用
- **Step 9: 仕上げ・整合性**
  - メモカードに eventDate バッジ表示（grid1x2/grid1flex でのみ）
  - ToDo 結合 (`mergeTodoLists`) で eventDate もコピー（既に対応済）
  - Undo/Redo スナップショットに eventDate 含める
  - 文字列定数を集約

### Phase 15 完了後
- main へマージ → release タグ
- TestFlight 内部配布セットアップ
- 爆速整理モードの iPad 対応

## 技術メモ（#28 で蓄積）

### Drift Migration: ALTER TABLE RENAME COLUMN
- Drift の Migrator API には rename 用の高レベルメソッドは無い
- `customStatement('ALTER TABLE todo_items RENAME COLUMN due_date TO event_date')` で対応
- SQLite 3.25+ で利用可、iOS 26 系は対応済み

### GridView の余白挙動
- `GridView.builder(shrinkWrap: true, mainAxisExtent: ...)` で日付セルを並べたら、曜日ヘッダと最初の行の間に **謎の大きな余白** が出ていた
- `childAspectRatio` でも同様の挙動
- 確実に制御したいときは Row × N の手動レイアウトの方が安定（calendar_view.dart の `_MonthBlock`）

### 件数バッジ集計の SQL（3 テーブル UNION ALL）
- `customSelect` で raw SQL 書く
- `date(event_date, 'unixepoch', 'localtime')` でローカル日付に変換
- `Variable<DateTime>(start)` で DateTime をパラメータに渡す（Drift デフォルトは Unix seconds 保存）
- 各テーブルで「内容あり」フィルタを SQL 側でかける（メモ: title/content/bgColor、ToDoリスト: title or アイテム1件以上、ToDoアイテム: title）

### iPhone wireless ビルドの取り扱い（再確認）
- `flutter run --release` で「Could not run」が初回 → リトライで Installing 完了 → 「Error running application」で flutter run プロセス自体は exit 2
- でも **iPhone にはアプリインストール済み**（2回目の Installing が成功している）
- ホーム画面のアプリアイコンから手動起動すれば最新版が動く

### Xcode 並列ビルドの DerivedData 衝突
- 4 デバイス並列で `flutter run` すると Xcode の DerivedData VFS yaml が壊れて `Could not write file ... -VFS-iphonesimulator/all-product-headers.yaml` エラー
- 対処: `rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*` でクリア後、シリアル or 2 並列までに抑える
- 自動リトライは効くが時間が伸びる

### `_focusInputTrigger` パターン
- `MemoInputArea` の `focusRequest: int` を `setState` でインクリメントするとフォーカス発火
- 新規メモ作成→編集モード突入の標準パス
- カレンダーから「+」で先行作成したメモを開くときに使う（`_openNewlyCreatedMemo`）

### showModalBottomSheet 閉時の編集モード突入問題
- Navigator の自動フォーカス復元で、シート閉時に MemoInputArea の TextField にフォーカスが戻る → キーボード出る → 編集モード突入
- 対処: `focusSafe` でラップ、または手動で `FocusManager.instance.primaryFocus?.unfocus()` を開閉前後に呼ぶ

### iPad 横幅対策はデフォルトで（auto memory にも保存）
- 新機能のダイアログ・シート・パネルは最初から `maxWidth` 制限する
- ボタン類が間延びしないよう `Center + ConstrainedBox` で囲む
- 後追いで直すより設計時に入れるほうがコスパ良い

## #27 で完了したこと

### TODO リスト UI の細部仕上げ
- 結合済みマークを「しおり上端とカード上端の中間寄り」に再配置 (`todo_lists_screen.dart` / `todo_card.dart`)
- 結合モード中のチェックボックスと結合マークの重なり回避（マークを `left: 22` へ右シフト）
- 結合モード上部バー（キャンセル⇔結合する間の余白）タップで結合モード抜ける
- メモ一覧の select モードでも TodoCard の結合マークが右シフトするよう `selectModeActive` 引数追加

### 親タグタブのフィルタボタンの位置ゆれ解消
- `Row + Expanded` だと件数の桁数でフィルタボタン位置が左右に動いていた
- `Stack + Align(centerLeft)` に変更、フィルタボタンは常にバー中央固定
- 件数＋子タグバッジは左にオーバーレイ表示

### 本業以外の進捗（関連プロジェクト立ち上げ）
- **`_Apps2026/session-recall/` を新規作成**（2026-04-24）
- claude-mem (OSS) を試用したが、バグ多・ノイズ多・高コストと判明 → 自作路線へ
- 既存の `SESSION_HISTORY.md` / `HANDOFF.md` を Claude が横断検索する仕組みを段階的に作る計画
- GitHub: https://github.com/nock-in-mook/session-recall
- 経緯と全フェーズ計画は `session-recall/HANDOFF.md` に詳細記載済み

### claude-mem は完全撤去済み
- `npm uninstall -g claude-mem`（グローバル npm パッケージ削除）
- `~/.claude-mem/`（DB・設定・ログ）削除
- `~/.claude/plugins/marketplaces/thedotmack/` および cache 削除
- `~/.claude/settings.json` の `enabledPlugins.claude-mem@thedotmack` と `extraKnownMarketplaces.thedotmack` を削除
- Worker プロセスも停止
- 副産物の `~/.bun/`（claude-mem が自動導入）は残置（他で使える可能性あり、不要なら後で `rm -rf ~/.bun` で削除可）
- 元の Claude 設定のバックアップ: `~/.claude-backup-pre-claude-mem/`（小さいので残置で問題なし）

## #26 で完了したこと

### iPad 横画面のレイアウト整備
- **iPhone 縦画面固定を SystemChrome でも制御**
  - Info.plist の UISupportedInterfaceOrientations だけでは UIRequiresFullScreen=true と
    組み合わさったとき効かないケースがあったため、`main.dart` で PlatformDispatcher
    から shortestSide を測って iPhone (< 600pt) は portraitUp 固定
- **ToDo 画面を iPad 横画面で左右分割レイアウトに対応**
  - メモ側 `_buildWideLayout` と同じ型
  - `TodoListScreen` に `embedded` パラメータ追加（Scaffold/SafeArea 外し、戻るボタン非表示）
  - `TodoListsScreen` の `_selectedListId` ステートで選択管理、`_openList` と
    `_createListAndOpen` で isWide 時は `Navigator.push` せず setState に分岐

### 横幅いっぱい問題の一掃（iPad 横で広がりすぎる UI）
- **トースト**: maxWidth 400pt (`utils/toast.dart`)
- **メモ/ToDo 長押しメニュー + タグピッカー**: maxWidth 500pt (`home_screen.dart`, `quick_sort_screen.dart`)
- **新規リスト作成ダイアログ**: maxWidth 440pt / 削除確認ダイアログ: maxWidth 400pt / リスト長押しメニュー: maxWidth 500pt (`todo_lists_screen.dart`)

### タグ追加シートの位置改善
- 画面高 55% → 85% に拡大（最初からカラーパレットまで見える）
- `Padding(bottom: keyboardH)` を SizedBox の外→内に移動し、
  シート外枠はキーボードで動かず内側コンテンツだけ上に詰めるように

### メモ入力ツールバー残留問題の修正
- 症状: メモ本文（BlockEditor 内 TextBlock）にフォーカスがある状態でタグシート等を開き、
  そちらの TextField にフォーカス→キーボード出すと、メモ入力エリアのキーボード上
  ツールバー (ゴミ箱/MD/画像/Undo/Redo/完了) が残留表示される
- 原因: `_onFocusChange` リスナーが `_titleFocusNode` / `_contentFocusNode` にしか
  張られておらず、BlockEditor 内の動的 FocusNode や別 route への primaryFocus 移動を
  検知できていなかった。加えて `_isInputFocused` が hasFocus ベース（緩い判定）で、
  別 route の TextField に primaryFocus が移っても true のまま残ることがあった
- 修正:
  - `block_editor.dart` に `hasActivePrimaryFocus` を追加（primaryFocus ベース厳密判定）
  - `memo_input_area.dart` の `_isBlockEditorFocused` / `_isInputFocused` を
    primaryFocus ベースに変更
  - `initState` で `FocusManager.instance.addListener(_onFocusChange)` を登録
    （dispose で removeListener）。別 route への入力移動も即検知できる

### 効かない SuppressKeyboardDoneBar の削除
- `SuppressKeyboardDoneBar` は InheritedWidget で「子ツリーの KeyboardDoneBar を抑制」する
  設計だったが、実際の使用箇所はすべて `showModalBottomSheet` / `showGeneralDialog`
  経由で別 Route として表示されるため、**InheritedWidget の参照が親ツリーに届かず抑制が効いていなかった**
- 結果として完了ボタンは常に出ていた（ユーザーの希望動作と一致）ので、
  見た目だけ「抑制している風」のコードを整理削除

## Flutter の罠メモ（次回以降も注意）

- `Info.plist` の向き制限は `UIRequiresFullScreen=true` と組み合わさると効かない場合あり。
  `SystemChrome.setPreferredOrientations` で Flutter 側でも制御すべき
- `InheritedWidget` は `Navigator.push` / `showModalBottomSheet` / `showGeneralDialog` 越しには
  参照が届かない（子 Route の要素からは親 Route の InheritedWidget が見えない）。
  Route 跨ぎの抑制/制御は `ValueNotifier` や静的フィールド経由で
- BlockEditor のように **動的に FocusNode が増減する** ケースで、
  特定 FocusNode の addListener では変化を捕捉できない。`FocusManager.instance.addListener`
  でグローバル監視すべき
- `FocusNode.hasFocus` は「フォーカスパス上にあれば true」の緩い判定。
  別 route に primaryFocus が移っても親 route 側で hasFocus=true のままになりうる。
  厳密に「入力を受けているか」を判定したいときは `FocusManager.instance.primaryFocus` 比較

## 次のアクション（次セッション）

### Memolette 本体
- **iPad 実機で全体動作確認**
- **iPhone 実機で ⌘1-9 動作確認**（シミュでは Window メニューが横取り）

### 別プロジェクトでの作業（session-recall）
- `_Apps2026/session-recall/` に移動して Phase 1 から開始
- 詳細は `session-recall/HANDOFF.md` を参照

### 優先度低
- **TestFlight 内部配布セットアップ**（Apple Developer 登録済みの活用）
- `Info.plist UIRequiresFullScreen=true` を外す（マルチタスキング復活）
- 爆速整理モードの iPad 対応（縦/横）

## 技術メモ

### iPhone 実機ビルド (Mac, wireless)
- `flutter run --release -d 00008130-0006252E2E40001C`
- iPhone スリープ中はインストール失敗するので、再試行時は画面を起こす
- Google Drive 上で直接ビルドは codesign エラー → `/tmp/memolette-run` に
  rsync してからビルド
- `/tmp/memolette-run` は再起動で消えるので、次セッション先頭で再作成が必要

### シミュレータ ID（現行）
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 15 Pro Max: `95C8A8C5-0972-4BB0-B793-5219096697DF`

### コード構造の注意
- `home_screen.dart` は 6300 行超
- `quick_sort_screen.dart` は 4400 行超（_QuickSortScreen 本体 + Card + Painter 群）
- `MemoInputArea` (`memo_input_area.dart`) は 3000 行超
- `todo_list_screen.dart` は 3156 行超（embedded 対応で少し増）
- `utils/safe_dialog.dart` の `focusSafe` はダイアログ閉時のキーボード自動再表示を
  抑制するラッパー。**編集中にダイアログを開いてキャンセル後に編集続行したい
  場面では使わない**こと（Navigator の自動フォーカス復元が効かなくなる）

### ダイアログ設計の定石（#24 で確立）
編集中に出すダイアログ（本文クリア / 削除 など）:
1. `focusSafe` を使わない（自動フォーカス復元を活かす）
2. `builder` 内で `MediaQuery(data: ...copyWith(viewInsets: EdgeInsets.zero))`
   でキーボード連動を切る
3. `_isDialogOpen` フラグを立ててフッター表示を編集モードで固定
4. `_isInputFocused` を使う条件（閉じる表示など）にも `!_isDialogOpen` を追加

閲覧中に出すダイアログはそのままでも問題ない（`wasEditing` ガード）。

### iPad 横幅制限の定石（#26 で確立）
iPad 横画面で画面いっぱいに広がる UI は、`Center + ConstrainedBox(maxWidth: N)` で
中央寄せ＋最大幅制限する：
- ダイアログ系: 320-440pt
- ボトムシート: 500pt
- トースト: 400pt

iPhone では画面幅 < maxWidth なので ConstrainedBox は実質効かず、見た目は従来通り。
