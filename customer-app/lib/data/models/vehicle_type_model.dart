/// Vehicle type returned by GET /content/vehicle-types
class VehicleTypeModel {
  const VehicleTypeModel({
    required this.id,
    required this.name,
    this.category = 'ride',
    this.baseFare = 0,
    this.perKmRate = 0,
    this.perStopFee = 0,
    this.isActive = true,
    this.description,
    this.icon,
  });

  final String id;
  final String name;
  final String category;    // 'ride' | 'delivery'
  final double baseFare;
  final double perKmRate;
  final double perStopFee;
  final bool isActive;
  final String? description;
  final String? icon;

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static bool _toIsActive(dynamic v) {
    if (v == null) return true;
    if (v is bool) return v;
    if (v is num) return v.toInt() == 1;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return true;
  }

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) =>
      VehicleTypeModel(
        id:          json['id']?.toString() ?? '',
        name:        json['name']?.toString() ?? '',
        category:    json['category']?.toString() ?? 'ride',
        baseFare:    _toDouble(json['base_fare']),
        perKmRate:   _toDouble(json['per_km_rate']),
        perStopFee:  _toDouble(json['per_stop_fee']),
        isActive:    _toIsActive(json['is_active']),
        description: json['description']?.toString(),
        icon:        json['icon']?.toString(),
      );
}
