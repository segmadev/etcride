import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class AccountDeletionRequest {
  final String id;
  final String status; // pending, approved, rejected
  final String? reason;
  final String? createdAt;
  final String? reviewedAt;
  final String? adminNotes;
  final String? deletedAt;

  AccountDeletionRequest({
    required this.id,
    required this.status,
    this.reason,
    this.createdAt,
    this.reviewedAt,
    this.adminNotes,
    this.deletedAt,
  });

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString(),
      createdAt: json['created_at']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

class AccountDeletionRepository {
  const AccountDeletionRepository(this._client);

  final ApiClient _client;

  /// Request account deletion with optional reason
  Future<AccountDeletionRequest> requestDeletion({String reason = ''}) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/account/delete-request',
      body: {'deletion_reason': reason},
    );
    if (data == null) throw const FormatException('Empty response.');
    return AccountDeletionRequest.fromJson(data);
  }

  /// Get current account deletion request status
  Future<AccountDeletionRequest> getRequestStatus() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/account/delete-request',
    );
    if (data == null) throw const FormatException('Empty response.');
    return AccountDeletionRequest.fromJson(data);
  }

  /// Cancel a pending deletion request
  Future<void> cancelRequest() async {
    await _client.delete('/account/delete-request');
  }
}
