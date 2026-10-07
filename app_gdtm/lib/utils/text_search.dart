// lib/utils/text_search.dart
// Tiện ích tìm kiếm tiếng Việt: bỏ dấu, tách từ, so khớp theo từng từ.
// Mỗi ký tự được thay bằng đúng 1 ký tự => độ dài chuỗi không đổi,
// nên có thể dùng chỉ số của chuỗi đã chuẩn hóa để tô đậm chuỗi gốc.

const Map<String, String> _viGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _viMap = () {
  final m = <String, String>{};
  _viGroups.forEach((base, chars) {
    for (final c in chars.split('')) {
      m[c] = base;
    }
  });
  return m;
}();

/// "Thông Báo Học Phí" -> "thong bao hoc phi"
String normalizeVi(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(_viMap[ch] ?? ch);
  }
  return b.toString();
}

/// Tách thành các từ đã chuẩn hóa (không dấu, chữ thường).
List<String> tokenizeVi(String s) => normalizeVi(
  s,
).split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();

/// Mọi từ trong [tokens] đều xuất hiện trong [normalizedHaystack].
bool containsAllTokens(String normalizedHaystack, List<String> tokens) {
  for (final t in tokens) {
    if (!normalizedHaystack.contains(t)) return false;
  }
  return true;
}