# 引き継ぎメモ

## 現在の状況

- **セッション#31 完了**（2026-04-29、半日）
- ブランチ: **`main`**
- ToDo 関連の細部修正 4 本立て完了。Phase 15 Step 8 までの主要部分は引き続き安定
- 動作確認: iPhone 17 Pro シミュ（debug、FIFO 経由ホットリロード）。実機 / iPad は未確認

## #31 のサマリ: ToDo 細部修正 4 本立て

### ToDo 編集画面のインデント問題 + 保存後のチラつき解消（todo_list_screen.dart）
- `_EditingItemField` の `contentPadding: horizontal: 10` → `EdgeInsets.zero`（編集中だけ右にずれる問題）
- 保存直後の「（空のアイテム）」一瞬表示を楽観的更新で吸収（`_optimisticTitles: Map<String, String>`）
  - `_commitEditWithText` で書き込み完了後にエントリ追加、Text 表示部の Builder 内で DB が追いついたらクリア

### TODO フォルダに選択削除モード追加（todo_lists_screen.dart）
- 緑エリア左下に円形フロート削除ボタン（メモ一覧フッターのゴミ箱と同じスタイル）
- 選択削除モード時のヘッダー: [キャンセル] / N件 選択中 / [削除]（ボタンに件数なし、中央テキストに件数）
- TODO タブ中央付近に 1 行ポップアップ「削除するToDoを選択してください」
  - Stack `clipBehavior: Clip.none` で 40pt 外にはみ出し配置、`Positioned(top: 5)`
- カードタップで選択トグル、未選択カード半透明、選択中カードに赤チェックバッジ
- 確認ダイアログ: 「選択したToDoを削除」/「N件のToDoを削除します。よろしいですか？」（件数1回）
- メモ混在フォルダ側も同形式に統一（home_screen の `_confirmDeleteSelected`）

### メモ・ToDoカードに背景色追加（DB Migration v6）
- `TodoLists.bgColorIndex` (int, default 0) を追加（`setTodoListBgColor` も新設）
- `_BgColorPickerDialog` を `lib/widgets/bg_color_picker_dialog.dart` に切り出して `BgColorPickerDialog` として public 化
- メモ長押し（`_showMemoActions`）/ ToDo 長押し（`_showTodoActions` / `_showListActions`）に「背景色」項目追加
- `TodoCard` と `todo_lists_screen` カード描画で `bgColorIndex` 反映
- ToDoカードはチェックボックス可読性のため、メモカードよりさらに白に40%寄せて薄める

### 項目全件削除の確認を1回に統合（todo_list_screen.dart）
- `_showClearAllConfirm` を削除、`_showClearAllDialog` の「全て削除する」から直接 `_clearAllItems`
- 件数と注意書きは1回目で表示済み、2回目「本当によろしいですか？」は冗長

### ROADMAP 追記
- 備忘: メモ選択削除のUI崩壊修正 / フォルダ最大時の選択モードUI最適化 / Phase 8（iPad）チェック項目化
- Phase 14: アクセシビリティ「文字サイズ拡大」影響箇所の全洗い出し（重点箇所と方針付き）

## 次のアクション（次セッション #32）

### 残課題
- 実機 / iPad での今回変更の動作確認
- ROADMAP 備忘:
  - メモ選択削除のUI崩壊修正
  - フォルダ最大時の選択モードUI最適化
- Phase 15 Step 9: メモカードに eventDate バッジ表示
- Undo/Redo スナップショットへの eventDate 統合
- Phase 14: アクセシビリティ文字サイズ対応（リリース前タスク）
- iPad 横画面 (embedded mode) での Phase 15 動作確認
- `FOCUS_REGRESSION_CHECKLIST.md` の全項目チェック

## 技術メモ

### shimu / 実機 ID
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`

### 開発フロー（FIFO 経由ホットリロード、デバッグビルド）
このセッションで確立した。debug ビルド + FIFO で素早い反復が可能。

```bash
# 初回セットアップ（FIFO + writer keeper を起動）
[ -p /tmp/flutter_pipe ] || mkfifo /tmp/flutter_pipe
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe' > /dev/null 2>&1 &
disown

# flutter run 起動（FIFO を stdin に）
cd /tmp/memolette-run && \
  nohup sh -c 'flutter run -d ACE500F3-AA23-44EC-AB93-C4EA636FC3BC < /tmp/flutter_pipe' \
  > /tmp/memolette-run/flutter_run.log 2>&1 &

# コード編集後の反映フロー
# 1. 本体側で編集
# 2. rsync で /tmp/memolette-run/lib/ に同期
rsync -a --delete \
  --exclude=build/ --exclude=.dart_tool/ --exclude=ios/Pods/ --exclude=ios/.symlinks/ \
  --exclude=ios/Flutter/ephemeral/ --exclude=ios/Runner.xcworkspace/xcuserdata/ \
  lib/ /tmp/memolette-run/lib/
# 3. ホットリロード送信
echo "r" > /tmp/flutter_pipe
# 必要なら R でホットリスタート（DBスキーマ変更後など）
```

### DB Migration v6
- `TodoLists.bgColorIndex` (int, default 0) を追加
- 起動時 `onUpgrade` で `m.addColumn(todoLists, todoLists.bgColorIndex)`
- `database.dart` の手動 TodoList コンストラクト箇所 3 つに `bgColorIndex: row.read<int>('bg_color_index')` を追加（ついでに不足していた `eventDate` も追加）

### 楽観的更新パターン
DB ストリームのラグを埋めるための定型。
```dart
// State
final Map<String, String> _optimisticTitles = {};

// 書き込み完了後
setState(() {
  _editingItemId = null;
  _optimisticTitles[id] = trimmed;
});

// 表示部 Builder 内
final optimistic = _optimisticTitles[item.id];
if (optimistic != null && item.title == optimistic) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() => _optimisticTitles.remove(item.id));
  });
}
final displayTitle = optimistic ?? item.title;
```

### Stack の Positioned + Clip.none
TODO タブの 40pt 領域より下に少しはみ出して配置するためのパターン:
```dart
SizedBox(
  height: 40,
  child: Stack(
    clipBehavior: Clip.none,  // ←必須
    children: [
      Positioned.fill(child: ...),  // 元のコンテンツ
      if (showBanner)
        Positioned(top: 5, left: 0, right: 0, child: Center(child: banner)),
    ],
  ),
);
```

## 関連メモ（自動メモリ）

- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウト（白カードサイズ等）は新機能で動かさない、オーバーレイで実装
- `build_workaround.md`: Google Drive 上では codesign エラーで `flutter build ios` が失敗 → `/tmp/memolette-run` 経由
