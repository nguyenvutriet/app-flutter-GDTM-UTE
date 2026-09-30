import 'package:app_gdtm/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:app_gdtm/pages/login/login_page.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase bằng cấu hình trong firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giải đáp thắc mắc sinh viên',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        useMaterial3: true,
      ),

      // Mở app vào trang đăng nhập; đăng nhập xong mới vào DashboardPage theo role
      home: const LoginPage(),
    );
  }
}