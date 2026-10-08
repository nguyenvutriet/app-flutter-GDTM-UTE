import 'package:file_picker/file_picker.dart';

extension PlatformFileCompat on PlatformFile {
  int get size => lengthSync() ?? 0;
}
