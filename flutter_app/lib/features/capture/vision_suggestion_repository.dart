import 'dart:convert';
import 'dart:typed_data';

import 'package:curio/features/capture/capture_suggestion.dart';
import 'package:curio/features/taxonomy/template_catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An opt-in vision request. No media is kept in memory by this repository
/// after the request is completed. Never call it automatically on page load.
abstract interface class VisionSuggestionRepository {
  Future<CaptureSuggestion> analyze({
    required Uint8List imageBytes,
    required String mimeType,
    required List<StandardObjectTemplate> templates,
  });
}

class SupabaseVisionSuggestionRepository implements VisionSuggestionRepository {
  SupabaseVisionSuggestionRepository(this._client);
  final SupabaseClient _client;

  static String imageDataUrl(Uint8List bytes, String mimeType) {
    if (bytes.isEmpty || bytes.length > 700000) {
      throw ArgumentError('Image must be under 700 KB');
    }
    if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
      throw ArgumentError('Only JPEG/PNG supported');
    }
    final jpeg = bytes.length >= 3 &&
        bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    final png = bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e &&
        bytes[3] == 0x47 && bytes[4] == 0x0d && bytes[5] == 0x0a &&
        bytes[6] == 0x1a && bytes[7] == 0x0a;
    if ((mimeType == 'image/jpeg' && !jpeg) ||
        (mimeType == 'image/png' && !png)) {
      throw ArgumentError('Unsupported image data');
    }
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  @override
  Future<CaptureSuggestion> analyze({
    required Uint8List imageBytes,
    required String mimeType,
    required List<StandardObjectTemplate> templates,
  }) async {
    if (templates.isEmpty || templates.length > 12) {
      throw ArgumentError('Expected 1-12 templates');
    }
    final dataUrl = imageDataUrl(imageBytes, mimeType);
    final result = await _client.functions.invoke(
      'kovunela-vision-analyze',
      body: {
        'image_data_url': dataUrl,
        'templates': templates.map((template) => {
          'code': template.code,
          'fields': template.fields,
        }).toList(),
      },
    );
    final payload = result.data;
    if (result.status != 200 || payload is! Map ||
        payload['source'] != 'openai_vision' ||
        payload['requires_review'] != true) {
      throw StateError('Vision analysis unavailable');
    }
    return CaptureSuggestion.fromJson(Map<String, dynamic>.from(payload));
  }
}
