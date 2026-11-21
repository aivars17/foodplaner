/// A family member with optional per-person dietary restrictions.
class FamilyMember {
  final String id;
  final String name;
  final List<String> dietary; // e.g. ["vegetarian"], ["be glitimo"]

  const FamilyMember({
    required this.id,
    required this.name,
    this.dietary = const [],
  });

  FamilyMember copyWith({String? name, List<String>? dietary}) =>
      FamilyMember(
        id: id,
        name: name ?? this.name,
        dietary: dietary ?? this.dietary,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dietary': dietary,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        dietary: (j['dietary'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  static List<FamilyMember> listFromJson(List<dynamic>? arr) {
    if (arr == null) return [];
    return arr
        .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

/// The single shared household configuration (synced).
class HouseholdSettings {
  final String id; // always "default"
  final List<String> dietary; // global restrictions
  final List<FamilyMember> members;
  final int defaultServings;
  final List<String> onHand; // ingredients already available
  final String updatedAt;
  final int version;

  const HouseholdSettings({
    this.id = 'default',
    this.dietary = const [],
    this.members = const [],
    this.defaultServings = 1,
    this.onHand = const [],
    required this.updatedAt,
    required this.version,
  });

  HouseholdSettings copyWith({
    List<String>? dietary,
    List<FamilyMember>? members,
    int? defaultServings,
    List<String>? onHand,
    String? updatedAt,
    int? version,
  }) =>
      HouseholdSettings(
        id: id,
        dietary: dietary ?? this.dietary,
        members: members ?? this.members,
        defaultServings: defaultServings ?? this.defaultServings,
        onHand: onHand ?? this.onHand,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );

  int get memberCount => members.isEmpty ? 1 : members.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dietary': dietary,
        'members': members.map((e) => e.toJson()).toList(),
        'defaultServings': defaultServings,
        'onHand': onHand,
        'updatedAt': updatedAt,
        'version': version,
      };

  factory HouseholdSettings.fromJson(Map<String, dynamic> j) =>
      HouseholdSettings(
        id: (j['id'] ?? 'default').toString(),
        dietary: (j['dietary'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        members: FamilyMember.listFromJson(j['members'] as List<dynamic>?),
        defaultServings: (j['defaultServings'] ?? 1) as int,
        onHand: (j['onHand'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        updatedAt: (j['updatedAt'] ?? '').toString(),
        version: (j['version'] ?? 0) as int,
      );
}
