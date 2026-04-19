import 'dart:io';

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

  /// 保存先のディレクトリ（存在しなければ作成）
  static Future<Directory> _imagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _subDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
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
  static Future<String> absolutePath(String relativePath) async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, relativePath);
  }

  /// 実ファイル削除（DBレコード削除とは別に呼ぶ）
  static Future<void> deleteFile(String relativePath) async {
    final abs = await absolutePath(relativePath);
    final file = File(abs);
    if (await file.exists()) await file.delete();
  }
}
