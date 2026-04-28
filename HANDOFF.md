# 引き継ぎメモ

## 現在の状況

- **セッション#30 完了**（2026-04-27 〜 29、長丁場）
- ブランチ: **`main`**（feat/calendar-view を fast-forward でマージ済み）
- Phase 15 はメイン実装完了。Step 9 の細部整合性は未着手
- 動作確認: iPhone 17 Pro シミュ中心。実機 / iPad はまだ未確認

## #30 のサマリ: Phase 15 Step 8 + UI 全面整備 + データ保護方針

### Phase 15 Step 8: ToDo に日付欄追加（todo_list_screen.dart）
- リストヘッダ右にカレンダーアイコン（タイトル + 日付テキスト一体）
- 各アイテム行のメモボタン隣に日付ボタン（36×36）
- 付与済みアイテムはタイトル下にバッジ（アイコン+YYYY/MM/DD）
- `_showListDatePicker` / `_showItemDatePicker` で `setTodoListEventDate` / `setTodoItemEventDate` に接続

### 日付ピッカー UI 全面改修（date_picker_sheet.dart）
- ヘッダ刷新: 「日付を指定」「（カレンダーに表示されます）」+ 左上の更新アイコン（本日へジャンプ、右上の本日ボタン廃止）
- 月ブロック: 6 週固定撤廃 → 実際の週数で動的高さ（`_calcMonthHeight` ヘルパ）
- セル高 40 → 36、月見出しフォント縮小
- ListView.itemExtent 撤廃 → 各月固有高さで描画、`_scrollToSelectedMonth` は累積高さで offset 計算
- ボタンを OutlinedButton 化（キャンセル/決定/カレンダーから消去すべて枠付き、グレー背景）
- 全体高さ heightFactor 0.85 → 0.74、`Center` → `Align(bottomCenter)` で下端固定 + 上端下げ

### カレンダー日付セルに帯表示（calendar_view.dart, database.dart, database_provider.dart）
- `DaySummary` 型: メモ件数+最初のラベル / ToDo件数+最初のラベル
- `watchEventSummariesForRange`: メモ・TodoList・TodoItem を UNION ALL で取得、TodoList はタイトル空なら最初のアイテム名にフォールバック
- `eventSummariesForRangeProvider` を月単位で購読
- `_DayCell`: 既存件数バッジ撤去、日付数字＋メモ(オレンジ)/ToDo(緑) の帯
- 帯は横幅いっぱい、複数件は右端にバッジ、テキストはクリップ（…なし）

### DayItemsPanel 横 2 列化 + フロート FAB（day_items_panel.dart）
- 左列メモ / 中央仕切り線 / 右列 ToDo（各列独立スクロール）
- 各列下端右下に円形フロート FAB（白背景、アイコン+右下の小さい+、テキスト無し）
- カード周囲背景: lightBlue.shade50 → `#F1F1F1`（grey.shade100 と shade200 の中間）でほんのり濃く
- カード（`_CardShell`）に薄いドロップシャドウ（elevation 1.5）
- カード内テキスト全体的に縮小（タイトル 14→11、本文 12→10）
- 日付ヘッダ: フォント 16→14, 上下 padding 80%

### メモ eventDate 表示の移譲（memo_input_area.dart, home_screen.dart）
- MemoInputArea から build 内の日付スペース（SizedBox 18pt）撤去 → 白カードのサイズは Step 7 前と同一に戻る
- `onEventDateChanged` callback を MemoInputArea に追加、`_applyMemoData` / `_clearInput` / `_showCalendarDatePicker` から発火
- home_screen 側で `_currentMemoEventDate` を保持、`_buildFunctionBarSection` の Stack の **外側**（AnimatedContainer の上層）に Positioned で日付テキスト
- 機能バーが height 0（編集中等）でも日付テキストは表示
- タップで `unfocus` → 日付ピッカー起動
- 色: グレー → オレンジ（メモのテーマ色）
- 右端は白カードの右枠線と一致（`right: 10`）
- callback は `addPostFrameCallback` で遅延（build 中の setState 回避、ToDo 編集画面戻りでのエラー対策）

### 機能バー縮小（home_screen.dart `_buildFunctionBar`）
- SizedBox(44x44) → SizedBox(44x28)（縦幅 16pt 縮小）
- フォルダビューがその分上に上がる

### カレンダーシート閉じる動作の拡張（home_screen.dart）
- タブ切替時: build 内の `_selectedTabKey` 変化検知で post-frame に `calendarSelectedDayProvider` を null 化
- 機能バー / ナビバー / 余白タップ: `_wrapUnfocusOnTap` の `onPointerDown` 内で同 Provider を null 化
- 既存の半透明オーバーレイタップ（calendar_view 内）は変更なし

