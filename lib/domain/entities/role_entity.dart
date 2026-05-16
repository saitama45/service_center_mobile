import 'package:equatable/equatable.dart';

class RoleEntity extends Equatable {
  const RoleEntity({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.isSystem,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final bool isSystem;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, code, isSystem, isActive];
}
