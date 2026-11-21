import 'package:flutter_test/flutter_test.dart';
import 'package:foodplaner/core/local/document_store.dart';

void main() {
  test('upsert stores and logs a change', () {
    final store = LocalDocumentStore();
    final e = DocEntity(
      type: 'plans',
      id: 'p1',
      data: {'name': 'P'},
      updatedAt: '2026-01-01T00:00:00Z',
      version: 1,
    );
    expect(store.upsert(e), isTrue);
    expect(store.get('plans', 'p1'), isNotNull);
    expect(store.changesSince('').length, 1);
  });

  test('upsert is last-write-wins (stale ignored)', () {
    final store = LocalDocumentStore();
    store.upsert(DocEntity(
        type: 'plans',
        id: 'p1',
        data: {'v': 2},
        updatedAt: '2026-01-02T00:00:00Z',
        version: 2));
    // older update
    final applied = store.upsert(DocEntity(
        type: 'plans',
        id: 'p1',
        data: {'v': 1},
        updatedAt: '2026-01-01T00:00:00Z',
        version: 1));
    expect(applied, isFalse);
    expect(store.get('plans', 'p1')!.data['v'], 2);
    // only one change logged
    expect(store.changesSince('').length, 1);
  });

  test('changesSince filters by timestamp', () {
    final store = LocalDocumentStore();
    store.upsert(DocEntity(
        type: 'plans', id: 'a', data: {}, updatedAt: '2026-01-01T00:00:00Z', version: 1));
    store.upsert(DocEntity(
        type: 'plans', id: 'b', data: {}, updatedAt: '2026-01-03T00:00:00Z', version: 1));
    final since = store.changesSince('2026-01-02T00:00:00Z');
    expect(since.length, 1);
    expect(since.single.id, 'b');
  });

  test('delete removes and logs', () {
    final store = LocalDocumentStore();
    final e = DocEntity(
        type: 'plans', id: 'p1', data: {}, updatedAt: '2026-01-01T00:00:00Z', version: 1);
    store.upsert(e);
    store.delete(e);
    expect(store.get('plans', 'p1'), isNull);
    expect(store.changesSince('').last.op, 'delete');
  });
}
