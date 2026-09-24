import 'package:equatable/equatable.dart';

class FarmTransfer extends Equatable {
  const FarmTransfer({
    required this.id,
    required this.farmId,
    required this.fromUserId,
    required this.toUserId,
    required this.expiresAt,
    required this.createdAt,
  });

  final int id;
  final int farmId;
  final int fromUserId;
  final int toUserId;
  final DateTime expiresAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, farmId, fromUserId, toUserId, expiresAt, createdAt];
}
