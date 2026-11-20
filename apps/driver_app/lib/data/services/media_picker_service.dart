import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// In-memory representation of a user-selected image/file ready for upload to
/// Supabase Storage.
class PickedMediaFile {
  const PickedMediaFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;

  String get extension {
    final idx = fileName.lastIndexOf('.');
    if (idx == -1 || idx == fileName.length - 1) return 'jpg';
    return fileName.substring(idx + 1).toLowerCase();
  }
}

/// Media selection source abstraction for camera/gallery uploads.
abstract class DriverMediaPicker {
  Future<PickedMediaFile?> pickImage({required ImageSource source});
  Future<List<PickedMediaFile>> pickMultiImage();
}

/// Production [DriverMediaPicker] backed by `image_picker`.
class ImagePickerDriverMedia implements DriverMediaPicker {
  ImagePickerDriverMedia({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static String inferMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Future<PickedMediaFile> _fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final safeName = file.name.trim().isEmpty
        ? 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : file.name.trim();
    return PickedMediaFile(
      bytes: bytes,
      fileName: safeName,
      contentType: inferMimeType(safeName),
    );
  }

  @override
  Future<PickedMediaFile?> pickImage({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return null;
    return _fromXFile(picked);
  }

  @override
  Future<List<PickedMediaFile>> pickMultiImage() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked.isEmpty) return const <PickedMediaFile>[];
    final files = <PickedMediaFile>[];
    for (final item in picked) {
      files.add(await _fromXFile(item));
    }
    return files;
  }
}
