# 引き継ぎメモ

## ★ Mac 移動: iPhone 実機ビルド時の罠（次セッション以降も注意）

USB 経由で iPhone (00008130-0006252E2E40001C) に **debug モード** で
`flutter run` すると、`iproxy` ポートフォワードでエラー終了し、Dart VM に
接続できないままアプリが起動 → 即クラッシュ（EXC_BAD_ACCESS / SIGBUS、
クラッシュレポート確認済）。

**回避策**: `flutter run --release -d <iPhone UDID>` で起動する。

(再現条件: macOS Tahoe 26.3.1 + iOS 26.3.1。`sudo launchctl kickstart -k
system/com.apple.usbmuxd` も SIP で拒否される。)

iPad シミュ (`C6A8AF6B-C3E8-4B93-BCCC-E8C398D4491F`) は通常通り debug で OK。

---

## 現在の状況

- セッション#23 完了（2026-04-22）
- ブランチ: `main`
- 最終コミット: `ca020ff` 爆速モード弧ライン延長
- iPad Pro 13 シミュ縦画面と iPhone 15 Pro Max 実機（release）で動作確認済

## #23 で完了したこと

### ⌘ショートカット完成 (Step C 前半 + 後半)
- `CallbackShortcuts + Focus(autofocus)` だとフォーカスツリーから抜けると
  キーが届かず、非編集状態で⌘N等が反応しなかった。
  → `HardwareKeyboard.instance.addHandler` のグローバルハンドラに移行
- ⌘N / ⌘F / ⌘Return / Esc / ⌘Z / ⇧⌘Z 動作確認 OK（iPad シミュ + Mac キーボード）
- ⌘1-9 はシミュ Window メニューが横取りするため未確認 → 実機で要確認
- ⌘B (太字 `**`) / ⌘I (斜体 `*`) を MD モード時のみ発火するよう実装。
  `BlockEditor.wrapFocusedSelection(wrapper)` + `MemoInputArea.triggerWrapMarkdown` 追加
- ⌘Z は TextField 編集中でもアプリ独自スナップショット Undo を使用
  （TextField ネイティブだとフィールド単位でしか戻らないため）

### 検索バー UX 改善
- フォーカス中に hintText「検索ワードを入力」を表示
- 検索フォーカス時の枠外タップでフォーカス解除（_wrapUnfocusOnTap の条件に
  `_searchFocusNode.hasFocus` を追加 + フォルダ非表示時の空白領域も対象化）

### 消しゴムボタン整理
- フロート消しゴム (`_buildFloatingEraserButton`) と編集中機能バー
  (`_buildEditingBar`) を廃止
- 入力エリアフッターのゴミ箱の右に集約（編集時のみ、濃いめのオレンジ）
- narrow 編集コンパクト時は機能バーセクション全体を非表示にして、
  爆速/ToDo ボタンへの誤タップを解消
- `EraserGlyph` に color 引数を追加（白以外も渡せるように）

### 遷移アニメ短縮
- ToDo / 爆速モード遷移を `_FastMaterialPageRoute` (150ms) に差し替え。
  デフォルト 300ms から半減。

### 爆速モード iPad レイアウト全面調整
- オープニング画面: 「次へ」ボタンを固定幅 220 + 中央寄せ、説明文の下に配置
- フィルタ画面: フィルタリスト本体を maxWidth 560 中央寄せ、開始ボタンを
  スクロール領域内のフィルター直下に
- セット確認画面: 左上に戻るボタン追加、セット一覧 maxWidth 560、開始ボタン
  もセット一覧直下に配置
- 結果画面: 戦績カード maxWidth 560、ボタン群を戦績カード直下に配置
- カルーセル画面:
  - メモカード maxWidth 620 中央寄せ
  - 日付（更新日/作成日）もカードと同じ maxWidth で左端揃え
  - 弧状コントローラ幅を iPhone 相当 (max 480) に制限して中央寄せ
    （iPad で弧が浅くなりボタンが沿わない問題の解消）
  - 下部操作パネルも maxWidth 480 中央寄せ。
    `MediaQuery.size.width / 2` を `LayoutBuilder` の `constraints.maxWidth / 2` に
  - 削除ボタンとロックボタンの隙間を 54 → 72 に
  - 弧ラインを画面端まで延長（`_ArcDividerPainter` に `arcWidth` 引数追加、
    Positioned を Stack 境界外に出して clipBehavior: Clip.none を活用）
- `_primaryButton` (開始 / 次のセット) を固定幅 240 + 中央寄せ

## 次のアクション候補（優先度順）

### 優先度高（残課題）
1. **ToDo 画面の iPad 対応** — 縦画面/横画面でレイアウト方針を決める
2. **ToDo 画面に検索窓追加**（メモ側と同等）
3. **iPhone 実機で ⌘1-9 動作確認**（シミュでは Window メニューが横取り）
4. **iPad 実機で全体動作確認**（ケーブル接続後）

### 優先度中
- **ToDo 複数リスト結合機能**
- **フッターボタンの並びと間隔調整**（閲覧時/編集時とも）
- **iPhone 横画面無効の挙動確認**（Info.plist は設定済みだが念のため）

### 優先度低（Phase 8 完了時）
- `Info.plist UIRequiresFullScreen=true` を外す（マルチタスキング復活）

## 技術メモ

### iPhone 実機ビルド (Mac 移動後)
- USB 接続でも iproxy が SIP で拒否される → debug モードでクラッシュ
- **`flutter run --release -d 00008130-0006252E2E40001C` を使う**
- ビルド時間: 初回 Xcode build ~40s、2回目以降 数秒〜10秒

### iPad シミュ
- iPad Pro 13-inch (M5) `C6A8AF6B-C3E8-4B93-BCCC-E8C398D4491F` で動作確認
- iOS 26.3 シミュは初回 `flutter clean + pod install` が必要なケースあり
  （objective_c framework ロード失敗時）

### コード構造の注意
- `home_screen.dart` は 6300 行超
- `quick_sort_screen.dart` は 4400 行超（_QuickSortScreen 本体 + Card + Painter 群）
- `MemoInputArea` (`memo_input_area.dart`) は 2970 行
- 弧の幅制限パターン: `final sw = screenW > 480 ? 480.0 : screenW;` + Center
- ボタン中央寄せパターン: `Center(child: SizedBox(width: 220-240, ...))`
- max-width 制限パターン: `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 480-620), child: ...))`
