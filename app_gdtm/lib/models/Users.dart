import 'package:cloud_firestore/cloud_firestore.dart';

class Users {
  String? id;
  String? fullName;
  String? email;
  String? password;
  String? role;
  String? departmentId;

  Users({
    this.id,
    this.fullName,
    this.email,
    this.password,
    this.role,
    this.departmentId,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Users.fromJson(Map<String, dynamic> json) {
    return Users(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      password: json['password'],
      role: json['role'],
      departmentId: json['departmentId'],
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'password': password,
      'role': role,
      'departmentId': departmentId,
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // ============================================================

  factory Users.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Users(
      id: data['id'] ?? doc.id,
      fullName: data['fullName'],
      email: data['email'],
      password: data['password'],
      role: data['role'],
      departmentId: data['departmentId'],
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'password': password,
      'role': role,
      'departmentId': departmentId,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Users copyWith({
    String? id,
    String? fullName,
    String? email,
    String? password,
    String? role,
    String? departmentId,
  }) {
    return Users(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      departmentId: departmentId ?? this.departmentId,
    );
  }
}