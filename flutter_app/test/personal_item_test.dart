import 'package:curio/features/capture/personal_item_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal item maps a validated server response', () {
    final item = PersonalItem.fromJson({
      'id': 'not-a-collection-id',
      'title': 'Vintage camera',
      'description': 'From the attic',
      'created_at': '2026-11-06T07:00:00Z',
    });
    expect(item.title, 'Vintage camera');
    expect(item.description, 'From the attic');
    expect(item.createdAt.isUtc, isTrue);
  });

  test('personal item supports empty optional description', () {
    final item = PersonalItem.fromJson({
      'id': 'item-id',
      'title': 'Photograph',
      'description': null,
      'created_at': '2026-11-06T07:00:00Z',
    });
    expect(item.description, isEmpty);
  });
}
