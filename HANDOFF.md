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

- **セッション#27 完了**（2026-04-24）
- ブランチ: `main`
- 最終コミット: `cecb85a` 結合マーク位置とチェックボックス配置の調整 + フィルタボタンを中央固定
- iPhone 15 Pro Max **実機 (wireless)** + iPad Pro 13-inch シミュで動作確認済
- 今回は wireless デプロイ安定、devicectl 経由で問題なし

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
- **ToDo 画面に検索窓追加**（メモ側と同等）
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
