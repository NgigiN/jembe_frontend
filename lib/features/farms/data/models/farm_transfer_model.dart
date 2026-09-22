import 'package:farm_tracker/features/farms/domain/entities/farm_transfer.dart';

class FarmTransferModel extends FarmTransfer {
  const FarmTransferModel({
    required super.id,
    required super.farmId,
    required super.fromUserId,
    required super.toUserId,
    required super.expiresAt,
    required super.createdAt,
  });

  factory FarmTransferModel.fromJson(Map<String, dynamic> json) {
    return FarmTransferModel(
      id: (json['id'] as num).toInt(),
      farmId: (json['farm_id'] as num).toInt(),
      fromUserId: (json['from_user_id'] as num).toInt(),
      toUserId: (json['to_user_id'] as num).toInt(),
      expiresAt: DateTime.parse(json['expires_at'].toString()),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}
