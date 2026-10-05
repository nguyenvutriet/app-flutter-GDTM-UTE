import 'package:app_gdtm/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:app_gdtm/pages/login/login_page.dart';
import 'package:app_gdtm/widgets/app_colors.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Chỉ Android/iOS mới cần GoogleSignIn.initialize().
  // Web dùng Firebase Auth popup.
  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: 'abc.apps.googleusercontent.com',
    );
  }

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

      // Mở app vào trang đăng nhập.
      // Sau khi đăng nhập sẽ điều hướng theo role.
      home: const LoginPage(),
    );
  }
}