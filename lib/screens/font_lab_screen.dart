import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// フォントラボ
/// 「このフォルダにメモ作成」ボタンを各フォントで描画して比較
class FontLabScreen extends StatelessWidget {
  const FontLabScreen({super.key});

  // iOSに標準で入っているフォントの候補
  // (バンドル不要、追加ライセンス不要)
  static const List<_FontCandidate> _candidates = [
    _FontCandidate('default (Material Roboto)', null),
    _FontCandidate('SF Pro (system, dot)', '.SF UI Text'),
    _FontCandidate('SF Pro Rounded (dot)', '.SF Pro Rounded'),
    _FontCandidate('CupertinoSystemText', 'CupertinoSystemText'),
    _FontCandidate('CupertinoSystemDisplay', 'CupertinoSystemDisplay'),
    _FontCandidate('Hiragino Maru Gothic ProN ★丸ゴシック', 'Hiragino Maru Gothic ProN'),
    _FontCandidate('Hiragino Sans', 'Hiragino Sans'),
    _FontCandidate('HiraMaruProN-W4', 'HiraMaruProN-W4'),
    _FontCandidate('HiraginoSans-W6', 'HiraginoSans-W6'),
    _FontCandidate('Avenir Next Rounded ★', 'Avenir Next Rounded'),
    _FontCandidate('AvenirNextRounded-Demi', 'AvenirNextRounded-Demi'),
    _FontCandidate('Avenir Next', 'Avenir Next'),
    _FontCandidate('Helvetica Neue', 'Helvetica Neue'),
    _FontCandidate('Apple SD Gothic Neo', 'Apple SD Gothic Neo'),
    _FontCandidate('Klee', 'Klee'),
    _FontCandidate('Marker Felt', 'Marker Felt'),
    _FontCandidate('Noteworthy', 'Noteworthy'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('フォントラボ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          final c = _candidates[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SampleButton(fontFamily: c.fontFamily, weight: FontWeight.w500, weightLabel: '500'),
                  _SampleButton(fontFamily: c.fontFamily, weight: FontWeight.w600, weightLabel: '600'),
                  _SampleButton(fontFamily: c.fontFamily, weight: FontWeight.w700, weightLabel: '700'),
                  _SampleButton(fontFamily: c.fontFamily, weight: FontWeight.w800, weightLabel: '800'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FontCandidate {
  final String label;
  final String? fontFamily;
  const _FontCandidate(this.label, this.fontFamily);
}

class _SampleButton extends StatelessWidget {
  final String? fontFamily;
  final FontWeight weight;
  final String weightLabel;

  const _SampleButton({
    required this.fontFamily,
    required this.weight,
    required this.weightLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('w$weightLabel',
            style: const TextStyle(fontSize: 9, color: Colors.black45)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0x66999999), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.add_circled,
                      size: 15, color: Colors.blue),
                  const SizedBox(width: 5),
                  Text('このフォルダに',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: weight,
                        fontFamily: fontFamily,
                        color: Colors.blue,
                        height: 1.0,
                      )),
                ],
              ),
              const SizedBox(height: 2),
              Text('メモ作成',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: weight,
                    fontFamily: fontFamily,
                    color: Colors.blue,
                    height: 1.0,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
