import 'dart:convert';
import 'dart:io';

/// A typed JSON document, mirroring the server's wire format.
class DocEntity {
  final String type;
  final String id;
  final Map<String, dynamic> data;
  final String updatedAt; // RFC3339 UTC
  final int version;

  const DocEntity({
    required this.type,
    required this.id,
    required this.data,
    required this.updatedAt,
    required this.version,
  });

  DocEntity copyWith({
    Map<String, dynamic>? data,
    String? updatedAt,
    int? version,
  }) =>
      DocEntity(
        type: type,
        id: id,
        data: data ?? this.data,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'data': data,
        'updatedAt': updatedAt,
        'version': version,
      };

  factory DocEntity.fromJson(Map<String, dynamic> j) => DocEntity(
        type: (j['type'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
        data: Map<String, dynamic>.from(j['data'] as Map? ?? const {}),
        updatedAt: (j['updatedAt'] ?? '').toString(),
        version: (j['version'] ?? 0) as int,
      );

  static String key(String type, String id) => '$type/$id';
}

/// A single changelog record.
class DocChange {
  final String type;
  final String id;
  final String op; // 'upsert' | 'delete'
  final Map<String, dynamic> data; // full body on upsert, empty on delete
  final String updatedAt;
  final int version;

  const DocChange({
    required this.type,
    required this.id,
    required this.op,
    required this.updatedAt,
    required this.version,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'op': op,
        'data': data,
        'updatedAt': updatedAt,
        'version': version,
      };

  factory DocChange.fromJson(Map<String, dynamic> j) => DocChange(
        type: (j['type'] ?? '').toString(),
        id: (j['id'] ?? '').toString(),
        op: (j['op'] ?? 'upsert').toString(),
        data: j['data'] is Map
            ? Map<String, dynamic>.from(j['data'] as Map)
            : const {},
        updatedAt: (j['updatedAt'] ?? '').toString(),
        version: (j['version'] ?? 0) as int,
      );
}

/// A local, offline document store. Pure in-memory logic with optional file
/// persistence — the manipulation logic is unit-testable without Flutter.
class LocalDocumentStore {
  final Map<String, DocEntity> _entities = {};
  final List<DocChange> _changelog = [];
  String? _path;

  /// Put a document with last-write-wins (ignores stale updates).
  bool upsert(DocEntity e) {
    final key = DocEntity.key(e.type, e.id);
    final existing = _entities[key];
    if (existing != null && existing.updatedAt > e.updatedAt) {
      return false; // stale
    }
    _entities[key] = e;
    _changelog.add(DocChange(
      type: e.type,
      id: e.id,
      op: 'upsert',
      updatedAt: e.updatedAt,
      version: e.version,
    ));
    _dirty = true;
    return true;
  }

  void delete(DocEntity e) {
    final key = DocEntity.key(e.type, e.id);
    _entities.remove(key);
    _changelog.add(DocChange(
      type: e.type,
      id: e.id,
      op: 'delete',
      updatedAt: e.updatedAt,
      version: e.version,
    ));
    _dirty = true;
  }

  DocEntity? get(String type, String id) =>
      _entities[DocEntity.key(type, id)];

  List<DocEntity> allOfType(String type) =>
      _entities.values.where((e) => e.type == type).toList();

  DocChange? lastChange() {
    if (_changelog.isEmpty) return null;
    return _changelog.last;
  }

  List<DocChange> changesSince(String since) {
    if (since.isEmpty) return List.of(_changelog);
    return _changelog
        .where((c) => c.updatedAt > since)
        .toList();
  }

  /// Load persisted documents from [path] (if set). No-op when path is null.
  Future<void> load(String? path) async {
    _path = path;
    if (path == null) return;
    final f = File(path);
    if (!await f.exists()) return;
    final raw = await f.readAsString();
    if (raw.trim().isEmpty) return;
    final j = jsonDecode(raw);
    final entities = (j['entities'] as Map?).map((k, v) =>
        MapEntry(k as String, DocEntity.fromJson(Map<String, dynamic>.from(v as Map))));
    entities?.forEach((k, e) => _entities[k] = e);
    final changes = (j['changelog'] as List?)?.cast<Map>() ?? const [];
    for (final c in changes) {
      _changelog.add(DocChange.fromJson(Map<String, dynamic>.from(c)));
    }
  }

  /// Persist to disk. No-op when no path is set.
  Future<void> save() async {
    if (_path == null) return;
    final j = {
      'entities': _entities.map(
        (k, e) => MapEntry(k, e.toJson()),
      ),
      'changelog': _changelog.map((c) => c.toJson()).toList(),
    };
    await File(_path!).writeAsString(jsonEncode(j));
    _dirty = false;
  }

  bool _dirty = false;
  bool get isDirty => _dirty;

  Map<String, DocEntity> get entitiesForTest => _entities;
  List<DocChange> get changelogForTest => _changelog;
}
