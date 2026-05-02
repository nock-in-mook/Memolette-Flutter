import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_provider.dart';
import '../utils/toast.dart';
import '../widgets/confirm_delete_dialog.dart';
import 'font_lab_screen.dart';
import 'font_weight_lab_screen.dart';
import 'icon_lab_screen.dart';
import 'all_tab_filter_lab_screen.dart';
import 'maximize_icon_lab_screen.dart';
import 'multi_action_icon_lab_screen.dart';
import 'preview_icon_lab_screen.dart';
import 'settings_icon_lab_screen.dart';
import 'undo_redo_icon_lab_screen.dart';

/// 設定画面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView(
        children: [
          const _SectionHeader('開発'),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('アイコンラボ'),
            subtitle: const Text('候補アイコンを比較する'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IconLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: const Text('フォントラボ'),
            subtitle: const Text('「このフォルダにメモ作成」を各フォントで比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FontLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('設定アイコンラボ'),
            subtitle: const Text('設定ボタンの候補アイコンを比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsIconLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.zoom_out_map),
            title: const Text('最大化アイコンラボ'),
            subtitle: const Text('機能バー右端の最大化ボタン候補を比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MaximizeIconLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('Undo/Redo アイコンラボ'),
            subtitle: const Text('フッターツールバーのUndo/Redoボタン候補を比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const UndoRedoIconLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.preview),
            title: const Text('プレビューアイコンラボ'),
            subtitle: const Text('プレビューボタンの候補アイコンを比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PreviewIconLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.ellipsis_circle),
            title: const Text('多機能アイコンラボ'),
            subtitle: const Text('機能バーの多機能ボタン候補アイコンを比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const MultiActionIconLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('すべてフィルタタブラボ'),
            subtitle: const Text('「すべて」タブ上部のフィルタ表示候補を比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AllTabFilterLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.format_bold),
            title: const Text('フォントウェイトラボ'),
            subtitle: const Text('タイトル・本文の太さを比較'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FontWeightLabScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dataset_outlined),
            title: const Text('ダミーデータ投入'),
            subtitle: const Text('タグとメモを一括追加'),
            onTap: () => _seedDummyData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('子タグもりもり親タグを追加'),
            subtitle: const Text('子タグドロワー検証用 (子タグ30個)'),
            onTap: () => _seedManyChildTagsParent(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Claudeダミーデータ投入'),
            subtitle: const Text('検索検証用: Claude/CLAUDE/claude/Cｌａｕｄｅ等を含むメモ'),
            onTap: () => _seedClaudeSearchData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: const Text('長文ダミーメモ追加'),
            subtitle: const Text('1000〜10000文字 (1000刻み) を10件'),
            onTap: () => _seedLongMemos(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.title),
            title: const Text('長タイトル＋長タグ名ダミー'),
            subtitle: const Text('タイトル・タグ名が長いメモを各種追加'),
            onTap: () => _seedLongTitleTagMemos(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('5階層 ToDo + 結合相手ダミー'),
            subtitle: const Text('結合検証用: 結合すると6階層目が出る'),
            onTap: () => _seedDummy5LevelTodo(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined,
                color: Colors.red),
            title: const Text('全データ削除',
                style: TextStyle(color: Colors.red)),
            onTap: () => _wipeAllData(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _seedDummyData(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // 親タグ作成（バリエーション多め）
    final work = await db.createTag(name: '仕事', colorIndex: 1);
    final diary = await db.createTag(name: '日記', colorIndex: 3);
    final shopping = await db.createTag(name: '買い物', colorIndex: 5);
    final hobby = await db.createTag(name: '趣味', colorIndex: 7);
    final health = await db.createTag(name: '健康', colorIndex: 9);
    final travel = await db.createTag(name: '旅行', colorIndex: 11);
    final study = await db.createTag(name: '勉強', colorIndex: 13);
    final ideas = await db.createTag(name: 'アイデア', colorIndex: 15);

    // 子タグ
    final workMeeting = await db.createTag(
        name: '会議', colorIndex: 2, parentTagId: work.id);
    final workReport = await db.createTag(
        name: '日報', colorIndex: 4, parentTagId: work.id);
    final workTodo = await db.createTag(
        name: 'TODO', colorIndex: 6, parentTagId: work.id);
    final shopFood = await db.createTag(
        name: '食料品', colorIndex: 6, parentTagId: shopping.id);
    final shopElectronics = await db.createTag(
        name: '家電', colorIndex: 8, parentTagId: shopping.id);
    final shopClothes = await db.createTag(
        name: '服', colorIndex: 10, parentTagId: shopping.id);
    final diaryMorning = await db.createTag(
        name: '朝', colorIndex: 14, parentTagId: diary.id);
    final diaryNight = await db.createTag(
        name: '夜', colorIndex: 16, parentTagId: diary.id);
    final healthRun = await db.createTag(
        name: 'ラン', colorIndex: 18, parentTagId: health.id);
    final healthFood = await db.createTag(
        name: '食事', colorIndex: 20, parentTagId: health.id);
    final travelDom = await db.createTag(
        name: '国内', colorIndex: 22, parentTagId: travel.id);
    final travelAbr = await db.createTag(
        name: '海外', colorIndex: 24, parentTagId: travel.id);
    final studyEng = await db.createTag(
        name: '英語', colorIndex: 26, parentTagId: study.id);
    final studyCode = await db.createTag(
        name: 'コード', colorIndex: 28, parentTagId: study.id);

    // ヘルパー
    Future<void> mk(
      String title,
      String content, {
      List<String> tagIds = const [],
    }) async {
      final m = await db.createMemo(title: title, content: content);
      for (final tid in tagIds) {
        await db.addTagToMemo(m.id, tid);
      }
    }

    // 仕事（多め）
    await mk('議事録 2026/04/08',
        '出席: 田中、佐藤、山田\n議題:\n- 新機能リリース日\n- バグ修正の優先度\n- Q2の目標設定',
        tagIds: [work.id, workMeeting.id]);
    await mk('日報', '・PRレビュー 3件\n・API設計\n・顧客MTG',
        tagIds: [work.id, workReport.id]);
    await mk('TODO 来週', '- スプリント計画\n- デザインレビュー',
        tagIds: [work.id, workTodo.id]);
    await mk('', '思いつきメモ。コードの命名規則を統一したい',
        tagIds: [work.id]);
    await mk('長いタイトルのメモを作ってみるとどうなるかテスト',
        '本文は短い', tagIds: [work.id, workMeeting.id]);
    await mk('議事録 4/01', '・予算確認\n・人員配置', tagIds: [work.id]);
    await mk('議事録 4/05', '・新規案件のヒアリング', tagIds: [work.id]);
    await mk('週次振り返り', 'KPT:\nKeep: ペアプロ\nProblem: テスト不足\nTry: TDD',
        tagIds: [work.id, workReport.id]);
    await mk('', '調査タスク: フロント側のメモリリーク',
        tagIds: [work.id, workTodo.id]);
    await mk('採用候補メモ', 'A: 経験豊富、B: 若手だが伸びそう',
        tagIds: [work.id]);

    // 日記
    await mk('今日の出来事', '朝散歩した。気持ちよかった。',
        tagIds: [diary.id, diaryMorning.id]);
    await mk('', '雨の音が好き', tagIds: [diary.id, diaryNight.id]);
    await mk('読書メモ', '小説を読み終えた。',
        tagIds: [diary.id, diaryNight.id]);
    await mk('週末日記', 'カフェに行った。新しいラテが美味しい',
        tagIds: [diary.id, diaryMorning.id]);
    await mk('', '寝る前にぼんやり考えたこと。明日のこと、来週のこと',
        tagIds: [diary.id, diaryNight.id]);
    await mk('久しぶりの晴れ', '朝から散歩。空気が澄んでる',
        tagIds: [diary.id, diaryMorning.id]);
    await mk('', 'ちょっと疲れた一日', tagIds: [diary.id]);

    // 買い物（子タグ豊富）
    await mk('スーパーで買うもの',
        '- 牛乳\n- 卵\n- パン\n- レタス\n- トマト',
        tagIds: [shopping.id, shopFood.id]);
    await mk('週末のレシピ', 'パスタ 200g、卵 2個',
        tagIds: [shopping.id, shopFood.id]);
    await mk('家電量販店', '- USB-Cハブ\n- HDMIケーブル',
        tagIds: [shopping.id, shopElectronics.id]);
    await mk('iPhoneケース候補', 'シリコン製、ブラック',
        tagIds: [shopping.id, shopElectronics.id]);
    await mk('', 'ティッシュ買う', tagIds: [shopping.id]);
    await mk('春服リスト', 'ライトジャケット、シャツ2枚',
        tagIds: [shopping.id, shopClothes.id]);
    await mk('スニーカー', '白系 27cm', tagIds: [shopping.id, shopClothes.id]);
    await mk('', 'ヘッドホン買い替え検討',
        tagIds: [shopping.id, shopElectronics.id]);
    await mk('調味料', '醤油、味噌、出汁パック',
        tagIds: [shopping.id, shopFood.id]);

    // 趣味
    await mk('観たい映画', '- 君の名は。\n- インセプション', tagIds: [hobby.id]);
    await mk('読みたい本リスト', '・ノルウェイの森\n・1Q84', tagIds: [hobby.id]);
    await mk('カメラ', '中古でフィルムカメラ買ってみたい', tagIds: [hobby.id]);
    await mk('', 'ボードゲーム会の候補日', tagIds: [hobby.id]);
    await mk('プラモ', '次はガンプラHGに挑戦', tagIds: [hobby.id]);

    // 健康
    await mk('体重メモ', '今日: 68.2kg', tagIds: [health.id]);
    await mk('朝ラン', '5km / 28min', tagIds: [health.id, healthRun.id]);
    await mk('夕ラン', '3km / 17min', tagIds: [health.id, healthRun.id]);
    await mk('', '体調メモ: のどが少し痛い', tagIds: [health.id]);
    await mk('食事記録', '朝: トースト\n昼: 定食\n夜: パスタ',
        tagIds: [health.id, healthFood.id]);
    await mk('プロテイン', 'ホエイ 30g 朝晩', tagIds: [health.id, healthFood.id]);
    await mk('', '寝つきが悪い日が続く', tagIds: [health.id]);

    // 旅行
    await mk('箱根 1泊2日', '・温泉\n・美術館\n・ロープウェイ',
        tagIds: [travel.id, travelDom.id]);
    await mk('沖縄', '5月の連休、レンタカー予約',
        tagIds: [travel.id, travelDom.id]);
    await mk('', '京都の桜が見たい', tagIds: [travel.id, travelDom.id]);
    await mk('台湾', '九份、台北101、夜市',
        tagIds: [travel.id, travelAbr.id]);
    await mk('パスポート期限', '2027/03 まで',
        tagIds: [travel.id, travelAbr.id]);
    await mk('荷物リスト', '・充電器\n・常備薬\n・ガイドブック', tagIds: [travel.id]);

    // 勉強
    await mk('英単語', 'serendipity, ephemeral, ubiquitous',
        tagIds: [study.id, studyEng.id]);
    await mk('英会話メモ', 'How have you been? を自然に使えるように',
        tagIds: [study.id, studyEng.id]);
    await mk('Flutter学習', 'Riverpod のProvider と StreamProvider の違い',
        tagIds: [study.id, studyCode.id]);
    await mk('', 'CustomPainter の使い方を覚えた',
        tagIds: [study.id, studyCode.id]);
    await mk('Dart基礎', 'enum の拡張、sealed class',
        tagIds: [study.id, studyCode.id]);
    await mk('', 'TOEIC 3月受験予定', tagIds: [study.id, studyEng.id]);

    // アイデア
    await mk('アプリ案', '散歩中に音声メモを取れるやつ', tagIds: [ideas.id]);
    await mk('', '冷蔵庫の中身管理アプリ', tagIds: [ideas.id]);
    await mk('UI改善', 'タブの並び順を覚えてくれる機能', tagIds: [ideas.id]);
    await mk('ブログネタ', '・SwiftからFlutterへの移植記\n・OSS開発の記録',
        tagIds: [ideas.id]);

    // タグなし
    await mk('ふとした思いつき', 'アプリのアイデア: 音声でメモするやつ');
    await mk('', '買い物リスト消化');
    await mk('TODOリスト', '・郵便局\n・銀行\n・図書館返却');
    await mk('', 'カフェの電源席リスト作りたい');
    await mk('複数タグ', '仕事と日記の境界線にあるような内容',
        tagIds: [work.id, diary.id]);
    await mk('複数タグ2', 'アイデアと勉強の交差点',
        tagIds: [ideas.id, study.id]);
    await mk(
        'これはとても長い本文を持つメモのテストです',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. 日本語混じりでもどうなるかチェック。改行も入れてみる。\n\n第二段落。\n第三段落。');

    if (!context.mounted) return;
    showToast(context, 'ダミーデータを投入しました');
  }

  // 子タグドロワー検証用: 子タグを30個持つ親タグを1つ作る
  Future<void> _seedManyChildTagsParent(
      BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // 親タグ「もりもり」
    final parent = await db.createTag(name: 'もりもり', colorIndex: 30);

    // 子タグ30個（バリエーション豊か）
    final names = [
      '英単語', '熟語', '長文', 'リスニング', '発音',
      '文法', '会話', '作文', '読解', 'スラング',
      '映画', 'ドラマ', '音楽', 'Podcast', 'YouTube',
      '日常会話', 'ビジネス', '旅行英語', '面接', '電話',
      'TOEIC', 'TOEFL', '英検', 'IELTS', '留学準備',
      'ニュース', '科学', '歴史', '文化', '経済',
    ];
    for (var i = 0; i < names.length; i++) {
      final colorIdx = (i * 2 + 1) % 70; // 色を散らす
      await db.createTag(
        name: names[i],
        colorIndex: colorIdx,
        parentTagId: parent.id,
      );
    }

    if (!context.mounted) return;
    showToast(context, '「もりもり」親タグ + 子タグ30個を追加しました');
  }

  // 検索検証用: Claude という単語を様々な大小・全半角で含むメモを大量投入
  Future<void> _seedClaudeSearchData(
      BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // 検証用に専用親タグを4個作る
    final ai = await db.createTag(name: 'AI', colorIndex: 12);
    final dev = await db.createTag(name: '開発', colorIndex: 18);
    final note = await db.createTag(name: 'メモ', colorIndex: 26);
    final misc = await db.createTag(name: 'その他', colorIndex: 34);

    // 子タグも軽く
    final aiChat = await db.createTag(
        name: 'チャット', colorIndex: 14, parentTagId: ai.id);
    final aiCode =
        await db.createTag(name: 'コード', colorIndex: 16, parentTagId: ai.id);
    final devTool = await db.createTag(
        name: 'ツール', colorIndex: 20, parentTagId: dev.id);

    Future<void> mk(String title, String content,
        {List<String> tagIds = const []}) async {
      final m = await db.createMemo(title: title, content: content);
      for (final t in tagIds) {
        await db.addTagToMemo(m.id, t);
      }
    }

    // ── タイトルにClaude/大小バリエーション ──
    await mk('Claude を試す', '今日は半角小文字標準。Claude の応答は早かった。',
        tagIds: [ai.id, aiChat.id]);
    await mk('CLAUDE 大文字テスト', 'タイトルだけ大文字 CLAUDE。本文は普通のClaude表記。',
        tagIds: [ai.id, aiChat.id]);
    await mk('claude 全部小文字', '本文も全部小文字 claude です。',
        tagIds: [ai.id]);
    await mk('Cｌａｕｄｅ 全角テスト', '全角の Cｌａｕｄｅ は別物として扱われるはず。',
        tagIds: [misc.id]);
    await mk('Claudeとペアプロ', 'コードレビューを Claude に頼んで時短した',
        tagIds: [dev.id, aiCode.id, devTool.id]);
    await mk('AI比較メモ', 'GPT, Gemini, Claude, Llama を比べた所感。',
        tagIds: [ai.id]);

    // ── 本文にだけ含む ──
    await mk('プロジェクト計画', 'AI支援で工数削減。Claudeを中心に運用予定。',
        tagIds: [dev.id]);
    await mk('日報 4/9', '・コードレビュー\n・claudeに質問×3件\n・PR2件マージ',
        tagIds: [dev.id]);
    await mk('議事録', '出席: 田中、佐藤\n議題:\n- Claudeの導入評価\n- 来週のスプリント',
        tagIds: [dev.id, devTool.id]);
    await mk('読書ログ', 'AI関連の本まとめ。Claude については別記事参照。',
        tagIds: [note.id]);
    await mk('長文サンプル',
        'Lorem ipsum dolor sit amet. Claude is helpful. 日本語と英語混じりのサンプル本文。'
        '2行目: claude lower case here.\n3行目: CLAUDE all caps. \n4行目: 通常テキスト。',
        tagIds: [note.id]);

    // ── ヒットしないが似た単語 ──
    await mk('clouds tag', '天気の話。clouds in the sky.',
        tagIds: [misc.id]); // claude にヒットしない
    await mk('Cloude typo', 'Cloude (タイプミス)。これも本来ヒットしない。',
        tagIds: [misc.id]);

    // ── 大量データ ──
    for (var i = 1; i <= 30; i++) {
      await mk(
        'メモ #$i',
        i % 3 == 0
            ? '$i 番目のメモ。Claude を含む本文 ($i)'
            : i % 5 == 0
                ? '$i 番目。CLAUDE を大文字で。'
                : '$i 番目の普通のメモ',
        tagIds: i % 2 == 0 ? [ai.id] : [dev.id],
      );
    }

    // ── TODO リスト（title / items.title / items.memo に Claude バリエーション）──
    Future<TodoList> mkList(String title,
        {List<String> tagIds = const []}) async {
      final list = await db.createTodoList(title: title);
      for (final tid in tagIds) {
        await db.addTagToTodoList(list.id, tid);
      }
      return list;
    }

    // 1. リストタイトルに Claude
    final l1 = await mkList('Claude プロジェクト', tagIds: [ai.id, aiChat.id]);
    await db.createTodoItem(listId: l1.id, title: 'API呼び出しの設計');
    await db.createTodoItem(listId: l1.id, title: 'プロンプト最適化');
    await db.createTodoItem(
        listId: l1.id, title: '評価指標の策定', memo: 'Claudeの応答品質を測る指標');

    final l2 = await mkList('CLAUDE 検証タスク', tagIds: [dev.id, devTool.id]);
    await db.createTodoItem(listId: l2.id, title: 'API キー取得');
    await db.createTodoItem(listId: l2.id, title: 'テストコード作成');

    // 2. アイテムタイトルに Claude
    final l3 = await mkList('AI リサーチ', tagIds: [note.id]);
    await db.createTodoItem(listId: l3.id, title: 'Claude の料金体系');
    await db.createTodoItem(listId: l3.id, title: 'GPT との比較');
    await db.createTodoItem(listId: l3.id, title: 'Gemini との比較');

    // 3. アイテムメモに Claude
    final l4 = await mkList('AI ツール選定', tagIds: [dev.id, aiCode.id]);
    await db.createTodoItem(
        listId: l4.id,
        title: 'コスト試算',
        memo: 'Claude / GPT / Gemini の月額比較表を作成する');
    await db.createTodoItem(
        listId: l4.id,
        title: 'パフォーマンス評価',
        memo: 'claudeのレスポンスタイムを実測');

    // 4. タイトル / items / memo 全部に Claude
    final l5 = await mkList('Claude 導入プロジェクト', tagIds: [ai.id]);
    await db.createTodoItem(
        listId: l5.id, title: 'Claude 試用', memo: 'Claude のAPIを触ってみる');
    await db.createTodoItem(listId: l5.id, title: 'チーム内共有');
    await db.createTodoItem(
        listId: l5.id, title: 'ドキュメント整備', memo: 'CLAUDE の使い方をまとめる');

    // 5. ノイズ（Claude 非含有）
    final l6 = await mkList('買い物リスト', tagIds: [misc.id]);
    await db.createTodoItem(listId: l6.id, title: '牛乳');
    await db.createTodoItem(listId: l6.id, title: 'パン');
    await db.createTodoItem(listId: l6.id, title: '卵');

    final l7 = await mkList('今日のタスク', tagIds: [misc.id]);
    await db.createTodoItem(listId: l7.id, title: '洗濯');
    await db.createTodoItem(listId: l7.id, title: '掃除');

    // 6. 大量データ（一部に Claude 混入）
    for (var i = 1; i <= 15; i++) {
      final l = await mkList('TODO #$i',
          tagIds: i % 2 == 0 ? [ai.id] : [dev.id]);
      await db.createTodoItem(listId: l.id, title: 'タスクA');
      await db.createTodoItem(listId: l.id, title: 'タスクB');
      if (i % 3 == 0) {
        await db.createTodoItem(
            listId: l.id,
            title: 'Claudeに相談',
            memo: '$i 番目のリスト内メモ');
      }
      if (i % 5 == 0) {
        await db.createTodoItem(
            listId: l.id, title: 'まとめ作成', memo: 'claude の出力を添付');
      }
    }

    if (!context.mounted) return;
    showToast(context, 'Claude検索検証用ダミーデータを投入しました（メモ + TODO）');
  }

  // 長文メモ検証用: 1000〜10000文字を1000刻みで10件
  Future<void> _seedLongMemos(
      BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // パラグラフのソース文（句読点・改行を含む自然な日本語）
    const para = '今日は朝から雨が降っていて、傘を持って出かけた。'
        '駅までの道で猫を見かけて、思わず立ち止まった。'
        'コーヒーを買って電車に乗り、本を読みながら通勤した。'
        '会社に着くと同僚が新しいプロジェクトの話をしていた。'
        'ランチは近くのカフェで済ませ、午後は集中して資料作成に没頭した。\n\n';

    String makeText(int targetChars) {
      final buf = StringBuffer();
      var i = 1;
      while (buf.length < targetChars) {
        buf.write('段落 $i: $para');
        i++;
      }
      // 厳密に target に揃える
      return buf.toString().substring(0, targetChars);
    }

    for (var n = 1000; n <= 10000; n += 1000) {
      await db.createMemo(
        title: '長文サンプル $n文字',
        content: makeText(n),
      );
    }

    if (!context.mounted) return;
    showToast(context, '長文ダミーメモ10件を追加しました');
  }

  Future<void> _seedLongTitleTagMemos(
      BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // 長い名前の親タグ
    final longParent = await db.createTag(
        name: 'プログラミング学習ノート集', colorIndex: 17);
    final longParent2 = await db.createTag(
        name: '毎日の体調管理と食事記録', colorIndex: 21);

    // 長い名前の子タグ
    final longChild1 = await db.createTag(
        name: 'Flutterウィジェット設計メモ',
        colorIndex: 19,
        parentTagId: longParent.id);
    final longChild2 = await db.createTag(
        name: 'Dart非同期処理パターン集',
        colorIndex: 23,
        parentTagId: longParent.id);
    final longChild3 = await db.createTag(
        name: '朝昼晩の栄養バランスチェック',
        colorIndex: 25,
        parentTagId: longParent2.id);

    // 1. 長タイトル + 親タグのみ
    final m1 = await db.createMemo(
      title: '来週の月曜日までに提出しなければならないレポートの下書きメモ',
      content: '第1章: はじめに\n第2章: 調査方法\n第3章: 結果と考察\n\nまだ第2章の途中。',
    );
    await db.addTagToMemo(m1.id, longParent.id);

    // 2. 長タイトル + 親タグ + 子タグ
    final m2 = await db.createMemo(
      title: 'StatefulWidgetのライフサイクルを完全に理解するための実験ログ',
      content: 'initState → didChangeDependencies → build → didUpdateWidget → dispose\nそれぞれのタイミングでprintして確認する。',
    );
    await db.addTagToMemo(m2.id, longParent.id);
    await db.addTagToMemo(m2.id, longChild1.id);

    // 3. 長タイトル + 親タグ + 子タグ（別の組み合わせ）
    final m3 = await db.createMemo(
      title: 'async/awaitとFuture.thenの使い分けについて考えたことのまとめ',
      content: 'async/awaitの方が読みやすいが、並列実行にはFuture.waitが必要。\nエラーハンドリングはtry-catchで統一する方針にした。',
    );
    await db.addTagToMemo(m3.id, longParent.id);
    await db.addTagToMemo(m3.id, longChild2.id);

    // 4. 長タイトル + タグなし
    final m4 = await db.createMemo(
      title: '今日スーパーで見かけた珍しい野菜の名前を忘れないようにメモしておく',
      content: 'ロマネスコ？ビーツ？名前が思い出せない…緑色のフラクタルっぽいやつ。',
    );

    // 5. 長タイトル + 別の親タグ + 子タグ
    final m5 = await db.createMemo(
      title: '一週間の食事を写真付きで記録して振り返るための習慣化チャレンジ',
      content: '月曜: 朝パン、昼弁当、夜カレー\n火曜: 朝グラノーラ、昼ラーメン、夜鍋',
    );
    await db.addTagToMemo(m5.id, longParent2.id);
    await db.addTagToMemo(m5.id, longChild3.id);

    // 6. 超長タイトル
    final m6 = await db.createMemo(
      title: 'このタイトルはとても長くて画面に収まりきらないかもしれないけれどテスト用なので気にしない',
      content: 'テスト用メモ。',
    );
    await db.addTagToMemo(m6.id, longParent.id);

    if (context.mounted) {
      showToast(context, '長タイトル＋長タグ名ダミーを追加しました');
    }
  }

  Future<void> _seedDummy5LevelTodo(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // A: 5階層構造のリスト (depth 0〜4 = 5階層)
    final listA = await db.createTodoList(title: 'A: 5階層');
    final lv1 = await db.createTodoItem(listId: listA.id, title: 'Lv1');
    final lv2 = await db.createTodoItem(
        listId: listA.id, title: 'Lv2', parentId: lv1.id);
    final lv3 = await db.createTodoItem(
        listId: listA.id, title: 'Lv3', parentId: lv2.id);
    final lv4 = await db.createTodoItem(
        listId: listA.id, title: 'Lv4', parentId: lv3.id);
    await db.createTodoItem(
        listId: listA.id, title: 'Lv5', parentId: lv4.id);

    // B: 結合相手 (シンプルな1階層リスト)
    final listB = await db.createTodoList(title: 'B: 結合相手');
    await db.createTodoItem(listId: listB.id, title: 'B-1');
    await db.createTodoItem(listId: listB.id, title: 'B-2');

    if (!context.mounted) return;
    showToast(context, 'A(5階層) と B を作成しました');
  }

  Future<void> _wipeAllData(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDeleteDialog(
      context: context,
      title: '全データ削除',
      message: '全てのメモとタグを削除します。よろしいですか？',
      confirmLabel: '削除する',
    );
    if (!ok) return;

    final db = ref.read(databaseProvider);
    await db.wipeAll();

    if (!context.mounted) return;
    showToast(context, '全データを削除しました');
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
