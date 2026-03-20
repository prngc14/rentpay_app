class UserModel {
  final String uid;
  final String name;
  final String email;
  final String room;
  final String role;
  final String ownerCode;
  final String ownerId;
  final bool approved;

  // ✅ NEW FIELDS
  final String? gcashQR;
  final String? mayaQR;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.room,
    required this.role,
    required this.ownerCode,
    this.ownerId = "",
    this.approved = false,
    this.gcashQR,
    this.mayaQR,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'room': room,
      'role': role,
      'ownerCode': ownerCode,
      'ownerId': ownerId,
      'approved': approved,
      'gcashQR': gcashQR,
      'mayaQR': mayaQR,
    };
  }
}
