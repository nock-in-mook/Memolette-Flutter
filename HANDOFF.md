# 引き継ぎメモ

## 現在の状況

- **セッション#36 完了**（2026-05-02、5コミット）
- ブランチ: **`main`**
- ROADMAP 備忘から ToDo 結合機能と爆速モードのキーボード周りを進めた
- シミュ確認のみ。実機検証は前セッションから引き続き積み残し

## #36 のサマリ（時系列）

### ToDo項目の日付バッジを行右上オーバーレイ表示
- 「タイトル下の独立行」を廃止し、Stack で行右上に Positioned 配置
- 行高さは維持(44pt)。タイトル位置・ボタン位置に影響なし
- カレンダーアイコン削除、フォント10pt + grey.shade500 で控えめに
- シェブロン右端と揃え (right: 6, top: -2)

### 5階層 ToDo 結合 → 6階層目の挙動対応
- depth 5 用の背景色・アクセント色（ピンク `#FF2D55`）を追加
- 結合済みリストのみ depth 5 まで子追加可（`_isMergedList` 判定）
- 通常リストは従来通り depth 4 (5階層) まで
- 結合元が 6階層持っていたら結合をトーストで阻止
  - エラーメッセージ「結合できるのは5階層までのリストです」
- 開発用ダミー: 5階層 ToDo + 結合相手の seed ボタン追加

### 爆速モードのキーボード押し上げ
- `resizeToAvoidBottomInset: false` のまま、`topSpacer` をキーボード高さ分縮める
- カードがヘッダー直下まで上にスライド、操作パネルはキーボード裏に隠れる前提
- (副作用なし、シンプル実装)

### 試した上で却下
- 爆速モードに MD ツールバーを追加 → ユーザー判断で不要、ロールバック
- ツールバー全体共通化案 → スコープを「消しゴム・画像追加・Undo/Redo」に限定する方針に

### ROADMAP整理
- 完了済み備忘削除 (爆速遷移アニメ短縮、NewTagSheetオリジナル風改修、5階層ToDo結合6階層目挙動確認、日付シート内カードの背景色反映、ToDoリスト内項目の日付表示縦に広げない方法)
- 「爆速モードのキーボードツールバー」を「BlockEditor化と合わせた具体内容」に書き直し
- メモカードの画像サムネイル右端固定の備忘追加

## 次のアクション（次セッション #37）

### 爆速モードのカード本文 BlockEditor 化（最優先）
- 現状: `_QuickSortCard` の本文は `TextField`、画像入りメモを開くと U+FFFC が空白として残るだけ
- 目標: BlockEditor に置換して画像インライン表示・画像追加に対応
- 同時に ツールバー（消しゴム・画像追加・Undo/Redo・完了）をキーボード上に Overlay 表示

#### 実装方針メモ
- `_QuickSortCardState` の `_contentController` を BlockEditor のミラーとして残す
- BlockEditor.onContentChanged で `_contentController.text = newContent` + `_saveContent()`
- `_contentFocus` は廃止 → `_blockEditorKey.currentState?.hasAnyFocus` 等で判定
- Undo/Redo は外側で text snapshot ベース (TextEditingValue を保存)。memo_input_area の `_undoStack` 実装 (line 196〜288) が参考
- 画像追加は `_blockEditorKey.currentState?.insertImageFromPicker(source!)` 経由（memo_input_area の `_attachImage` line 716 参考）
- ツールバー widget は `lib/widgets/memo_edit_toolbar.dart` 新規作成。引数で callback / state を受け取るシンプル設計
- TextField scrollPadding は 44pt(ツールバー高さ) を加算
- 必要なら memo_input_area 側のツールバーもこの widget に置換（A 案完全共通化）

#### `BlockEditor` 公開 API（block_editor.dart 確認済み）
- `currentContent` getter
- `hasAnyFocus` getter (緩い判定)
- `hasActivePrimaryFocus` getter (厳密判定)
- `focusedController` getter (フォーカス中 TextBlock の controller)
- `insertImageFromPicker(ImageSource)`
- `focusFirst()`, `focusLast()`, `focusAtSourceOffset(int)`
- `wrapFocusedSelection(String wrapper)`
- `currentSourceOffset` getter

#### `BlockEditor` コンストラクタ
```dart
BlockEditor(
  key: _blockEditorKey,
  memoIdResolver: () => widget.memo.id,
  initialContent: widget.memo.content,
  onContentChanged: (s) { _contentController.text = s; _saveContent(); },
  isMarkdown: widget.memo.isMarkdown,
  readOnly: false,
  scrollPaddingBottom: cursorBottomBuffer.toDouble(),
)
```

### 残タスク（ROADMAP「備忘」より）
- ToDo の複数リスト結合機能（実装済みかも要確認）
- 爆速整理モードと ToDo の iPad 対応
- メモ入力エリア枠外右下の eventDate 表示を機種ごとに確認
- 選択モード関連の iPad 対応チェック
- アプリ全体の iOS 風 UI 要素を Memolette オリジナル風に置き換え
- iPad 縦↔横回転時の編集状態維持
- iPad スプリット時の右側メモ編集画面: 上余白 + 左上閉じるボタン
- メモカードの画像サムネイルを右端固定に

### 実機検証の積み残し
- 13 mini シミュは起動したまま（pipe: `/tmp/flutter_pipe_13`）
- 15 Pro Max / iPad は wireless 接続が前回不安定で実機未確認
- #36 の修正全部シミュのみ確認

## 技術メモ

### 階層制限の実装パターン (todo_list_screen.dart)
- `const int _maxDepth = 5;` は色配列インデックスの上限
- `_normalMaxDepth = 4` / `_mergedMaxDepth = 5` で階層制限を分離
- State で `bool _isMergedList = false; StreamSubscription<TodoList?>? _listSub;` を保持
- `initState` で `_listSub = _watchList().listen((list) { ... })` で更新
- `int get _effectiveMaxDepth => _isMergedList ? _mergedMaxDepth : _normalMaxDepth;`
- `dispose` で `_listSub?.cancel();`

### Stack オーバーレイで行高さ維持
- `clipBehavior: Clip.none` の Stack なら、Positioned のはみ出しを許容
- 例: ToDo 項目の日付バッジ右上配置 (`bottom: 0` から `top: -2` 等)

### 結合元の最大階層計算（todo_lists_screen.dart）
```dart
final items = await (db.select(db.todoItems)
      ..where((t) => t.listId.equals(id)))
    .get();
final byId = {for (final i in items) i.id: i};
var maxDepth = 0;
for (final item in items) {
  var d = 0;
  var pid = item.parentId;
  while (pid != null) { d++; pid = byId[pid]?.parentId; }
  if (d > maxDepth) maxDepth = d;
}
if (maxDepth >= 5) { showToast(...); return; }
```

### シミュ / 実機 ID
- iPhone SE 3rd iOS26: `47003836-6426-4AB1-90FC-C5E73DA251C1`
- iPhone 13 mini iOS26: `B5B2C694-8EAB-4C14-AA4D-8BCE464CE49D`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`
- iPad（のっくりのiPad、wireless）: `00008103-000470C63E04C01E`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`

### Mac で `py` コマンドはない
- グローバル CLAUDE.md の Python 実行ルールは Windows 用。Mac では `python3` で代用

## 関連メモ（自動メモリ）

- `feedback_dialog_style.md`: AskUserQuestion の選択肢形式は使わず自然な対話
- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウトは新機能で動かさない
- `build_workaround.md`: Google Drive 上では codesign エラー → `/tmp/memolette-run` 経由
