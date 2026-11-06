import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// An ephemeral selected JPEG/PNG. Bytes are never persisted by this model.
class CapturedPhoto {
  const CapturedPhoto({
    required this.bytes,
    required this.mimeType,
    required this.source,
  });

  final Uint8List bytes;
  final String mimeType;
  final PhotoSource source;
}

enum PhotoSource { camera, gallery, recovered }

/// Injectable boundary for testing without invoking device plugins.
abstract interface class PhotoSelectionService {
  Future<CapturedPhoto?> select(PhotoSource source);
}

/// Recovery is separate from selection to allow isolated testing.
/// Recovered images never imply renewed consent.
abstract interface class PhotoRecoveryService {
  Future<CapturedPhoto?> recoverLostPhoto();
}

/// Uses the system picker. Uploads only happen after separate user consent.
class ImagePickerPhotoSelectionService
    implements PhotoSelectionService, PhotoRecoveryService {
  ImagePickerPhotoSelectionService([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const maxBytes = 700000;

  @override
  Future<CapturedPhoto?> select(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 65,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return _readSelectedPhoto(file, source);
  }

  @override
  Future<CapturedPhoto?> recoverLostPhoto() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) {
      throw const FormatException('Recovering photo failed');
    }
    final files = response.files;
    if (files == null || files.isEmpty) return null;
    if (files.length != 1) {
      throw const FormatException('Ambiguous recovered image selection');
    }
    return _readSelectedPhoto(files.single, PhotoSource.recovered);
  }

  Future<CapturedPhoto> _readSelectedPhoto(
    XFile file,
    PhotoSource source,
  ) async {
    if (await file.length() > maxBytes) {
      throw const FormatException('Photo exceeds 700 KB after resizing');
    }
    final bytes = await file.readAsBytes();
    return fromBytes(bytes, source);
  }

  static CapturedPhoto fromBytes(Uint8List bytes, PhotoSource source) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Invalid photo size');
    }
    // Prefer binary signature over a user-controlled file name/extension.
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return CapturedPhoto(
        bytes: bytes,
        mimeType: 'image/jpeg',
        source: source,
      );
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return CapturedPhoto(
        bytes: bytes,
        mimeType: 'image/png',
        source: source,
      );
    }
    throw const FormatException('Unsupported photo format');
  }
}
