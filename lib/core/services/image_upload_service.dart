import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Shared service for picking and uploading images to Firebase Storage.
///
/// Logo images are validated to be between 20 KB and 50 KB.
/// Banner images have no specific size restriction.
class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Minimum logo file size in bytes (20 KB).
  static const int logoMinBytes = 20 * 1024;

  /// Maximum logo file size in bytes (50 KB).
  static const int logoMaxBytes = 50 * 1024;

  /// Pick an image from the gallery.
  ///
  /// [maxWidth] and [maxHeight] control the resize dimensions.
  /// [imageQuality] (0–100) controls JPEG compression.
  Future<File?> pickImage({
    double maxWidth = 512,
    double maxHeight = 512,
    int imageQuality = 80,
  }) async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Pick a logo image with 20-50 KB size enforcement.
  ///
  /// Returns the [File] if within limits, or `null` if the user cancelled.
  /// Throws a [LogoSizeException] if the file is outside the allowed range.
  Future<File?> pickLogoImage() async {
    // Use lower quality / smaller dimensions to help stay within 50 KB.
    final file = await pickImage(
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 60,
    );
    if (file == null) return null;

    final sizeBytes = await file.length();
    if (sizeBytes < logoMinBytes) {
      throw LogoSizeException(
        'Logo image is too small (${(sizeBytes / 1024).toStringAsFixed(1)} KB). '
        'Please use an image between 20 KB and 50 KB.',
      );
    }
    if (sizeBytes > logoMaxBytes) {
      throw LogoSizeException(
        'Logo image is too large (${(sizeBytes / 1024).toStringAsFixed(1)} KB). '
        'Please use an image between 20 KB and 50 KB.',
      );
    }
    return file;
  }

  /// Pick a banner image (no strict size limits, just reasonable dimensions).
  Future<File?> pickBannerImage() async {
    return pickImage(
      maxWidth: 1200,
      maxHeight: 400,
      imageQuality: 75,
    );
  }

  /// Upload [file] to Firebase Storage at the given [storagePath].
  ///
  /// Returns the public download URL on success.
  Future<String> uploadFile(File file, String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return uploadTask.ref.getDownloadURL();
  }

  /// Convenience: pick a logo, validate size, upload to Firebase Storage,
  /// and return the download URL.
  ///
  /// [uid] is the library owner's UID used to scope the storage path.
  Future<String?> pickAndUploadLogo(String uid) async {
    final file = await pickLogoImage();
    if (file == null) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'library_images/$uid/logo_$ts.jpg';
    return uploadFile(file, path);
  }

  /// Convenience: pick a banner, upload to Firebase Storage,
  /// and return the download URL.
  Future<String?> pickAndUploadBanner(String uid) async {
    final file = await pickBannerImage();
    if (file == null) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'library_images/$uid/banner_$ts.jpg';
    return uploadFile(file, path);
  }
}

/// Exception thrown when the logo image size is outside the 20-50 KB range.
class LogoSizeException implements Exception {
  final String message;
  const LogoSizeException(this.message);

  @override
  String toString() => message;
}

/// Riverpod provider for [ImageUploadService].
final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});
