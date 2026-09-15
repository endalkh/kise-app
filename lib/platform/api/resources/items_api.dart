/// Items data source: list, create, get, and the archive-or-delete removal.
///
/// Items are the things the owner buys, picked (or created on the fly) when recording an expense.
/// [remove] mirrors the backend: `204` (deleted, returns null) when nothing uses the item, `200`
/// with the archived item when expenses reference it.
library;

import '../api_client.dart';

class ItemDto {
  const ItemDto({
    required this.id,
    required this.name,
    required this.nameAm,
    required this.defaultUnitId,
    required this.isArchived,
  });

  final String id;
  final String name;
  final String? nameAm;
  final String? defaultUnitId;
  final bool isArchived;

  String label({bool amharic = false}) => amharic && nameAm != null ? nameAm! : name;

  factory ItemDto.fromJson(Map<String, Object?> json) => ItemDto(
        id: json['id'] as String,
        name: json['name'] as String,
        nameAm: json['name_am'] as String?,
        defaultUnitId: json['default_unit_id'] as String?,
        isArchived: json['is_archived'] as bool,
      );
}

class ItemsApi {
  ItemsApi(this._client);

  final ApiClient _client;

  Future<List<ItemDto>> list({bool includeArchived = false}) async {
    final data = await _client.get('/api/items', query: {'include_archived': includeArchived});
    return (data as List)
        .map((item) => ItemDto.fromJson((item as Map).cast<String, Object?>()))
        .toList();
  }

  Future<ItemDto> create({
    required String name,
    String? nameAm,
    String? defaultUnitId,
  }) async {
    final data = await _client.post('/api/items', body: {
      'name': name,
      if (nameAm != null) 'name_am': nameAm,
      if (defaultUnitId != null) 'default_unit_id': defaultUnitId,
    });
    return ItemDto.fromJson((data as Map).cast<String, Object?>());
  }

  Future<ItemDto> get(String id) async {
    final data = await _client.get('/api/items/$id');
    return ItemDto.fromJson((data as Map).cast<String, Object?>());
  }

  /// Null when deleted (204); the archived item when it was in use (200).
  Future<ItemDto?> remove(String id) async {
    final data = await _client.delete('/api/items/$id');
    if (data is Map) return ItemDto.fromJson(data.cast<String, Object?>());
    return null;
  }
}
