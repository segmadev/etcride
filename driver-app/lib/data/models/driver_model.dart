class DriverAssignedVehicle {
  const DriverAssignedVehicle({
    required this.id,
    this.plateNumber,
    this.make,
    this.model,
    this.color,
    this.year,
    this.status,
    this.vehicleType,
    this.photoUrl,
  });

  final String id;
  final String? plateNumber;
  final String? make;
  final String? model;
  final String? color;
  final String? year;
  final String? status;
  final String? vehicleType;
  final String? photoUrl;

  String get displayName {
    final parts = [make, model]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Assigned Vehicle' : parts.join(' ');
  }

  factory DriverAssignedVehicle.fromJson(Map<String, dynamic> json) {
    return DriverAssignedVehicle(
      id: json['id']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString(),
      make: json['make']?.toString(),
      model: json['model']?.toString(),
      color: json['color']?.toString(),
      year: json['year']?.toString(),
      status: json['status']?.toString(),
      vehicleType: (json['vehicle_type'] ?? json['vehicle_type_name'])
          ?.toString(),
      photoUrl:
          (json['photo_url'] ??
                  json['image_url'] ??
                  json['photo'] ??
                  json['image'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (plateNumber != null) 'plate_number': plateNumber,
    if (make != null) 'make': make,
    if (model != null) 'model': model,
    if (color != null) 'color': color,
    if (year != null) 'year': year,
    if (status != null) 'status': status,
    if (vehicleType != null) 'vehicle_type': vehicleType,
    if (photoUrl != null) 'photo_url': photoUrl,
  };
}

class DriverModel {
  const DriverModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.email,
    required this.isOnline,
    this.kycStatus,
    this.rating,
    this.photo,
    this.drivingExperience,
    this.kycNote,
    this.assignedVehicle,
  });

  final String id;
  final String phone;
  final String name;
  final String email;
  final bool isOnline;
  final String? kycStatus; // not_submitted | pending | rejected | verified
  final double? rating;
  final String? photo;
  final String? drivingExperience;
  final String? kycNote;
  final DriverAssignedVehicle? assignedVehicle;

  bool get isKycRejected => kycStatus == 'rejected';

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['full_name'] ?? json['fullname'] ?? '')
        .toString();

    final phone =
        (json['phone'] ?? json['phone_number'] ?? json['mobile'])?.toString() ??
        '';

    final email = (json['email'] ?? json['mail'])?.toString() ?? '';

    final onlineRaw = json['is_online'];
    final isOnline = switch (onlineRaw) {
      bool v => v,
      int v => v == 1,
      String v => v == '1' || v.toLowerCase() == 'true',
      _ => false,
    };

    final ratingRaw = json['rating'] ?? json['avg_rating'];
    final rating = ratingRaw == null
        ? null
        : double.tryParse(ratingRaw.toString());

    return DriverModel(
      id: json['id']?.toString() ?? '',
      phone: phone,
      name: name,
      email: email,
      isOnline: isOnline,
      kycStatus: json['kyc_status']?.toString(),
      rating: rating,
      photo:
          (json['photo_url'] ??
                  json['photo'] ??
                  json['avatar'] ??
                  json['profile_photo_url'] ??
                  json['profile_photo'])
              ?.toString(),
      drivingExperience: json['driving_experience']?.toString(),
      kycNote: (json['kyc_note'] ?? json['rejection_reason'])?.toString(),
      assignedVehicle: json['assigned_vehicle'] is Map<String, dynamic>
          ? DriverAssignedVehicle.fromJson(
              json['assigned_vehicle'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  DriverModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    bool? isOnline,
    String? kycStatus,
    double? rating,
    String? photo,
    String? drivingExperience,
    String? kycNote,
    DriverAssignedVehicle? assignedVehicle,
  }) => DriverModel(
    id: id ?? this.id,
    phone: phone ?? this.phone,
    name: name ?? this.name,
    email: email ?? this.email,
    isOnline: isOnline ?? this.isOnline,
    kycStatus: kycStatus ?? this.kycStatus,
    rating: rating ?? this.rating,
    photo: photo ?? this.photo,
    drivingExperience: drivingExperience ?? this.drivingExperience,
    kycNote: kycNote ?? this.kycNote,
    assignedVehicle: assignedVehicle ?? this.assignedVehicle,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'email': email,
    'is_online': isOnline,
    if (kycStatus != null) 'kyc_status': kycStatus,
    if (rating != null) 'rating': rating,
    if (photo != null) 'photo': photo,
    if (drivingExperience != null) 'driving_experience': drivingExperience,
    if (kycNote != null) 'kyc_note': kycNote,
    if (assignedVehicle != null) 'assigned_vehicle': assignedVehicle!.toJson(),
  };
}
