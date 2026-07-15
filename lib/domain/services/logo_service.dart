import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Picks a logo image via `image_picker`, copies it into the app's docs
/// directory (so it survives reinstalls of the source app / picker cache
/// being cleared), and returns the absolute path. Returns null if the
/// user cancels.
///
/// Stored under `<docs>/logos/<uuid>.<ext>` to avoid filename collisions.
class LogoService {
  LogoService._();

  static final _picker = ImagePicker();

  /// Picks an image from the gallery. Returns the local file path, or null
  /// if the user cancelled.
  static Future<String?> pickFromGallery() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xfile == null) return null;
    return _saveToDocs(xfile);
  }

  /// Picks an image via the camera.
  static Future<String?> pickFromCamera() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xfile == null) return null;
    return _saveToDocs(xfile);
  }

  static Future<String> _saveToDocs(XFile xfile) async {
    final docs = await getApplicationDocumentsDirectory();
    final logosDir = Directory(p.join(docs.path, 'logos'));
    if (!await logosDir.exists()) {
      await logosDir.create(recursive: true);
    }
    final ext = p.extension(xfile.path).toLowerCase();
    final filename = '${const Uuid().v4()}$ext';
    final dest = p.join(logosDir.path, filename);
    await File(xfile.path).copy(dest);
    return dest;
  }

  /// Deletes a stored logo file. Safe to call with null or non-existent path.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
