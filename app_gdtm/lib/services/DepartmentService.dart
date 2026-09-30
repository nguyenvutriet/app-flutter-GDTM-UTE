import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_gdtm/models/Department.dart';

class DepartmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Department>> getDepartments() async {
    final snapshot = await _firestore
        .collection('department')
        .get();

    return snapshot.docs.map((doc) {
      return Department.fromFirestore(doc);
    }).toList();
  }
}