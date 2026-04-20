# 引き継ぎメモ

## ★ 後で動作確認するタスク（セッション#22で実装済・未検証）

### Mac キーボードをシミュに繋いで（I/O → Keyboard → Connect Hardware Keyboard）確認
- [ ] `⌘N` 新規メモ作成
- [ ] `⌘F` 検索バーにフォーカス
- [ ] `⌘1` 〜 `⌘9` タブ切替（`_tabOrder[i]` の index 番目）
- [ ] `⌘Return` 入力確定（フォーカス解除）
- [ ] `Esc` フォーカス解除
- [ ] `⌘Z` Undo（`_inputAreaKey.currentState?.triggerUndo()` 経由）
- [ ] `⇧⌘Z` Redo

### iPhone 実機 / iPhone シミュで確認（#22 の変更は iPad シミュ中心）
- [ ] iPhone のツールバー配置が均等（iPad 以外）に戻ってる
- [ ] iPad 縦画面（特に iPad Pro 13: 1024×1366）でスプリットが誤発動しない — `isWide = width >= 840 && width > height` で対策済
- [ ] iPhone 実機に新ビルドを入れ直す

### Step C 後半 実装（次セッション以降）
- [ ] `⌘B` 太字（MDモード時のみ、focused TextEditingController に `**` ラップ）
- [ ] `⌘I` 斜体（同じく `*` ラップ）
- [ ] MemoInputArea に `triggerInsertMd(String wrapper)` 的な public メソッド追加が必要
- [ ] `MarkdownToolbar._wrapSelection` のロジックを State 側に移植 or 流用

### Phase 8 完了時に外すこと
- [ ] **Info.plist `UIRequiresFullScreen`** — iPad マルチタスキング（Split View / Slide Over / Stage Manager）を復活させる。開発用にシミュ回転を効かせるために一時的に true にしている

---

## 現在の状況
- セッション#22 完了（2026-04-21）
- ブランチ: `main`
- 最終コミット: `e8067b7` Phase 8 Step B (iPad スプリットビュー) + Step C 前半 + 細部調整
- iPad Pro 13 シミュ + iPad 実機（#21）で動作確認済み

## #22 で完了したこと

### Phase 8 Step B: iPad 横画面スプリットビュー
- `_buildMainContent` を `isWide` 分岐で `Row` (左:一覧 / 右:入力) に組み替え
- 検索バー / 入力エリア / 機能バー / タブ / フォルダ本体を private メソッドへ抽出
- 横画面では 最大化/縮小・シェブロン非表示、機能バー常時表示、下端余白、キーボード上ツールバー有効
- 縦横共通の構造を `_buildNarrowLayout` / `_buildWideLayout` に分離

### 横画面用グリッド
- `enum GridSizeOption` に `iPadWideColumns` / `iPadWideRows` を追加
- ラベルとメニュー選択肢を横画面用に（`5×6` / `4×5` / `3×4` / `2×3` / `1×可変` / `タイトルのみ`）
- iPad カードの本文表示行数を緩和（`_bodyLinesFor(context)` で動的化、LayoutBuilder 実寸で計算）
- `Responsive.isWide` に `width > height` 条件を追加（iPad Pro 13 縦画面で誤発動しない）

### Step C 前半: ⌘ショートカット 7種
- `⌘N` / `⌘F` / `⌘1-9` / `⌘Return` / `Esc` / `⌘Z` / `⇧⌘Z`
- `MemoInputArea` に `triggerUndo` / `triggerRedo` 公開
- `build` を `CallbackShortcuts + Focus` でラップ

### フッター・レイアウト微調整
- iPad のみ左グループ (ゴミ箱/MD/プレビュー) と右グループを Spacer で分離
- アイコン間隔 1.5 倍、Undo/Redo と最大化ボタンの左右余白強化
- 「閉じる」とコピー/最大化の距離を対称に
- iPhone は元の配置を維持

### 状態不整合の修正
- 枠外タップの unfocus 条件を `isInputFocused` 単独に（フローティングキーボード時も抜ける）
- 入力エリア以外の各セクションを `_wrapUnfocusOnTap` (`Listener(PointerDown)`) で包み、どこタップでも一律 unfocus
- Wide/Narrow 共通のヘルパで実装

### 選択モードバー
- 横画面で **幅 70% 中央寄せ** + 画面上端〜タブ上端の中央に配置（`viewPadding.top + 検索バー高さ + 機能バー高さ` で計算）
- 縦画面は従来どおり

### iPad シミュ回転対応
- `Info.plist` に `UIRequiresFullScreen=true` を追加（Flutter iPad シミュの既知バグ回避）
- 副作用として Split View / Slide Over / Stage Manager が無効化 → Phase 8 完了後に外す

## 次のアクション候補

### 優先度高
1. **動作確認**（Mac キーボード経由で⌘ショートカット / iPhone 実機 / iPad 縦画面 Pro 13）
2. **Step C 後半**: ⌘B / ⌘I（太字・斜体、MD モード時）
3. **Step C 他要素**: D&D、右クリック/長押しメニュー、サイドバー常時表示

### 優先度中
- Phase 8 完了時: `UIRequiresFullScreen` を外す、iPad 実機で最終動作確認
- Phase 9: Firebase / iCloud 同期

## 技術メモ

### ビルド関連
- ビルド回避策: `/tmp/memolette-run` に rsync してから build（Google Drive で codesign エラー回避）
- シミュで native library 問題 (`objective_c.framework` ロード失敗) が出たら `flutter clean + pod install` で解決
- シミュの回転は `UIRequiresFullScreen=true` で追従（Flutter の iPad シミュ既知バグ対応）

### 実機デプロイ
- iPad 実機 ID: `00008103-000470C63E04C01E`（のっくりのiPad, iOS 26.2.1）
- iPhone 実機 ID: `00008130-0006252E2E40001C`（15promax, iOS 26.3.1）
- ワイヤレスだと Dart VM 繋がりにくい（Installing は成功、ホットリロード不可）→ USB 接続推奨

### シミュレータ
- iPhone 15 Pro Max: `95C8A8C5-0972-4BB0-B793-5219096697DF` (iOS 17.2)
- iPad Pro 13-inch (M5): `CC1098F2-158C-48B5-A59A-0462BBEF0360` (iOS 26.3)

### コード構造の注意
- `home_screen.dart` は 6300行超
- Step B で `_buildMainContent` は `_buildNarrowLayout` / `_buildWideLayout` に分離
- Listener ラッパ `_wrapUnfocusOnTap` で入力エリア以外の一括 unfocus
- `MemoInputArea` (`memo_input_area.dart`) は 2970行、リファクタ対象候補
