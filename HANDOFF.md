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

### iPhone 実機 / iPhone シミュで確認（セッション#22 の変更が iPad にしか入ってない）
- [ ] iPhone のツールバー配置が **均等（iPad 以外）に戻ってる** — iPad だけ右寄せになっているか
- [ ] iPad 縦画面（特に iPad Pro 13: 1024×1366）で **スプリットが誤発動しない** — `isWide = width >= 840 && width > height` に変更済

### Step C 後半 実装（次セッション以降）
- [ ] `⌘B` 太字（MDモード時のみ、focused TextEditingController に `**` ラップ）
- [ ] `⌘I` 斜体（同じく `*` ラップ）
- [ ] MemoInputArea に `triggerInsertMd(String wrapper)` 的な public メソッド追加が必要
- [ ] `MarkdownToolbar._wrapSelection` のロジックを State 側に移植 or 流用

### Phase 8 完了時に外すこと
- [ ] **Info.plist `UIRequiresFullScreen`** — iPad マルチタスキング（Split View / Slide Over / Stage Manager）を復活させる。開発用にシミュ回転を効かせるために一時的に true にしている

---

## 現在の状況
- セッション#21 完了
- ブランチ: `main`
- 最終コミット: `b6625cf` iPhone portrait-only + viewPadding クラッシュ対策
- iPad 実機（のっくりのiPad / iOS 26.2.1）で動作確認済み

## 今回（#21）完了したこと

### Phase 8 Step A: iPad レスポンシブ対応の土台

#### 新規モジュール
- `lib/utils/responsive.dart` — `Responsive.isTablet(context)` / `Responsive.isWide(context)` / `contentMaxWidth`
  - isTablet: shortestSide >= 600
  - isWide: width >= 840（Split View で狭くなる iPad も考慮）

#### enum GridSizeOption 拡張
- `iPadColumns` フィールド追加。iPad時は個別の列数を使う
  - grid3x6 → 6列、grid2x5 → 4列、grid2x3 → 4列、grid1x2 → 2列、grid1flex → 1列（維持）、titleOnly → 2列
- ラベル生成も `_gridLabelFor` で iPad時は iPadColumns 基準に（「6×6」「4×5」等）
- グリッドメニューの選択肢: iPad時は grid1x2 を除外（2×2が他と冗長なので）
- labelOverrides を iPad時も常時埋める（旧版では最大化時のみ）

#### レイアウト調整
- 入力欄の縦幅: iPad時は `constraints.maxHeight * 0.5 - 120`（画面半分弱）
- メモグリッド: iPad時は列数倍化（crossAxisCount = iPadColumns）
- titleOnly: iPad時のみ 2列 GridView に切り替え（iPhone は ListView 維持）
- サブフィルタ（すべて/よく見る/最近/タグなし）: `Center + ConstrainedBox(maxWidth: 600)` で中央寄せ

#### ツールバー右寄せ（memo_input_area.dart）
- `_buildToolbar` の Row 先頭に Spacer を追加、間の Spacer 2箇所を調整
- 左利き対応時は先頭 Spacer を末尾に移すだけでOK
- 編集/閲覧/compact の全モードで統一

#### iOS ネイティブ設定
- `AppDelegate.application(supportedInterfaceOrientationsFor:)` を `.all` で実装
  - iPadシミュレータで orientation change が追従しない問題の対応（実機では動作）
- Info.plist: iPhone 向け `UISupportedInterfaceOrientations` から landscape 2方向を削除 → **iPhone は portrait-only**
- iPad 向け `UISupportedInterfaceOrientations~ipad` は全方向維持

#### バグ修正
- `viewPadding.top - 4` が 4 未満になる環境で Padding アサーション失敗→クラッシュ
- `(viewPadding.top - 4).clamp(0.0, double.infinity)` で対処

### 実機検証
- Developer Mode + デバイス信頼 + ローカルネットワーク許可 すべて通った
- 実機 iPad 横画面で綺麗に表示、現状は縦用レイアウトが横に広がる形（Step B の出番）

## 次のアクション

### 次セッション最優先: Phase 8 Step B（iPad 横画面スプリットビュー）
**注意: 実装はかなり大規模なリファクタリング**

#### 現状の課題
- `_buildMainContent` の Column 内に5要素がインラインで 300行以上
- これを isWide 時に Row 配置へ切り替えるには変数抽出が必要
- 今回、変数抽出を途中まで試みたが、途中で revert（安全優先）

#### 推奨アプローチ
1. 5要素を private method に切り出す
   - `_buildSearchBarSection()`
   - `_buildInputAreaSection(constraints)`
   - `_buildFunctionBarSection()`
   - `_buildTabSection(parentTagsAsync)`
   - `_buildFolderBodySection(currentColor, parentTags, parentTagsAsync)` ← ここは Expanded を外して Container を返す
2. `_buildMainContent` で isWide 分岐
   - 縦画面: 従来の Column
   - 横画面: Row(左: タブ+検索+機能バー+フォルダ本体 / 右: 入力エリア)
3. 入力エリアの高さを isWide時は `constraints.maxHeight`（右カラム全域）に

### その後（Step C）
- ⌘キーショートカット（⌘N / ⌘F / ⌘Z / ⌘B/I / ⌘1-9）
- ドラッグ&ドロップ（他アプリから画像/テキスト）
- 右クリック / 長押しコンテキストメニュー
- サイドバー常時表示（親タグ一覧左固定）
- 並列編集モード（ROADMAP アイデアメモ）
- Apple Pencil Scribble 検証
- マルチウィンドウ（iPadOS Scene）

### 盲点 / 要検証
- iPad 横画面回転は実機では OK だが、シミュレータは**bugで追従しない**（iOS 17.2/26.3 両方確認）
- Floating キーボード時のツールバー位置（viewInsets.bottom = 0 問題）
- 外部 BT キーボード使用時はツールバー不要、⌘ショートカットで代替

## 技術メモ

### ビルド関連
- **ビルド回避策**: `/tmp/memolette-run` に rsync してから build（Google Drive で codesign エラー回避）
- **rsync のexclude**: `ios/Pods` と `ios/Podfile.lock` は除外すべき（Google Drive側の古い Pods でエラーになる）
- **flutter run 再起動時**: iOS 側の変更がなくても数秒〜数十秒の差分ビルドは走る
- **iOS バージョンが変わると pod install 必要**: 初回のみ

### 実機デプロイ
- **iPad 実機 ID**: `00008103-000470C63E04C01E`（のっくりのiPad, iOS 26.2.1）
- **iPhone 実機 ID**: `00008130-0006252E2E40001C`（15promax, iOS 26.3.1）
- **実機 flutter run**: 初回はDeveloper Mode + デバイス信頼 + ローカルネットワーク許可 が必要
- **Installing and launching が長い**: 初回は 60-80秒 かかる

### シミュレータ
- **iPhone 15 Pro Max**: `95C8A8C5-0972-4BB0-B793-5219096697DF` (iOS 17.2)
- **iPad Pro 13-inch (M5)**: `CC1098F2-158C-48B5-A59A-0462BBEF0360` (iOS 26.3)
- **iPad シミュは orientation change を追従しない既知の現象** — レイアウト確認のみシミュ、回転検証は実機で

### コード構造の注意
- `home_screen.dart` は 6100行超。`_buildMainContent` が巨大（300行以上）
- Step B 着手時は**まず現状把握→method抽出→Row/Column切替**の順で慎重に
- `MemoInputArea`（memo_input_area.dart）は 2960行、こちらもリファクタ対象候補
