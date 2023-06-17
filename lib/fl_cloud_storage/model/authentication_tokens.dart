class AuthenticationTokens {

  const AuthenticationTokens({
    required this.accessToken,
    required this.idToken,
  });

  /// The OAuth2 access token used to access services.
  final String? accessToken;

  /// An OpenID Connect ID token for the authenticated user.
  final String? idToken;

}