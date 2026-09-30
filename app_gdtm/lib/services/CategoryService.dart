import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_gdtm/models/Category.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Danh mục đang bật (isActive == true), sắp xếp theo tên.
  Future<List<Category>> getActiveCategories() async {
    final snapshot = await _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .get();

    final list = snapshot.docs.map(Category.fromFirestore).toList();
    list.sort((a, b) => a.subject.compareTo(b.subject));
    return list;
  }
}