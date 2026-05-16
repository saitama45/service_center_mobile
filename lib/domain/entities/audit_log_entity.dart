import 'package:equatable/equatable.dart';

class AuditLogEntity extends Equatable {
  const AuditLogEntity({
    required this.id,
    this.userId,
    this.userFullName,
    this.moduleCode,
    this.moduleName,
    this.permissionCode,
    this.targetTable,
    this.targetId,
    this.actionDetail,
    this.oldValueJson,
    this.newValueJson,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String? userFullName;
  final String? moduleCode;
  final String? moduleName;
  final String? permissionCode;
  final String? targetTable;
  final String? targetId;
  final String? actionDetail;
  final String? oldValueJson;
  final String? newValueJson;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, createdAt];
}
