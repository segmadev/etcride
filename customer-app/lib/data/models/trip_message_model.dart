/// A single chat message exchanged between customer and driver on a booking.
class TripMessageModel {
  const TripMessageModel({
    required this.id,
    required this.bookingId,
    required this.senderRole,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String senderRole; // 'customer' | 'driver'
  final String senderId;
  final String body;
  final DateTime createdAt;

  bool get isMine => senderRole == 'customer';

  factory TripMessageModel.fromJson(Map<String, dynamic> json) {
    return TripMessageModel(
      id:         json['id']?.toString() ?? '',
      bookingId:  json['booking_id']?.toString() ?? '',
      senderRole: json['sender_role']?.toString() ?? '',
      senderId:   json['sender_id']?.toString() ?? '',
      body:       json['body']?.toString() ?? '',
      createdAt:  DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
