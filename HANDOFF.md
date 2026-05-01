# 引き継ぎメモ

## 現在の状況

- **セッション#34 完了**（2026-05-01、長め）
- ブランチ: **`main`**
- 今回はダイアログ統一の仕上げ + メモカード行数最適化 + カレンダー周りバグ修正・機能追加 + FAB簡素化

## #34 のサマリ

### BgColorPickerDialog 完全 DialogStyles 統一
- `Dialog()` ウィジェット → `showGeneralDialog` + `Material(transparent) + Container(bodyDecoration)` パターンに変換
- クラス `BgColorPickerDialog` を削除 → 関数 `showBgColorPickerDialog(context, current)` に変更
- 直書きの色・フォント・太さ・角丸・影を全て DialogStyles 経由
- ボタンを `accentButtonDecoration` の薄色背景＋色付きテキストに統一
- 呼び出し元 4 箇所（home_screen × 2 / todo_lists_screen / memo_input_area）を新 API に更新

### ダイアログ巡回 C/E/F の DialogStyles 統一
- **C 選択肢メニュー**: メモ長押し / ToDo長押し / ToDoリスト長押しのキャンセルボタン `Color(0xFF007AFF)` → `DialogStyles.defaultAction`、タグピッカーのタイトル → `DialogStyles.title`
- **E 日付ピッカー**: タイトル「日付を指定」+ サブタイトル + フッター3ボタン (キャンセル / 決定 / カレンダーから消去) を DialogStyles トークン経由に
- **F バナー**: メモ選択モード / ToDo選択削除 / ToDo結合 の 3 バナーで accent カラー & テキストスタイルを DialogStyles 経由に

### Phase 14 文字サイズ方針更新
- アクセシビリティは見送り。将来案を「スライダー → ノーマル/大の2段階トグル」に書き換え
- スライダーや3段階以上は影響範囲が広すぎる（カード行数・高さ計算が崩壊）

### メモカード grid3x6 で本文 1→2行表示
- mini 3×4 表示でカード高さが切迫していた（body Flex maxH=30.9px、2行に必要な 36.4px に届かず）
- `_bodyLinesFor` の grid3x6 mobile cap: 1→2
- `_cardPadding` の grid3x6: 4→3
- 新設 `_dividerMargin` で grid3x6 のみ縦余白縮小 (top:1, bottom:1)
- 計 7px 確保 → maxH=37.9px → SE 3×2 / mini 3×4 / standard 3×6 で本文 2行 OK

### カレンダー DayItemsPanel カードタップ遷移バグ修正（2件）
- **原因 1**: `_wrapUnfocusOnTap` の Listener が `onPointerDown` 時点で `selectedDay=null` していたため、シート内カードの InkWell.onTap 発火前にシートが unmount されてナビゲーション空振り → `onPointerUp` に移動（InkWell.onTap → Navigator.push の後に走るので実害なし）
- **原因 2**: DayItemsPanel の ToDoアイテム個別タップで `onTodoItemTap` が wire されておらず InkWell.onTap が null → CalendarView 経由で `_openTodoItemFromCalendar` を渡し、アイテムの listId から親 TodoList を引いて `_openTodoList` で遷移

### カレンダー経由オープン時のスクロール+ハイライト
- TodoListScreen に `highlightItemId` パラメータ追加
- 起動直後に対象項目を画面内にスクロール (`Scrollable.ensureVisible` + `alignmentPolicy.explicit`) + オレンジ枠で 2 回フラッシュ点滅
- 対象項目の祖先がいる場合は強制展開してから走らせる
- `_didInitialExpand` の自動全展開と競合しないよう **150ms 遅延**を挟む（タイミングバグ回避）
- `_openTodoItemFromCalendar` が listId 経由で親リスト取得し `highlightItemId` 付きで `_openTodoList` を呼ぶ

### TodoListScreen のヒントテキスト自動隠蔽
- 項目数が 6 件超のときは「タップで編集 ・ 長押しで並び替え ・ 左スワイプで削除」ヒントを非表示にして縦余白を稼ぐ

