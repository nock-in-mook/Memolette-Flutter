# 引き継ぎメモ

## 現在の状況
- Flutter版Memolette プロジェクト作成済み
- Swift版（`_Apps2026/Memolette`）からの移植を進める
- 技術選定完了、次は実装開始

## 技術選定（確定）
- **データ保存**: Drift（SQLite）— 多対多リレーション対応、同期の自由度が高い
- **状態管理**: Riverpod — 型安全、テストしやすい
- **同期方針**: SQLiteをローカルの「信頼できる唯一のデータ源」として、Firebase/iCloudはそこに同期する設計
  - Firebase同期: Firestore ↔ SQLite
  - iCloud同期: CloudKit ↔ SQLite

## Swift版データモデル（移植元）

### Memo（メモ）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| id | UUID | 一意識別子 |
| content | String | メモ本文（最大50,000文字） |
| title | String | メモタイトル |
| tags | [Tag] | 関連タグ（多対多） |
| isMarkdown | Bool | マークダウン形式フラグ |
| createdAt | Date | 作成日時 |
| updatedAt | Date | 更新日時 |
| isPinned | Bool | ピン留め |
| manualSortOrder | Int | 手動並び順 |
| viewCount | Int | 閲覧数 |
| lastViewedAt | Date? | 最終閲覧日時 |
| isLocked | Bool | 削除防止ロック |

### Tag（タグ）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| id | UUID | タグID |
| name | String | タグ名 |
| colorIndex | Int | カラーパレット（0-56） |
| gridSize | Int | グリッド表示サイズ（0=小, 1=中, 2=大） |
| memos | [Memo] | 関連メモ（多対多） |
| todoItems | [TodoItem] | 関連ToDo |
| todoLists | [TodoList] | 関連ToDoリスト |
| parentTagID | UUID? | 親タグID（nil=トップレベル） |
| sortOrder | Int | タブ並び順 |
| isSystem | Bool | システムタグフラグ |

### TodoItem（ToDoアイテム）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| id | UUID | アイテムID |
| listID | UUID | 所属ToDoListのID |
| title | String | タイトル |
| isDone | Bool | 完了フラグ |
| parentID | UUID? | 親アイテムID（階層構造） |
| sortOrder | Int | 並び順 |
| tags | [Tag] | 関連タグ（多対多） |
| createdAt | Date | 作成日時 |
| updatedAt | Date | 更新日時 |
| dueDate | Date? | 期限 |
| memo | String? | 補足テキスト |

### TodoList（ToDoリスト）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| id | UUID | リストID |
| title | String | タイトル |
| isPinned | Bool | ピン固定 |
| isLocked | Bool | 削除ロック |
| manualSortOrder | Int | 手動並び順 |
| tags | [Tag] | 関連タグ（多対多） |
| createdAt | Date | 作成日時 |
| updatedAt | Date | 更新日時 |

### TagHistory（タグ使用履歴）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| parentTagID | UUID | 親タグID |
| childTagID | UUID? | 子タグID |
| usedAt | Date | 使用日時 |
- 最大20件保持、同じ組み合わせは日時更新

### リレーション
- Memo ↔ Tag: 多対多（中間テーブル必要）
- TodoItem ↔ Tag: 多対多
- TodoList ↔ Tag: 多対多
- Tag: 親子関係（parentTagID自己参照）
- TodoItem: 階層構造（parentID自己参照）

## Swift版の主要画面構成
- **MainView**: ルート（iPad横画面は左右分割）
- **MemoInputView**: 入力欄（高さ328px固定）+ ルーレット + Undo/Redo
- **TabbedMemoListView**: タグタブ切り替え + グリッド表示
- **MemoDetailView**: メモ全画面表示・編集
- **QuickSortView**: 爆速メモ整理（カルーセルUI）
- **TodoListsView / TodoListView**: ToDo管理
- **TagDialView**: 扇形ルーレット（親子タグ選択）
- **SettingsView**: アプリ設定

## Swift版の主要機能
- メモCRUD（自動保存）、ピン固定、削除ロック、閲覧追跡
- マークダウン対応（リアルタイムプレビュー、ツールバー）
- 親子2階層タグ、56色パレット
- 爆速メモ整理モード（50件ずつカルーセル処理）
- ToDoリスト（階層アイテム対応）
- Undo/Redo（最大50スナップショット）
- 行番号エディタ（GutteredTextView）
- カスタムリッチダイアログ（標準alertは使わない）

## 移植順（予定）
1. Memo CRUD + ローカル保存（Drift）
2. Tag管理（親子階層、多対多）
3. メモ一覧画面（グリッド表示）
4. メモ入力・編集画面
5. 爆速モード
6. マークダウン対応
7. ToDo機能
8. Firebase同期
9. iCloud同期

## 環境
- Flutter 3.41.6 (stable)
- CocoaPods 1.16.2
- Xcode 26.3
- Android SDK: 未インストール（iOS優先）

## UIルール（Swift版から引き継ぎ）
- ダイアログは全てカスタムリッチUI（標準alertは使わない）
- シミュレータでprintデバッグは使えない → UI overlay等で対応

## 参照元
- Swift版ソースコード: `_Apps2026/Memolette/SokuMemoKun/SokuMemoKun/`
- Swift版HANDOFF: `_Apps2026/Memolette/HANDOFF.md`
