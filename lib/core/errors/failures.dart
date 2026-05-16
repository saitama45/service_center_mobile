import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure({this.attemptsRemaining, this.serverMessage})
      : super('Invalid username or password.');
  final int? attemptsRemaining;
  final String? serverMessage;
}

class AccountLockedFailure extends AuthFailure {
  const AccountLockedFailure(this.lockedUntil)
      : super('Account is locked.');
  final DateTime lockedUntil;
}

class AccountDisabledFailure extends AuthFailure {
  const AccountDisabledFailure() : super('Account is disabled.');
}

class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure() : super('Permission denied.');
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
