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

wireless 接続だと iPhone がスリープするたびに `Installing and launching` が
「Could not run」で失敗する → iPhone を起こしてから再試行。

---

## ★ Apple Developer Program 承認済み

2026-04-22 に Apple Developer Program 登録完了報告あり。TestFlight 配信 /
App Store 審査提出が可能な状態。

Flutter 側 `ios/Runner.xcodeproj` の Team 設定は個人 Team のまま
（CF34X3P59Y）。必要に応じて法人/個人 Developer Team へ切り替え。

関連資料: `/Users/nock_re/Library/CloudStorage/GoogleDrive-yagukyou@gmail.com/マイドライブ/_Apps2026/APP_RELEASE_GUIDE.md`

---

## 現在の状況

- セッション#24 完了（2026-04-23）
- ブランチ: `main`
- 最終コミット: `79cee4f` 入力欄フッター整備 + ダイアログ挙動修正
- iPhone 15 Pro Max 実機（release, wireless）で動作確認済

## #24 で完了したこと

### 入力欄フッター整備（閲覧/編集とも）
- 閲覧/編集モード問わず**閉じる/拡大ボタンを常に右寄せ**に統一
  （コピーの後に `Spacer()` 追加、編集時は従来のSpacerのまま）
- 閲覧モードのアイコン列を **+6px 右にシフト**
  - `SizedBox(width: isTablet ? sp(12) : 18)` に変更
  - 多機能/パレット/コピーを等間隔（12px, iPad は 18px）に
- プレビュー表示時の**拡大ボタン押し出し対策**
  - 閉じる↔拡大を 16 → 11 に詰める
  - ツールバー右padding を 10 → 5 に詰める
- 消しゴムは**編集モードのみ表示**に戻す（常時グレー案は却下）
- 画像↔Undo は Undo↔Redo より少し広く（iPhone 30, iPad 40）して
  画像ボタンに独立感

### MDトグル トースト位置調整
- `showToast` に `bottomY` パラメータを追加（絶対 Y 座標でトースト下端を指定）
- `_toolbarKey` をツールバーに付けて、フッター上端の 5px 上にトースト下端を合わせる
- 親指に隠れないよう、入力欄内（本文表示領域）に出すイメージ

### ダイアログ挙動修正（本文クリア・メモ削除）
- **viewInsets を 0 に上書き** → キーボードが閉じるアニメーションに
  引きずられて「上から降ってくる」挙動を解消
- **focusSafe を外す** → Navigator の自動フォーカス復元で、キャンセル後に
  元の編集カーソル位置 (＋キーボード) へ復帰
- **`_isDialogOpen` フラグ**を追加してダイアログ中のフッター切替を抑制
  - `_buildToolbar` の `isEditing` 判定と、閉じる表示条件の両方で考慮
  - `clearBody` と `_confirmDeleteMemo` の両方で設定

### iPhone 実機動作
- wireless 接続で `flutter run --release` が通ることを確認
- 初回 Xcode build ~35s、増分 ~18s、インストール 2〜3s

## 次のアクション（次セッション）

### 優先度高（次セッションで本格対応）
1. **ToDo 画面の iPad 対応** ← 次セッションのメイン
   - 縦画面/横画面でレイアウト方針を決める
   - `todo_lists_screen.dart` / `todo_list_screen.dart` 全面調整

### 優先度中
- **ToDo 画面に検索窓追加**（メモ側と同等）
- **ToDo 複数リスト結合機能**
- **iPhone 横画面無効の挙動確認**（Info.plist は設定済み）
- **iPhone 実機で ⌘1-9 動作確認**（シミュでは Window メニューが横取り）
- **iPad 実機で全体動作確認**（ケーブル接続後）

### 優先度低
- **TestFlight 内部配布セットアップ**（Apple Developer 登録済みの活用）
- `Info.plist UIRequiresFullScreen=true` を外す（マルチタスキング復活）

## 技術メモ

### iPhone 実機ビルド (Mac, wireless)
- `flutter run --release -d 00008130-0006252E2E40001C`
- iPhone スリープ中はインストール失敗するので、再試行時は画面を起こす
- Google Drive 上で直接ビルドは codesign エラー → `/tmp/memolette-run` に
  rsync してからビルド

### iPad シミュ
- iPad Pro 13-inch (M5) `C6A8AF6B-C3E8-4B93-BCCC-E8C398D4491F` で動作確認
- iOS 26.3 シミュは初回 `flutter clean + pod install` が必要なケースあり

### コード構造の注意
- `home_screen.dart` は 6300 行超
- `quick_sort_screen.dart` は 4400 行超（_QuickSortScreen 本体 + Card + Painter 群）
- `MemoInputArea` (`memo_input_area.dart`) は 3000 行超（#24 で +91 行）
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
