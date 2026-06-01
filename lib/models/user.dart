class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isAdmin;
  final bool emailVerified;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.isAdmin = false,
    this.emailVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'],
        role: j['role'] ?? 'customer',
        isAdmin: j['is_admin'] == true,
        emailVerified: j['email_verified'] == true,
      );
}
