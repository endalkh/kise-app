/// Categories data source: list, create, update, and the archive-or-delete removal.
///
/// [remove] mirrors the backend's two-outcome contract: a `204` means the category was deleted and
/// this returns null; a `200` with a body means it was archived instead (something uses it) and the
/// archived [CategoryDto] comes back, so the UI can say "archived, because it's in use".
library;

import '../api_client.dart';

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    required this.nameAm,
    required this.color,
    required this.icon,
    required this.isArchived,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String? nameAm;
  final String color;
  final String? icon;
  final bool isArchived;
  final bool isDefault;

  factory CategoryDto.fromJson(Map<String, Object?> json) => CategoryDto(
        id: json['id'] as String,
        name: json['name'] as String,
        nameAm: json['name_am'] as String?,
        color: json['color'] as String,
        icon: json['icon'] as String?,
        isArchived: json['is_archived'] as bool,
        isDefault: json['is_default'] as bool,
      );
}

class CategoriesApi {
  CategoriesApi(this._client);

  final ApiClient _client;

  Future<List<CategoryDto>> list({bool includeArchived = false}) async {
    final data = await _client.get(
      '/api/categories',
      query: {'include_archived': includeArchived},
    );
    return (data as List)
        .map((item) => CategoryDto.fromJson((item as Map).cast<String, Object?>()))
        .toList();
  }

  Future<CategoryDto> create({
    required String name,
    String? nameAm,
    String? color,
    String? icon,
  }) async {
    final data = await _client.post('/api/categories', body: {
      'name': name,
      if (nameAm != null) 'name_am': nameAm,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
    });
    return CategoryDto.fromJson((data as Map).cast<String, Object?>());
  }

  Future<CategoryDto> update(
    String id, {
    String? name,
    String? nameAm,
    String? color,
    String? icon,
  }) async {
    final data = await _client.patch('/api/categories/$id', body: {
      if (name != null) 'name': name,
      if (nameAm != null) 'name_am': nameAm,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
    });
    return CategoryDto.fromJson((data as Map).cast<String, Object?>());
  }

  /// Null when deleted (204); the archived category when it was in use (200).
  Future<CategoryDto?> remove(String id) async {
    final data = await _client.delete('/api/categories/$id');
    if (data is Map) {
      return CategoryDto.fromJson(data.cast<String, Object?>());
    }
    return null;
  }
}
