import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.roleId,
    required this.roleCode,
    required this.roleName,
    this.deoId,
    required this.username,
    required this.fullName,
    this.email,
    this.employeeId,
    required this.isActive,
    this.lastLoginAt,
    required this.failedLoginCount,
    this.lockedUntil,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String roleId;
  final String roleCode;
  final String roleName;
  final String? deoId;
  final String username;
  final String fullName;
  final String? email;
  final String? employeeId;
  final bool isActive;
  final DateTime? lastLoginAt;
  final int failedLoginCount;
  final DateTime? lockedUntil;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now().toUtc());

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [id, username, roleId, isActive];
}
