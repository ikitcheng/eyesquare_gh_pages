class ParkingSpace {
  final int id;
  final String parkingName;
  final DateTime refreshTime;
  final String vehicleSpace;
  final String eVehicleSpace;
  final String motorcycleSpace;  // 保持這個名稱不變
  final String eMotorcycleSpace; // 保持這個名稱不變
  final double latitude;
  final double longitude;
  final bool isRoadside;

  ParkingSpace({
    required this.id,
    required this.parkingName,
    required this.refreshTime,
    required this.vehicleSpace,
    required this.eVehicleSpace,
    required this.motorcycleSpace,
    required this.eMotorcycleSpace,
    required this.latitude,
    required this.longitude,
    required this.isRoadside,
  });

  factory ParkingSpace.fromJson(Map<String, dynamic> json) {
    return ParkingSpace(
      id: json['id'],
      parkingName: json['parking_name'] ?? '',
      refreshTime: DateTime.parse(json['refresh_time']),
      vehicleSpace: _parseDoubleSafely(json['vehicle_space']).toString() ?? '',
      eVehicleSpace: _parseDoubleSafely(json['e_vehicle_space']).toString() ?? '',
      motorcycleSpace: _parseDoubleSafely(json['motocycle_space']).toString() ?? '',  // 注意這裡的改變
      eMotorcycleSpace: _parseDoubleSafely(json['e_motocycle_space']).toString() ?? '',  // 注意這裡的改變
      latitude: _parseDoubleSafely(json['latitude']),
      longitude: _parseDoubleSafely(json['longitude']),
      isRoadside: json['is_roadside'] ?? false,
    );
  }

  static double _parseDoubleSafely(dynamic value) {
    if (value == null) return -1;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? -1;
    }
    return 0.0;
  }
}