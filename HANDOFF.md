# 引き継ぎメモ

## 現在の状況

- **セッション#33 完了**（2026-04-30 〜 05-01、長め）
- ブランチ: **`main`**
- 今回はバグ修正中心。タグシート関連の見た目統一 + iOS 風要素オリジナル化 + 重大バグ4件の修正

## #33 のサマリ

### NewTagSheet のデザイン統一
- 配置（左キャンセル/中央タイトル/右確定、シート高さ85%）は維持しつつ、色・フォント・太さ・背景を `DialogStyles` に統一
- 背景: すりガラス（blur+alpha 0.65）→ 白ベース（上部角丸＋影）
- フォント: Hiragino Sans 統一
- 太さ: タイトル w600→w700、キャンセル w400→w600
- グレー濃度: shade600 → `DialogStyles.textGrey`
- 青: 直書き #007AFF → `DialogStyles.defaultAction`

### 親タグ削除の CupertinoActionSheet → Memolette オリジナル化
- `home_screen.dart:3968` の `showCupertinoModalPopup` + `CupertinoActionSheet` を撤去
- 新規 `lib/widgets/tag_delete_choice_dialog.dart` を作成（`showTagDeleteChoiceDialog`）
- 中央ダイアログ + 白背景 + 縦並びボタン、destructive(赤) / default(青) / キャンセル(グレー)

### KeyboardDoneBar 二重表示の解消
- `main.dart` の MaterialApp.builder で全画面に既に掛かっているのに、各画面とシートで再度包んでいた
- シート内では Stack 位置計算がズレて「完了」ボタンが画面上部に2個目が出ていた
- 削除: `home_screen.dart` / `todo_lists_screen.dart` / `quick_sort_screen.dart` / `new_tag_sheet.dart`

### 重大バグ修正

#### A. 新規メモが保存されないバグ（`onMemoCreated` の早期 return）
- 原因: 920c0bd で追加された `if (!_isInputExpanded && !_isEditingCompact) return;` が、`_focusInputTrigger++` 直後の「フォーカス・キーボード立ち上がりかけ」も弾いていた
- `_isEditingCompact` は「フォーカス入力中＋キーボード表示中」が条件 → `_preCreateEmptyMemo` 完了時にまだ満たしていない
- 修正: `_pendingNewMemoCreation` フラグ追加、`onClosed` で必ずリセット → 立ち上がりかけだけ通し、戻り矢印で抜けた後の遅延コールバックは元のガードが効く（920c0bd の最大化ループ防止と両立）

#### B. ルーレット親タグの内側端が子タグ判定に吸われる
- 原因: `borderX = cx - parentInnerR` の **垂直線**で親/子を分けていた。視覚的境界は半径 `parentInnerR` の **円弧**なので、上下に傾いたセクター（中心軸から離れたもの）の内側端が borderX より右側に来て子判定されていた
- 修正: タップ/ドラッグ開始位置の中心からの距離（半径）で判定 → `dr < parentInnerR` なら子、それ以上なら親

#### C. タグ残存バグ（async レース）
- 症状: 親タグルーレットを切り替えてもバッジ表示と子タグルーレットが古いまま固着
- ログで確認: `editingMemoId=null` なのに `_attachedTags=[長文テスト]` が残存
- 原因: `_loadMemo` / `loadMemoDirectly` の async タグ取得が、await 中にユーザーが新規作成等で別メモへ遷移した後に完了し、古いメモのタグで `_attachedTags` を上書きしていた
- 修正: await 完了時に `widget.editingMemoId` が変化していないかガード

#### D. タグ残存バグ（pending 残留）
- 症状: タグだけ指定して本文未入力の状態で新規作成ボタンを押すと pending タグが残る
- 原因: `editingMemoId` が null → null（変化なし）になるため `didUpdateWidget` の `_clearInput` が呼ばれない
- 修正: `focusRequest` 変化＋両方 null の場合に明示的に `_clearInput` を実行

### ルーレット開時のフォーカス排他
- ルーレットが開いた状態で入力欄に文字を打てると状態が壊れる原因になっていた
- 入力フォーカスとルーレット表示は排他にする
- `memo_input_area`: タイトル/本文にフォーカスが入った瞬間に `_onFocusChange` で `_closeRoulette()`
- `home_screen`: 検索欄フォーカス時の listener で `_inputAreaKey.currentState?.closeRoulette()`

### グローバル CLAUDE.md に「★ 回帰バグ防止ルール」追記
- 「こっちを立てたらあっちが死んだ」型の回帰バグ（920c0bd の早期 return が新規作成を阻害したパターン）を防ぐためのルール
- ガード追加・変更前: ① 通すべき正常ケースの列挙 / ② コールバック呼び出し元の grep / ③ 既存ガードは `git blame` で意図確認

### ROADMAP 追記
- メモカードのテキスト行数最適化: グリッド3×4(mini)/3×2(SE)で本文をもう1行多く表示できそう

## 次のアクション（次セッション #34）

### 残タスク
- **アプリ全体の iOS 風要素の追加洗い出し**（CupertinoActionSheet は #33 で潰した。残: フィルタプルダウン / 背景色ピッカー の `DialogStyles` 統一など）
- **BgColorPickerDialog の DialogStyles 統一**（メモ・ToDoリスト背景色ダイアログ。直書きで `DialogStyles` 未使用）
- **ダイアログ巡回の続き**: C 選択肢メニュー / E ピッカー / F バナー
- 実機 / iPad での Phase 15 Step 9 + Phase 16 動作確認
- Phase 14: アクセシビリティ文字サイズ対応（リリース前タスク）

### 短期備忘
- メモカードのテキスト行数最適化（ROADMAP アイデアメモ）

## 技術メモ

### 回帰防止ルール（グローバル CLAUDE.md より）
ガード（early return / 条件分岐）を追加・変更する前に：
1. 通すべき正常ケースを箇条書きで列挙し、新条件下でそれぞれ通過することを確認
2. そのコールバック / 関数の呼び出し元を grep で全部洗う（async コールバックは複数経路から呼ばれがち）
3. 既存ガードを削除・緩和する前に `git blame` で過去の意図確認

### hot reload と addListener
`addListener` は initState で1回しか呼ばれない。**hot reload では新しいリスナー登録が反映されない**。検証時は **hot restart** が必要（`echo R > /tmp/flutter_pipe`）。

### 二系統 FIFO（SE + mini 並列起動）
```bash
# SE 3rd
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe' > /dev/null 2>&1 &
# mini
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe_13' > /dev/null 2>&1 &
# 別 /tmp/memolette-run-13mini に rsync して並列 flutter run
```

### flutter logs でデバッグ
```bash
flutter logs -d 47003836-6426-4AB1-90FC-C5E73DA251C1 > /tmp/se_logs.txt 2>&1 &
```
debugPrint がリアルタイムで /tmp/se_logs.txt に書かれる。`grep "[Tag" /tmp/se_logs.txt` でフィルタ。

### シミュ / 実機 ID
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`
- iPhone SE 3rd iOS26: `47003836-6426-4AB1-90FC-C5E73DA251C1`
- iPhone 13 mini iOS26: `B5B2C694-8EAB-4C14-AA4D-8BCE464CE49D`

## 関連メモ（自動メモリ）

- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウトは新機能で動かさない、オーバーレイで実装
- `build_workaround.md`: Google Drive 上では codesign エラー → `/tmp/memolette-run` 経由
