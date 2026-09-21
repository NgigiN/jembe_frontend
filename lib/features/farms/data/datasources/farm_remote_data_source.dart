import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farms/data/models/farm_invitation_model.dart';
import 'package:farm_tracker/features/farms/data/models/farm_member_model.dart';
import 'package:farm_tracker/features/farms/data/models/farm_model.dart';
import 'package:farm_tracker/features/farms/data/models/farm_transfer_model.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

abstract class FarmRemoteDataSource {
  Future<List<FarmModel>> listFarms();
  Future<FarmModel> createFarm({
    required String name,
    required String location,
    required int fiscalYearStartMonth,
  });
  Future<FarmModel> getCurrentFarm();
  Future<List<FarmMemberModel>> listMembers();
  Future<void> updateMemberRole(int userId, FarmRole role);
  Future<void> removeMember(int userId);
  Future<List<FarmInvitationModel>> listInvitations();
  Future<FarmInvitationModel> createInvitation(String email, FarmRole role);
  Future<void> revokeInvitation(int id);
  Future<void> setSuccessor(int? userId);
  Future<FarmTransferModel?> getTransfer();
  Future<FarmTransferModel> nominateTransfer(int userId);
  Future<void> cancelTransfer();
  Future<void> acceptTransfer();
}

class FarmRemoteDataSourceImpl implements FarmRemoteDataSource {
  FarmRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  // Lets 4xx responses through as a normal Response (instead of Dio
  // throwing a generic DioException) so _throwIfNotOk can surface the
  // server's actual error message via extractServerErrorMessage, matching
  // every other remote data source in this codebase.
  static Options get _permissive =>
      Options(validateStatus: (status) => status != null && status < 500);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  void _throwIfNotOk(Response<dynamic> response, Set<int> okStatuses) {
    if (!okStatuses.contains(response.statusCode)) {
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    }
  }

  @override
  Future<List<FarmModel>> listFarms() => _guard(() async {
    final response = await dio.get<dynamic>('/api/v1/farms', options: _permissive);
    _throwIfNotOk(response, {200});
    return (response.data as List<dynamic>)
        .map((json) => FarmModel.fromJson(json as Map<String, dynamic>))
        .toList();
  });

  @override
  Future<FarmModel> createFarm({
    required String name,
    required String location,
    required int fiscalYearStartMonth,
  }) => _guard(() async {
    final response = await dio.post<dynamic>(
      '/api/v1/farms',
      data: {
        'name': name,
        'location': location,
        'fiscal_year_start_month': fiscalYearStartMonth,
      },
      options: _permissive,
    );
    _throwIfNotOk(response, {201});
    return FarmModel.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<FarmModel> getCurrentFarm() => _guard(() async {
    final response = await dio.get<dynamic>('/api/v1/farms/current', options: _permissive);
    _throwIfNotOk(response, {200});
    return FarmModel.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<List<FarmMemberModel>> listMembers() => _guard(() async {
    final response = await dio.get<dynamic>(
      '/api/v1/farms/current/members',
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
    return (response.data as List<dynamic>)
        .map((json) => FarmMemberModel.fromJson(json as Map<String, dynamic>))
        .toList();
  });

  @override
  Future<void> updateMemberRole(int userId, FarmRole role) => _guard(() async {
    final response = await dio.patch<dynamic>(
      '/api/v1/farms/current/members/$userId',
      data: {'role': role.wireValue},
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
  });

  @override
  Future<void> removeMember(int userId) => _guard(() async {
    final response = await dio.delete<dynamic>(
      '/api/v1/farms/current/members/$userId',
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
  });

  @override
  Future<List<FarmInvitationModel>> listInvitations() => _guard(() async {
    final response = await dio.get<dynamic>(
      '/api/v1/farms/current/invitations',
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
    return (response.data as List<dynamic>)
        .map((json) => FarmInvitationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  });

  @override
  Future<FarmInvitationModel> createInvitation(String email, FarmRole role) =>
      _guard(() async {
    final response = await dio.post<dynamic>(
      '/api/v1/farms/current/invitations',
      data: {'email': email, 'role': role.wireValue},
      options: _permissive,
    );
    _throwIfNotOk(response, {201});
    return FarmInvitationModel.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> revokeInvitation(int id) => _guard(() async {
    final response = await dio.delete<dynamic>(
      '/api/v1/farms/current/invitations/$id',
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
  });

  @override
  Future<void> setSuccessor(int? userId) => _guard(() async {
    final response = await dio.patch<dynamic>(
      '/api/v1/farms/current/successor',
      data: {'user_id': userId},
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
  });

  @override
  Future<FarmTransferModel?> getTransfer() => _guard(() async {
    final response = await dio.get<dynamic>(
      '/api/v1/farms/current/transfer',
      options: _permissive,
    );
    if (response.statusCode == 404) return null;
    _throwIfNotOk(response, {200});
    return FarmTransferModel.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<FarmTransferModel> nominateTransfer(int userId) => _guard(() async {
    final response = await dio.post<dynamic>(
      '/api/v1/farms/current/transfer',
      data: {'user_id': userId},
      options: _permissive,
    );
    _throwIfNotOk(response, {201});
    return FarmTransferModel.fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> cancelTransfer() => _guard(() async {
    final response = await dio.delete<dynamic>(
      '/api/v1/farms/current/transfer',
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
  });

  @override
  Future<void> acceptTransfer() => _guard(() async {
    final response = await dio.post<dynamic>(
      '/api/v1/farms/current/transfer/accept',
      options: _permissive,
    );
    _throwIfNotOk(response, {200});
  });
}
