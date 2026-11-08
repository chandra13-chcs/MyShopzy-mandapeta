/// A signed-in delivery rider: name, phone and vehicle.
/// [vehicleType] is one of 'bike', 'scooter', 'cycle'.
class Rider {
  final String name;
  final String phone;
  final String vehicleType;
  final String vehicleNumber;

  Rider({
    required this.name,
    required this.phone,
    this.vehicleType = 'bike',
    this.vehicleNumber = '',
  });

  Rider copyWith({String? name, String? vehicleType, String? vehicleNumber}) => Rider(
        name: name ?? this.name,
        phone: phone,
        vehicleType: vehicleType ?? this.vehicleType,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
      };

  /// Old saved riders have no vehicle fields, so they get safe defaults.
  factory Rider.fromJson(Map<String, dynamic> json) => Rider(
        name: json['name'] as String,
        phone: json['phone'] as String,
        vehicleType: json['vehicleType'] as String? ?? 'bike',
        vehicleNumber: json['vehicleNumber'] as String? ?? '',
      );
}
