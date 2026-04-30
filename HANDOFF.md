# 引き継ぎメモ

## 現在の状況

- **セッション#32 完了**（2026-04-29、長め）
- ブランチ: **`main`**（`feature/phase-16-responsive` をマージ済み）
- Phase 15 Step 9（カードバッジ）/ Phase 16（レスポンシブ）/ ダイアログ統一 まで完了
- 動作確認: SE 3rd シミュ + iPhone 13 mini シミュ（FIFO 二系統）

## #32 のサマリ

### Phase 15 Step 9: メモ・ToDo カードにバッジ表示
- メモカード: `eventDate`（橙）/ `containsMarkdown` ベースの MD（紫）/ Pin（青）/ Lock（赤）を Stack 右上にオーバーレイ
- `containsMarkdown(text)` を `lib/utils/markdown_detect.dart` に新設（Swift 版から regex 移植）
- ToDoカード（メモ一覧グリッド + ToDo一覧画面）にも同形式のバッジ追加
- `StackFit.expand` でセル全体を満たすよう調整、サムネイル比率の潰れも修正
- サムネイル更新時のチラつき → `ImageStorage.absolutePathSync` で同期取得し初フレームで決定

### Phase 16: レスポンシブ対応（SE 3rd / 13 mini / 標準）
- 機種別グリッドオプション: SE は 3×2/2×2、mini は 3×4/2×4、標準は 3×6/2×5
- `_phoneSizeClass` / `_gridRowsFor` / `_availableGridOptions` ヘルパーで分岐
- カレンダー初期スクロール: 今日が常にビューポート中央に来るよう `weekIndex` 基準で算出
- 爆速整理画面: 高さ 700px 未満で上部余白 70→30
- 爆速整理 最終カードの右下「完了」ボタン → 虹色三角形（`_TriangleNavButton.rainbow`）に変更。ロックボタンとの視覚的被り回避
- ToDo カードのセル高をメモカードと一致させる

### ダイアログデザイン共通化
- `lib/widgets/dialog_styles.dart` 新設。`title` / `message` / `actionLabel` / `bodyDecoration` / `accentButtonDecoration` / `textGrey` / `destructive` / `defaultAction` を一箇所に集約
- `confirm_delete_dialog.dart` と `frosted_alert_dialog.dart` を `DialogStyles` 参照にリファクタ
- 視認性向上: タイトル w600→w700 / 本文 w400→w500 / ボタン w500→w600、グレー alpha 0x99→0xCC
- メモ上限（旧 CupertinoAlertDialog）→ `showFrostedAlert` に統一
- 設定画面の全データ削除（旧 AlertDialog）→ `showConfirmDeleteDialog` に統一

### ToDo 編集画面の状態遷移修正（多数）
- アイテム編集中に他アイテム / タイトル / メモ をタップ → 自動コミットしてから次の操作へ
- `_committingIds: Set<String>` で per-id ガード（単一フラグだと Y commit が漏れる問題を解消）
- dispose 時の commit が次アイテムを上書きしないよう `if (_editingItemId == id)` ガード
- 「完了」 キーボードボタンで commit → `_focusNode.addListener(_handleFocusChange)` で focus loss 検知
- 親 GestureDetector の onTap が子のタップを奪う問題 → outer `Listener(onPointerDown:)` に変更
- onTapOutside は no-op（commit は dispose と focus listener に任せる）

### 選択モード見た目調整
- 「削除するメモを選択してください」バナー位置をフォルダタブより前面 + ノッチ回避位置に
- 選択削除ボタンのドロップシャドウ・不透明背景化（半透明だとシャドウが透けて灰色っぽく見える問題）
- ToDo 一覧の選択削除ラベル「削除」→「選択削除」、alpha 0.6→0.85