### DayItemsPanel の FAB 簡素化 + ToDoアイテムをチェックボックス表示に
- FAB を 48×48 → 32×32 にコンパクト化、＋アイコンのみのシンプル仕様（テキスト・サブバッジ撤去）
- 配置を左下/右下 → メモ列・ToDo列それぞれの**中央**に
- `_TodoItemTile` のしおりアイコン (オレンジ) → チェックボックス (緑、isDone でチェック有無を切替) に変更し ToDoリストとの視認差を明確化

## 次のアクション（次セッション #35）

### 残タスク
- **既知バグ**: ToDo項目入力中に「項目追加」ボタンを押すと、入力中の項目名が一瞬「空のアイテム」に変わってから確定される不具合（編集中アイテムの commit タイミングと新規追加の競合）
- **実機 / iPad での Phase 15 Step 9 + Phase 16 動作確認**（残）
  - SE/mini シミュ/15 Pro Max 実機/iPad 実機 4 台並列起動済み（FIFO + rsync 経由）
- 子タグドロワー「都度収納/常時表示」設定（ROADMAP アイデアメモ）
- アプリ内文字サイズ「ノーマル/大」2段階トグル（ROADMAP アイデアメモ）

### 短期備忘
- 直書きの `Color(0xFF007AFF)` がアプリ全体（機能バーやアクセント等）にまだ残っている — ダイアログ巡回外なので別タスク

## 技術メモ

### iOS 実機ワイヤレス debug ビルドは遅い
- 15 Pro Max 実機で全体的にカクカク → 主に debug build 由来。release build (`flutter run --release`) で本来の速度
- 実機検証は debug 動作 OK ならとりあえず合格、UX は release で別途確認

### カレンダー経由項目ハイライトのタイミング
- TodoListScreen 初回 build → `_didInitialExpand` が postFrame で `_expandAll` を setState
- これによりレイアウトが変わるので、ハイライトの scroll 計算は `_expandAll` の setState を待たないと古い座標で計算してしまう
- 対策: postFrame の中でさらに 150ms 遅延 → 自動展開後に flash を走らせる

### Listener.onPointerDown vs onPointerUp の使い分け
- フォーカス解除（`unfocus`）は **onPointerDown**（タップ前にキーボードを閉じてレイアウトを安定させる）
- 何かを「閉じる」処理は **onPointerUp**（子の InkWell.onTap が先に走り、その後で閉じる）
- `onPointerDown` で閉じると、子要素が unmount されて InkWell.onTap 発火タイミングで子が tree に居らず、タップが空振りする

### シミュ / 実機 ID
- iPhone 17 Pro シミュ: `ACE500F3-AA23-44EC-AB93-C4EA636FC3BC`
- iPad Pro 12.9-inch (6th gen): `1F181174-7768-44DB-9BDA-E9E9976695F0`
- iPhone 15 Pro Max（実機 wireless）: `00008130-0006252E2E40001C`
- iPad（のっくりのiPad、wireless）: `00008103-000470C63E04C01E`
- iPhone SE 3rd iOS26: `47003836-6426-4AB1-90FC-C5E73DA251C1`
- iPhone 13 mini iOS26: `B5B2C694-8EAB-4C14-AA4D-8BCE464CE49D`

### 4台並列実行の FIFO セットアップ
```bash
# SE 3rd
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe' > /dev/null 2>&1 &
# mini
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe_13' > /dev/null 2>&1 &
# 15 Pro Max
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe_15pm' > /dev/null 2>&1 &
# iPad
nohup sh -c 'while sleep 86400; do :; done > /tmp/flutter_pipe_ipad' > /dev/null 2>&1 &
# 各々別 /tmp/memolette-run-XXX に rsync して並列 flutter run
# ログは /tmp/{se,mini,15pm,ipad}_logs.txt
```

## 関連メモ（自動メモリ）

- `feedback_no_monitor_for_build.md`: flutter run のビルド完了待ちで Monitor を使わない
- `feedback_layout_immutable.md`: 既存レイアウトは新機能で動かさない、オーバーレイで実装
- `build_workaround.md`: Google Drive 上では codesign エラー → `/tmp/memolette-run` 経由