### ROADMAP 追記
- Phase 9 同期にデータ保護方針セクション追加（多重防御策・絶対遵守）
- アイデア: Google Calendar 連携 / リマインダー / 自分宛メール / メッセージ機能
- 備忘: 選択中フォルダタブの重なり順調整

### memory 追加（~/.claude/projects/.../memory/）
- `feedback_layout_immutable.md`: 既存レイアウトは新機能追加で 1px も動かさない、オーバーレイで実装
- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor は使わない（チャット通知が溢れる）

## 次のアクション（次セッション #31）

### ToDo 関連の細かい直し（ユーザー予告）
- **項目入力時の謎のインデント問題**（todo_list_screen の `_EditingItemField` 周辺？）
- **TODO 選択削除の実装**（メモグリッドの選択削除と同等の体験）
- **TODO カードに背景色追加**（メモカードと同じく色付け可能に）
- **全件削除の確認を 1 回に**（現状は二段階？まとめる）

### 残課題
- iPad 横画面（embedded mode）での Phase 15 動作確認
- iPhone 実機での動作確認
- `FOCUS_REGRESSION_CHECKLIST.md` の全項目チェック
- iPad 縦画面での Phase 15 動作確認
- メモカードに eventDate バッジ表示（Step 9）
- Undo/Redo スナップショットへの eventDate 統合（Step 9）

## 技術メモ

### shimu / 実機 ID
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`

### Pods 16.0 で再 install 必要だった件（#30 で解決）
- `/tmp/memolette-run/ios/Podfile` が `# platform :ios, '13.0'` のままだった
- 結果として `objective_c.framework` が Runner.app に組み込まれず Unhandled Exception
- ios/ 全体を本体側から rsync で再同期 + `Pods` / `Podfile.lock` を削除して `pod install` 再実行で解決
- 次セッション以降、ios/ の同期も意識する

### Stack の Positioned と hitTest の罠
- `Stack(clipBehavior: Clip.none) + Positioned(bottom: -16)` で外にはみ出した子は **タップ判定が届かない**
- 解決: タップが必要な要素は Stack の bound 内に置くか、別 Stack（親側）でラップする
- メモ入力エリア下の日付テキストはこれで右往左往した結果、機能バー側の Stack に Positioned で重ねる方式に着地

### setState during build 問題
- ToDo 編集画面から戻ると `setState() or markNeedsBuild() called during build` が出ていた
- 原因: home_screen の `onEventDateChanged: (date) => setState(...)` が build 中に呼ばれる経路があった
- 対処: `addPostFrameCallback` で遅延

### Monitor で flutter run のビルドを待たない
- メモ: `feedback_no_monitor_for_build.md` に記載
- Bash の `run_in_background: true` + 別 Bash で `until grep -q "VM Service" log; do sleep 2; done` 方式が良い

## ピッカー / カレンダー周辺の最終仕様（#30 着地点）

### 日付ピッカー
- 高さ: 画面の 0.74、下端固定（SafeArea 内 bottomCenter）
- ヘッダ: タイトル「日付を指定」+ 注釈「（カレンダーに表示されます）」+ 左上 refresh アイコン + 下に選択日プレビュー（YYYY年M月D日(曜)）
- 月ブロック: 動的高さ（4-6 週）、月見出しはカード上部、セル高 36
- ボタン: 3 つとも OutlinedButton（グレー背景 + 色付き枠）
- 枠外タップで閉じる（既存）

### カレンダー（全カレンダータブ）
- 日付セル: 中央に日付数字 + 下部にメモ帯（オレンジ）+ ToDo 帯（緑）
- 帯は横幅いっぱい、複数件は右端に件数バッジ、テキストは clip
- 件数バッジ（オレンジ丸）は撤去

### 日別シート（DayItemsPanel）
- 横 2 列（左メモ / 右 ToDo）、各列独立スクロール
- 各列下端右下に円形フロート FAB（白背景、アイコン+小さい+）
- カード周囲背景 `#F1F1F1`、カードは elevation 1.5 のドロップシャドウ
- 日付ヘッダ（上端）は lightBlue.shade50 のまま

### メモ入力下の eventDate 表示
- 機能バーの上端右側にオーバーレイ（白カードの右枠線と右端一致）
- 編集中（機能バー height 0）でも独立に表示
- タップで unfocus → ピッカー起動
- 色はオレンジ（メモテーマ色）
