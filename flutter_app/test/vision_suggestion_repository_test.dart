import 'dart:typed_data';

import 'package:curio/features/capture/vision_suggestion_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JPEG bytes are validated before transmission to the protected function', () {
    final jpg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, ...List.filled(20, 0)]);
    final dataUrl = SupabaseVisionSuggestionRepository.imageDataUrl(
        jpg, 'image/jpeg');
    expect(dataUrl, startsWith('data:image/jpeg;base64,'));
    expect(() => SupabaseVisionSuggestionRepository.imageDataUrl(
        jpg, 'image/png'), throwsArgumentError);
  });

  test('PNG files require the actual PNG signature', () {
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0,
    ]);
    expect(SupabaseVisionSuggestionRepository.imageDataUrl(
        png, 'image/png'), startsWith('data:image/png;base64,'));
  });

  test('limits file size and supported formats before network requests', () {
    final jpg = Uint8List.fromList([0xff, 0xd8, 0xff, 0]);
    expect(() => SupabaseVisionSuggestionRepository.imageDataUrl(
        jpg, 'image/gif'), throwsArgumentError);
    expect(() => SupabaseVisionSuggestionRepository.imageDataUrl(
        Uint8List(700001), 'image/jpeg'), throwsArgumentError);
    expect(() => SupabaseVisionSuggestionRepository.imageDataUrl(
        Uint8List(0), 'image/jpeg'), throwsArgumentError);
  });
}
