class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePic;
  final String fcmToken;
  final bool isOnline;
  final List<String> connections;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePic,
    required this.fcmToken,
    this.isOnline = false,
    this.connections = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profilePic': profilePic,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'connections': connections,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profilePic: map['profilePic'] ?? '',
      fcmToken: map['fcmToken'] ?? '',
      isOnline: map['isOnline'] ?? false,
      connections: List<String>.from(map['connections'] ?? []),
    );
  }
}
