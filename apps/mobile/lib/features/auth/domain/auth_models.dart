class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String experienceLevel;
  final List<String> preferredMarkets;
  final String? paperAccountId;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.experienceLevel = 'BEGINNER',
    this.preferredMarkets = const ['NSE', 'CRYPTO'],
    this.paperAccountId,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      experienceLevel: json['experienceLevel'] as String? ?? 'BEGINNER',
      preferredMarkets: (json['preferredMarkets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['NSE', 'CRYPTO'],
      paperAccountId: json['paperAccountId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

enum AuthStatus { initial, unauthenticated, authenticated, loading, demoMode }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isDemoMode => status == AuthStatus.demoMode;
  bool get isLoading => status == AuthStatus.loading;

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, errorMessage: error);
  factory AuthState.authenticated(UserModel user) =>
      AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.demoMode() => const AuthState(
        status: AuthStatus.demoMode,
        user: UserModel(
          id: 'demo_user_01',
          email: 'demo@tradeverse.ai',
          displayName: 'Simulated Trader (Demo)',
          experienceLevel: 'BEGINNER',
        ),
      );
}
