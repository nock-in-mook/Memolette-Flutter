import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import 'font_lab_screen.dart';
import 'icon_lab_screen.dart';

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
            leading: const Icon(Icons.dataset_outlined),
            title: const Text('ダミーデータ投入'),
            subtitle: const Text('タグとメモを一括追加'),
            onTap: () => _seedDummyData(context, ref),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ダミーデータを投入しました')),
    );
  }

  Future<void> _wipeAllData(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('全てのメモとタグを削除します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final db = ref.read(databaseProvider);
    await db.wipeAll();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('全データを削除しました')),
    );
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
