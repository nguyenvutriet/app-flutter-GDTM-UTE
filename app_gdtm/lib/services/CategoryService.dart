import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_gdtm/models/Category.dart';


/// Danh mục kèm số lượng phản hồi (dùng cho trang quản lý của admin)
class CategoryStat {
  final Category category;
  final int requestCount;
  const CategoryStat(this.category, this.requestCount);
}

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


    // ======================= ADMIN =======================

  /// Tất cả danh mục (cả đã vô hiệu hóa) kèm số phản hồi.
  Future<List<CategoryStat>> getAllCategoriesWithStats() async {
    final snapshot = await _firestore.collection('categories').get();
    final cats = snapshot.docs.map(Category.fromFirestore).toList();
    cats.sort((a, b) => a.subject.compareTo(b.subject));
 
    // Lấy góp ý 1 lần rồi đếm theo mảng categoryIds
    final reqSnap = await _firestore.collection('requests').get();
 
    int countFor(Category c) => reqSnap.docs.where((d) {
          final ids = d.data()['categoryIds'];
          return ids is List && ids.contains(c.id);
        }).length;
 
    return [for (final c in cats) CategoryStat(c, countFor(c))];
  }
 
  Future<void> addCategory(String subject) async {
    final ref = _firestore.collection('categories').doc();
    final cat = Category(id: ref.id, subject: subject.trim(), isActive: true);
    await ref.set(cat.toFirestore());
  }
 
  Future<void> updateSubject(String id, String subject) =>
      _firestore.collection('categories').doc(id).update({'subject': subject.trim()});
 
  Future<void> setActive(String id, bool isActive) =>
      _firestore.collection('categories').doc(id).update({'isActive': isActive});
}
 