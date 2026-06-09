class DriverModel {
  const DriverModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.email,
    required this.isOnline,
    required this.kycStatus,
    this.state,
    this.lga,
    this.photo,
    this.rating,
    this.ratingCount = 0,
    this.vehicleId,
  });

  final String  id;
  final String  phone;
  final String  name;
  final String  email;
  final bool    isOnline;
  final String  kycStatus;   // not_submitted | pending | rejected | verified
  final String? state;
  final String? lga;
  final String? photo;
  final double? rating;
  final int     ratingCount;
  final String? vehicleId;

  bool get isVerified    => kycStatus == 'verified';
  bool get isPendingKyc  => kycStatus == 'pending';
  bool get isKycRejected => kycStatus == 'rejected';
  bool get needsKyc      => kycStatus == 'not_submitted' || kycStatus == 'rejected';

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final name  = (json['name'] ?? json['full_name'] ?? json['fullname'] ?? '').toString();
    final phone = (json['phone'] ?? json['phone_number'] ?? '').toString();
    final email = (json['email'] ?? '').toString();

    final onlineRaw = json['is_online'];
    final isOnline = switch (onlineRaw) {
      bool v   => v,
      int v    => v == 1,
      String v => v == '1' || v.toLowerCase() == 'true',
      _        => false,
    };

    final kycRaw = (json['kyc_status'] ?? 'not_submitted').toString();
    final kycStatus = ['not_submitted', 'pending', 'rejected', 'verified'].contains(kycRaw)
        ? kycRaw
        : 'not_submitted';

    double? rating;
    final ratingRaw = json['rating'];
    if (ratingRaw != null) {
      rating = double.tryParse(ratingRaw.toString());
    }

    return DriverModel(
      id:          json['id']?.toString()         ?? '',
      phone:       phone,
      name:        name,
      email:       email,
      isOnline:    isOnline,
      kycStatus:   kycStatus,
      state:       json['state']?.toString(),
      lga:         json['lga']?.toString(),
      photo:       json['photo']?.toString(),
      rating:      rating,
      ratingCount: int.tryParse(json['rating_count']?.toString() ?? '0') ?? 0,
      vehicleId:   json['vehicle_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':           id,
        'phone':        phone,
        'name':         name,
        'email':        email,
        'is_online':    isOnline,
        'kyc_status':   kycStatus,
        if (state     != null) 'state':       state,
        if (lga       != null) 'lga':         lga,
        if (photo     != null) 'photo':       photo,
        if (rating    != null) 'rating':      rating,
        'rating_count': ratingCount,
        if (vehicleId != null) 'vehicle_id':  vehicleId,
      };

  DriverModel copyWith({
    String?  id,
    String?  phone,
    String?  name,
    String?  email,
    bool?    isOnline,
    String?  kycStatus,
    String?  state,
    String?  lga,
    String?  photo,
    double?  rating,
    int?     ratingCount,
    String?  vehicleId,
  }) => DriverModel(
        id:          id          ?? this.id,
        phone:       phone       ?? this.phone,
        name:        name        ?? this.name,
        email:       email       ?? this.email,
        isOnline:    isOnline    ?? this.isOnline,
        kycStatus:   kycStatus   ?? this.kycStatus,
        state:       state       ?? this.state,
        lga:         lga         ?? this.lga,
        photo:       photo       ?? this.photo,
        rating:      rating      ?? this.rating,
        ratingCount: ratingCount ?? this.ratingCount,
        vehicleId:   vehicleId   ?? this.vehicleId,
      );
}
