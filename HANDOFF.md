# 引き継ぎメモ

## 現在の状況

- **セッション#35 完了**（2026-05-01〜2026-05-02、超長め・17コミット）
- ブランチ: **`main`**
- 今回は #34 の積み残し（既知バグ修正＋実機 release 検証）から始まり、
  ROADMAP 備忘の小〜中サイズタスクを次々潰していく流れ
- iPad 関連の修正が中盤以降多く、最終的に wireless 接続不安定で
  実機検証が一部未完。シミュでは全項目動作確認済み

## #35 のサマリ（時系列）

### 既知バグ修正
- ToDo項目入力中に「項目追加」ボタン → 入力中項目が一瞬「空のアイテム」に
  なる不具合修正。`_EditingItemField.onChanged` で常時 `_optimisticTitles`
  を更新する設計に変更（`_commitEditWithText` の wasEmpty 分岐に保険の remove も）

### 実機 release 検証（前回 #34 から持ち越し）
- 15 Pro Max + iPad 両方を release ビルドして Phase 15 Step 9 + Phase 16
  確認済み。**release では debug のカクカクが完全に消えて快適**

### eventDate 表示まわり大幅整理
1. 機能バー位置の eventDate がフォルダ最大化中などに画面最上部に居残る
   バグを `eventDateHidden` 条件追加で修正
2. iPad 横画面 / メモ最大化中は機能バー位置の表示が使えないので、
   `_buildInputAreaSection` の AnimatedContainer の下に eventDateFooter
   （高さ22px、Column 構造）を追加。タップで日付ピッカー起動

### 日付ピッカー
- 「決定」ボタンをオレンジ塗りつぶし+白文字に変更（薄背景+色文字から強調）

### ToDoリスト関連の整理
- 戻るボタンを「戻る」テキスト+白カード から `CupertinoIcons.back` 青色
  シェブロンに（メモ画面と統一）。pop 前に `purgeEmptyTodoLists` を await して
  「無題で項目0件のリスト」を確実に削除（dispose の fire-and-forget では
  一覧画面の rebuild に間に合わなかった）
- 新規作成ダイアログの「作成する」ボタンを常時押せるように。空タイトルでも
  作成OKに（カレンダー経由作成と挙動を統一）
- 個別画面タイトル placeholder を「無題のリスト」→「タイトル（任意）」、
  色を `Colors.grey 0.4` にしてメモ統一
- 起動時 cleanup に `purgeEmptyTodoLists` 追加（`home_screen.initState`）

### DayItemsPanel（カレンダーシート）大幅改修
- FAB を白背景+色アイコンから **accent.withValues(alpha: 0.55)** 塗りつぶし
  +白抜き「＋」（Container 2本を Stack で組む。Text/Icon だとフォント
  ベースラインで下にずれるため）。直径 33、太さ 3px
- セクション見出し（メモ/ToDo）の上余白を 14→7px に半減
- メモ・ToDoリスト・ToDoアイテムカードのフォントを +2 で視認性 up、
  ToDoリスト配下の項目を Padding(left: 12) でリスト名よりインデント
- 全カードに**左スワイプで削除**機能追加。確認ダイアログ付き、
  ToDoリストは配下アイテム+ taggings まで transaction 削除、ToDoアイテムは
  子孫を再帰削除。仕切り線を超えないよう ClipRect でラップ
- ダイアログ表示中も削除ボタンを保持（`_holdingForDialog` フラグ +
  `Listener.onPointerDown` で確実に flag 立て）
- iPad 横画面のカレンダー右カラムは横幅が狭いので **メモ上 / ToDo下** の
  縦積み表示（`DayItemsPanel.stacked` プロパティ追加）

### iPad 横画面の右カラム
- メモ編集中に左上「閉じる」テキストボタン追加（ToDoリスト一覧と統一）。
  右カラム上余白を 36px に確保
- 機能バー位置の eventDate を消して、白カード下端外側に新規 eventDateFooter

