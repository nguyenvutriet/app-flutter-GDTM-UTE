import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_gdtm/models/Notification.dart' as app_notification;
import 'package:app_gdtm/models/Request.dart';

class NotificationService {
  static const String notificationsCollection = 'notification';
  static const String requestsCollection = 'requests';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<app_notification.Notification>> watchNotifications({
    String? userId,
    String? departmentId,
  }) {
    return _firestore.collection(notificationsCollection).snapshots().map(
      (snapshot) {
        final notifications = snapshot.docs
            .map(app_notification.Notification.fromFirestore)
            .where(
              (notification) =>
                  userId != null && userId.isNotEmpty
                      ? notification.userId == userId
                      : departmentId != null && departmentId.isNotEmpty
                      ? notification.departmentId == departmentId
                      : false,
            )
            .toList();
        notifications.sort(
          (a, b) => (b.createAt ?? DateTime(0)).compareTo(
            a.createAt ?? DateTime(0),
          ),
        );
        return notifications;
      },
    );
  }

  Future<List<app_notification.Notification>> getNotifications({
    String? userId,
    String? departmentId,
  }) async {
    final snapshot = await _firestore.collection(notificationsCollection).get();
    final notifications = snapshot.docs
        .map(app_notification.Notification.fromFirestore)
        .where(
          (notification) =>
              userId != null && userId.isNotEmpty
                  ? notification.userId == userId
                  : departmentId != null && departmentId.isNotEmpty
                  ? notification.departmentId == departmentId
                  : false,
        )
        .toList();
    notifications.sort(
      (a, b) => (b.createAt ?? DateTime(0)).compareTo(
        a.createAt ?? DateTime(0),
      ),
    );
    return notifications;
  }

  Future<int> getUnreadCount({
    String? userId,
    String? departmentId,
  }) async {
    final notifications = await getNotifications(
      userId: userId,
      departmentId: departmentId,
    );
    return notifications.where((notification) => notification.isRead != true).length;
  }

    Future<void> setNotificationRead(String notificationId, bool isRead) async {
    await _firestore
        .collection(notificationsCollection)
        .doc(notificationId)
      .update({'isRead': isRead});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(notificationsCollection)
        .doc(notificationId)
        .delete();
  }

  Future<Request?> getRequestById(String requestId) async {
    final doc = await _firestore
        .collection(requestsCollection)
        .doc(requestId)
        .get();
    if (!doc.exists) return null;
    return Request.fromFirestore(doc);
  }
}
