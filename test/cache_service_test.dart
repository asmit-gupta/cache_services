import 'package:cache_service/cache_service.dart';
import 'package:test/test.dart';

void main() {
  test('Concurrent in-memory cache operations', () async {
    final cacheService = CacheService();

    await Future.wait([
      Future(() => cacheService.addItem({'id': '1', 'value': 'test1'})),
      Future(() => cacheService.addItem({'id': '2', 'value': 'test2'})),
      Future(() => cacheService.updateItem({'id': '1', 'value': 'updated'})),
      Future(() => cacheService.removeItemFromMemory('2')),
    ]);

    expect(cacheService.getItem('1'), {'id': '1', 'value': 'updated'});
    expect(cacheService.getItem('2'), isNull);
  });
}