### フィルタメニュー
- `_TypeFilter` enum に `nameAsc`, `nameDesc` を追加（種別フィルタと排他選択
  で「名前順 ↑」「名前順 ↓」をフィルタ項目として並べる）
- `_GridItem` に `String get title` 追加。`_MemoGridView._mergeItems` で
  名前順ソート対応。`_MemoGridView` には `typeFilter` パラメータを追加して伝搬

### グリッドサイズ「タイトルのみ」表示バグ修正
- フィルタなし＋TODO 混在時に何も表示されないバグ。原因は ListView.separated
  の loose constraint 下で TodoCard の `Stack(fit: StackFit.expand)` が
  0 高さになって描画消失。各行を `SizedBox(height: 32)` で包んで tight
  制約を与える形で修正

## 次のアクション（次セッション #36）

### 残タスク（ROADMAP「備忘」より）
- ToDo の複数リスト結合機能（実装済みかも要確認）
- ToDo / 爆速モードを開くときの遷移アニメーション短縮
- 爆速整理モードと ToDo の iPad 対応
- 5階層 ToDo 結合 6階層目挙動確認
- 爆速メモ編集中のキーボードもツールバー付きに
- メモ入力エリア枠外右下の eventDate 表示を機種ごとに確認（直したばかりだが
  全機種で再確認）
- 選択モード関連の iPad 対応チェック
- NewTagSheet オリジナル風改修
- アプリ全体の iOS 風 UI 要素を Memolette オリジナル風に置き換え
- ToDoリスト内項目の日付表示縦に広げない方法
- iPad 縦↔横回転時の編集状態維持
- 日付シート内カードに背景色指定を反映

### 実機検証の積み残し
- iPad / 15 Pro Max wireless 接続が後半不安定で「unlock recovery」エラー
  連発。直近の修正（DayItemsPanel スワイプ削除、ToDo 戻るシェブロン、
  iPad 横画面の eventDate 移動など）は **シミュ確認のみ**で実機未確認
- 次回はワイヤード接続 or シミュレータ単体で進める想定

### アイデアメモ系（後回し）
- 子タグドロワー「都度収納/常時表示」設定
- アプリ内文字サイズ「ノーマル/大」2段階トグル

## 技術メモ

### Listener.onPointerDown 順序の罠
- 外側 Listener.onPointerUp が削除ボタンタップで発火 → Provider 増分 → 自分が
  close される問題は、 `GestureDetector.onTapDown` では順序が遅すぎて間に
  合わない（PointerUpEvent 後に発火）。**削除ボタンを内側 Listener で
  ラップして onPointerDown で flag 立てる**のが確実

### Stack.clipBehavior だけでは効かない場合
- Stack(clipBehavior: Clip.hardEdge) では中身の Transform.translate がはみ出す
  ことがある。確実にクリップしたい時は `ClipRect` で包む

### release ビルド再起動のコマンド
```bash
echo "q" > /tmp/flutter_pipe_15pm  # 既存停止
rsync -a --delete lib/ /tmp/memolette-run-15pm/lib/
# Bash run_in_background=true で:
cd /tmp/memolette-run-15pm && flutter run --release -d 00008130-0006252E2E40001C \
  < /tmp/flutter_pipe_15pm > /tmp/15pm_release_log.txt 2>&1
```

### シミュ / 実機 ID
- iPhone SE 3rd iOS26: `47003836-6426-4AB1-90FC-C5E73DA251C1`
- iPhone 13 mini iOS26: `B5B2C694-8EAB-4C14-AA4D-8BCE464CE49D`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`
- iPad（のっくりのiPad、wireless）: `00008103-000470C63E04C01E`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`

### Mac で `py` コマンドはない
- グローバル CLAUDE.md の Python 実行ルールは Windows 用。Mac では `python3`
  で代用（transcript_export.py 等）

## 関連メモ（自動メモリ）

- `feedback_dialog_style.md`: AskUserQuestion の選択肢形式は使わず自然な対話
- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウトは新機能で動かさない
- `build_workaround.md`: Google Drive 上では codesign エラー → `/tmp/memolette-run` 経由
