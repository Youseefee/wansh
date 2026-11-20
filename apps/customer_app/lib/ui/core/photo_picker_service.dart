import 'package:image_picker/image_picker.dart';

import '../../data/repositories/models.dart';

/// Abstraction over `image_picker` so views and viewmodels stay decoupled
/// from platform channels during tests.
abstract class PhotoPickerService {
  Future<SelectedPhotoBytes?> pickFromCamera();
  Future<List<SelectedPhotoBytes>> pickMultipleFromGallery({int limit = 4});
  Future<SelectedPhotoBytes?> pickSingleFromGallery();
}

/// Platform implementation backed by [ImagePicker].
class ImagePickerService implements PhotoPickerService {
  ImagePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<SelectedPhotoBytes> _toSelectedPhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
    final lower = name.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    return SelectedPhotoBytes(
      fileName: name,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<SelectedPhotoBytes?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null) return null;
    return _toSelectedPhoto(file);
  }

  @override
  Future<List<SelectedPhotoBytes>> pickMultipleFromGallery({
    int limit = 4,
  }) async {
    final files = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
      limit: limit,
    );
    final result = <SelectedPhotoBytes>[];
    for (final file in files) {
      result.add(await _toSelectedPhoto(file));
    }
    return result;
  }

  @override
  Future<SelectedPhotoBytes?> pickSingleFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null) return null;
    return _toSelectedPhoto(file);
  }
}
