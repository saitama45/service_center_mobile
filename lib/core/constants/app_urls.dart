import '../../data/datasources/remote/api_client.dart';

/// Web pages that complement the API.
///
/// Both are served by the same Laravel app as the API, so they derive from
/// [ApiClient.origin] and follow the same `API_BASE_URL` override — pointing
/// the app at a local backend points these links there too.
class AppUrls {
  const AppUrls._();

  /// Public page where a signed-in member requests deletion of their account.
  /// Apple requires account deletion to be reachable from inside the app
  /// (App Store Review Guideline 5.1.1(v)); linking out to this page is an
  /// accepted way to satisfy it.
  static Uri get accountDeletion =>
      Uri.parse('${ApiClient.origin}/account-deletion');

  /// Password reset request form. Submitting it emails a tokenised
  /// `/reset-password/{token}` link; the new password works in the app
  /// immediately afterwards because sign-in authenticates against this
  /// same backend.
  static Uri get forgotPassword =>
      Uri.parse('${ApiClient.origin}/forgot-password');
}
