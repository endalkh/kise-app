/// Units-of-measurement data source: list and create.
///
/// Units are global and seedable on the server, and an admin can add more. The picker on an expense
/// form reads [list]; [create] adds a custom unit. There is no delete — a unit an expense was
/// recorded against must never dangle.
library;

import '../api_client.dart';

class UnitDto {
  const UnitDto({
    required this.id,
    required this.code,
    required this.name,
    required this.nameAm,
    required this.isSystem,
  });

  final String id;
  final String code;
  final String name;
  final String? nameAm;
  final bool isSystem;

  /// The label to show, preferring Amharic when asked and present.
  String label({bool amharic = false}) => amharic && nameAm != null ? nameAm! : name;

  factory UnitDto.fromJson(Map<String, Object?> json) => UnitDto(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        nameAm: json['name_am'] as String?,
        isSystem: json['is_system'] as bool,
      );
}

class UnitsApi {
  UnitsApi(this._client);

  final ApiClient _client;

  Future<List<UnitDto>> list() async {
    final data = await _client.get('/api/units');
    return (data as List)
        .map((item) => UnitDto.fromJson((item as Map).cast<String, Object?>()))
        .toList();
  }

  Future<UnitDto> create({
    required String code,
    required String name,
    String? nameAm,
  }) async {
    final data = await _client.post('/api/units', body: {
      'code': code,
      'name': name,
      if (nameAm != null) 'name_am': nameAm,
    });
    return UnitDto.fromJson((data as Map).cast<String, Object?>());
  }
}
