import 'package:flutter/material.dart';
import 'package:app_gdtm/pages/common/dashboard_page.dart';
import 'package:app_gdtm/widgets/app_colors.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      // TODO: khi có login thì đổi thành trang đăng nhập
      home: const DashboardPage(),
    );
  }
}