### タグ周り
- タブ z-index: 選択中=最前面、隣接=次、遠い=奥（`_ZOrderedRow._frontToBackOrder`）
- 親タグ追加直後にそのタブへ自動スクロール（リトライ付き）
- ルーレットの親タグ削除後リセット（`_syncToSelection` に `selectedParentId == null` 分岐追加）
- タグ表示の動的配分: TextPainter で自然幅を測り、短辺は自然 / 長辺に余白配分

### ROADMAP 追記
- フィルタボタンに「名前順」ソート（昇/降順トグル）
- **タグ追加シート（NewTagSheet）を Memolette オリジナル風に改修**（次セッション最有力タスク）
- アプリ全体の iOS 風 UI 要素を洗い出して脱却（Android リリース見据えて）

## 次のアクション（次セッション #33）

### 直近最優先
- **NewTagSheet のオリジナル風改修**
  - 現状: iOS ナビゲーションバー風（左キャンセル / 中央タイトル / 右確定 / 背景すりガラス）+ 入力欄が背景同化
  - 改修: 白背景 + ボタン縦並び（confirm_delete_dialog 系統）/ 入力欄も白背景 + 明確な枠線
  - ToDoリスト新規作成（_NewListDialog）はそのまま据え置き
- **アプリ全体の iOS 風要素の洗い出し**
  - showCupertinoModalPopup / CupertinoActionSheet / CupertinoDialogAction 系の使用箇所
  - Memolette オリジナル風に置き換え

### ダイアログ巡回の続き（途中）
カテゴリ別の確認・統一作業は途中で中断。次は：
- **C 選択肢・メニュー**: フィルタプルダウン / 背景色ピッカー / グリッドサイズ選択メニュー
- **D 入力シート**: NewTagSheet（上記タスクと統合）
- **E ピッカー**: showCustomDatePickerSheet / showCupertinoModalPopup
- **F バナー**: 選択モードバナー類

### 残課題（前セッションから継続）
- 実機 / iPad での Phase 15 Step 9 + Phase 16 動作確認
- Phase 14: アクセシビリティ文字サイズ対応（リリース前タスク、現状はアプリ固定方針）
- iPad 横画面 (embedded mode) での選択モード対応（Phase 8 で確認）
- `FOCUS_REGRESSION_CHECKLIST.md` の全項目チェック

## 技術メモ

### Phase 16 グリッド分岐
```dart
enum _PhoneSizeClass { se, mini, standard }
_PhoneSizeClass _phoneSizeClass(Size size) {
  if (size.width < 380 && size.height < 700) return _PhoneSizeClass.se;       // 375x667
  if (size.width < 380) return _PhoneSizeClass.mini;                          // 375x812
  return _PhoneSizeClass.standard;
}
```

### 二系統 FIFO（SE + mini 並列起動）
```bash
# SE 3rd
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe' > /dev/null 2>&1 &

# mini
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe_13' > /dev/null 2>&1 &

# 別 /tmp/memolette-run-13 に rsync して並列 flutter run
```

### DialogStyles の使い方
共通スタイルは `lib/widgets/dialog_styles.dart` 一箇所で管理。新規ダイアログは：
```dart
import '../widgets/dialog_styles.dart';
// タイトル
Text(title, style: DialogStyles.title)
// 本文
Text(message, style: DialogStyles.message)
// アクションボタン
Container(
  decoration: DialogStyles.accentButtonDecoration(DialogStyles.destructive),
  child: Text(label, style: DialogStyles.actionLabel.copyWith(color: DialogStyles.destructive)),
)
// ダイアログ全体
Container(decoration: DialogStyles.bodyDecoration, ...)
```

### shimu / 実機 ID
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`
- iPhone SE 3rd / iPhone 13 mini はセッション中に作成した iOS 26.3 ランタイムシミュ（次回再作成可）

## 関連メモ（自動メモリ）

- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウト（白カードサイズ等）は新機能で動かさない、オーバーレイで実装
- `build_workaround.md`: Google Drive 上では codesign エラーで `flutter build ios` が失敗 → `/tmp/memolette-run` 経由
