enum ReactionType {
  like,
  love,
  haha,
  wow,
  sad,
  angry,
}

extension ReactionTypeExtension on ReactionType {
  /// Chuyển đổi ReactionType thành chuỗi để lưu vào API/Firestore
  String toApiString() {
    return name;
  }

  /// Tạo ReactionType từ chuỗi
  static ReactionType? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return ReactionType.values.firstWhere(
        (e) => e.name.toLowerCase() == value.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}