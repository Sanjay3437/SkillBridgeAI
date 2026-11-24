class User {
  const User({required this.id, required this.email});

  final String id;
  final String email;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
      );
}

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      );
}
