import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/ForwardingLog.dart';
import 'package:app_gdtm/models/Request.dart';
import 'package:app_gdtm/models/Users.dart';

class Department {
  String? id;
  String? name;
  String? description;
  String? email;
  String? phone;
  String? location;
  bool? isActive;

  // Relationships
  List<Users> users;
  List<Request> requests;
  List<ForwardingLog> receivedForwardingLogs;
  List<ForwardingLog> sendedForwardingLogs;

  Department({
    this.id,
    this.name,
    this.description,
    this.email,
    this.phone,
    this.location,
    this.isActive,
    this.users = const [],
    this.requests = const [],
    this.receivedForwardingLogs = const [],
    this.sendedForwardingLogs = const [],
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      email: json['email'],
      phone: json['phone'],
      location: json['location'],
      isActive: json['isActive'],

      users: json['users'] != null
          ? (json['users'] as List)
              .map((e) => Users.fromJson(e))
              .toList()
          : [],

      requests: json['requests'] != null
          ? (json['requests'] as List)
              .map((e) => Request.fromJson(e))
              .toList()
          : [],

      receivedForwardingLogs:
          json['receivedForwardingLogs'] != null
              ? (json['receivedForwardingLogs'] as List)
                  .map((e) => ForwardingLog.fromJson(e))
                  .toList()
              : [],

      sendedForwardingLogs:
          json['sendedForwardingLogs'] != null
              ? (json['sendedForwardingLogs'] as List)
                  .map((e) => ForwardingLog.fromJson(e))
                  .toList()
              : [],
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'email': email,
      'phone': phone,
      'location': location,
      'isActive': isActive,

      'users': users
          .map((e) => e.toJson())
          .toList(),

      'requests': requests
          .map((e) => e.toJson())
          .toList(),

      'receivedForwardingLogs':
          receivedForwardingLogs
              .map((e) => e.toJson())
              .toList(),

      'sendedForwardingLogs':
          sendedForwardingLogs
              .map((e) => e.toJson())
              .toList(),
    };
  }

  // ============================================================
  // FROM FIRESTORE
  // Collection: department
  //
  // Firestore fields:
  // description
  // email
  // id
  // isActive
  // location
  // phone
  // ============================================================

  factory Department.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Department(
      id: data['id'] ?? doc.id,
      name: data['name'],
      description: data['description'],
      email: data['email'],
      phone: data['phone'],
      location: data['location'],
      isActive: data['isActive'],
    );
  }

  // ============================================================
  // TO FIRESTORE
  // ============================================================

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'email': email,
      'phone': phone,
      'location': location,
      'isActive': isActive,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Department copyWith({
    String? id,
    String? name,
    String? description,
    String? email,
    String? phone,
    String? location,
    bool? isActive,
    List<Users>? users,
    List<Request>? requests,
    List<ForwardingLog>? receivedForwardingLogs,
    List<ForwardingLog>? sendedForwardingLogs,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      users: users ?? this.users,
      requests: requests ?? this.requests,
      receivedForwardingLogs:
          receivedForwardingLogs ?? this.receivedForwardingLogs,
      sendedForwardingLogs:
          sendedForwardingLogs ?? this.sendedForwardingLogs,
    );
  }
}