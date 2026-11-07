class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final String name;
  final bool emailVerified;
}
