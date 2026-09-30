import 'package:app_gdtm/firebase_options.dart';
import 'package:app_gdtm/models/Announcement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      debugShowCheckedModeBanner: false,
      title: 'Test Firebase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Stream lấy dữ liệu realtime từ Firestore
  final Stream<QuerySnapshot<Map<String, dynamic>>> _announcementStream =
      FirebaseFirestore.instance
          .collection('announcement')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Firebase Firestore'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _announcementStream,

        builder: (context, snapshot) {
          // =========================
          // ĐANG TẢI
          // =========================
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // =========================
          // CÓ LỖI
          // =========================
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snapshot.error}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            );
          }

          // =========================
          // KHÔNG CÓ DATA
          // =========================
          if (!snapshot.hasData) {
            return const Center(
              child: Text('Không lấy được dữ liệu'),
            );
          }

          final documents = snapshot.data!.docs;

          // =========================
          // COLLECTION RỖNG
          // =========================
          if (documents.isEmpty) {
            return const Center(
              child: Text(
                'Collection announcement không có dữ liệu',
              ),
            );
          }

          // =========================
          // IN DATA RA CONSOLE
          // =========================
          for (final doc in documents) {
            print('==============================');
            print('Document ID: ${doc.id}');
            print('Firestore Data: ${doc.data()}');

            final announcement =
                Announcement.fromFirestore(doc);

            print('Announcement ID: ${announcement.id}');
            print('Title: ${announcement.title}');
            print('Content: ${announcement.content}');
            print('User ID: ${announcement.userId}');
            print('Date: ${announcement.date}');
          }

          // =========================
          // HIỂN THỊ DATA
          // =========================
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,

            itemBuilder: (context, index) {
              final doc = documents[index];

              // Chuyển Firestore Document -> Announcement
              final announcement =
                  Announcement.fromFirestore(doc);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),

                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // ID
                      Text(
                        'ID: ${announcement.id ?? 'Không có'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // TITLE
                      Text(
                        announcement.title ?? 'Không có title',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // CONTENT
                      Text(
                        announcement.content ??
                            'Không có content',
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // USER ID
                      Text(
                        'User ID: ${announcement.userId ?? 'Không có'}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // DATE
                      Text(
                        'Date: ${announcement.date ?? 'Không có'}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}