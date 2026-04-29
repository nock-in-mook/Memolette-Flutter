import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 画像の保存・読み込みユーティリティ
///
/// - 入力: 元画像ファイル（ピッカーから受け取る XFile.path 等）
/// - 処理: 長辺 1024px にリサイズ + JPEG 70% で圧縮 → 1枚 100〜200KB 目安
/// - 保存: `Documents/memo_images/{uuid}.jpg`
/// - DB には Documents ディレクトリからの相対パスのみを保持する
///   （Documents パスは OS 再インストール等で変わることがあるため）
class ImageStorage {
  static const _uuid = Uuid();
  static const _subDir = 'memo_images';
  static const _longSide = 1024;
  static const _quality = 70;

  /// Documents ディレクトリのパスキャッシュ（グリッド内の多数カードが同じ値を
  /// 参照するため、初回取得後は同期返却で FutureBuilder のコストを軽減）
  static String? _docsPathCache;

  /// 保存先のディレクトリ（存在しなければ作成）
  static Future<Directory> _imagesDir() async {
    final docs = await _ensureDocsPath();
    final dir = Directory(p.join(docs, _subDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> _ensureDocsPath() async {
    if (_docsPathCache != null) return _docsPathCache!;
    final docs = await getApplicationDocumentsDirectory();
    _docsPathCache = docs.path;
    return docs.path;
  }

  /// 元画像を圧縮して保存。相対パス（例: "memo_images/abc.jpg"）を返す
  static Future<String?> saveCompressed(String sourcePath) async {
    final dir = await _imagesDir();
    final id = _uuid.v4();
    final target = p.join(dir.path, '$id.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      target,
      quality: _quality,
      minWidth: _longSide,
      minHeight: _longSide,
      format: CompressFormat.jpeg,
    );
    if (result == null) return null;
    return p.join(_subDir, '$id.jpg');
  }

  /// 相対パス → 絶対パス（読み込み用）
  /// キャッシュ済みなら同期的に解決されるので FutureBuilder のコストが最小化される
  static Future<String> absolutePath(String relativePath) async {
    final docs = await _ensureDocsPath();
    return p.join(docs, relativePath);
  }

  /// 同期版 absolutePath: Documents パスがキャッシュ済みなら即座に絶対パスを返す。
  /// キャッシュ未取得なら null を返す（呼び出し側で Future 経由にフォールバック）。
  /// FutureBuilder の "none → waiting → done" 遷移を踏まないので、
  /// グリッド再描画時にサムネがチカチカ点滅するのを防げる。
  static String? absolutePathSync(String relativePath) {
    final docs = _docsPathCache;
    if (docs == null) return null;
    return p.join(docs, relativePath);
  }

  /// 事前に Documents パスを温めておく（起動時に呼ぶ）
  /// 呼び忘れても absolutePath 内で初回のみ await されるので致命的ではない
  static Future<void> warmUp() => _ensureDocsPath();

  /// 任意のバイト列を memo_images/ 配下に保存。相対パスを返す
  /// （ダミーデータ生成などで圧縮を通さず直接 PNG 等を保存したいケース向け）
  static Future<String> saveBytes(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final dir = await _imagesDir();
    final id = _uuid.v4();
    final target = p.join(dir.path, '$id.$extension');
    await File(target).writeAsBytes(bytes);
    return p.join(_subDir, '$id.$extension');
  }

  /// 実ファイル削除（DBレコード削除とは別に呼ぶ）
  static Future<void> deleteFile(String relativePath) async {
    final abs = await absolutePath(relativePath);
    final file = File(abs);
    if (await file.exists()) await file.delete();
  }
}
