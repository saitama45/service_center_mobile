class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => 'AppException: $message';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message);
}

class AuthException extends AppException {
  const AuthException(super.message);
}

class PermissionException extends AppException {
  const PermissionException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}
