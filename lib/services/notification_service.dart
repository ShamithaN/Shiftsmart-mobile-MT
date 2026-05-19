import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/notification.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient();
  static bool _listenersConfigured = false;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String get baseUrl => dotenv.env['NOTIFICATION_BASE_URL'] ?? '';

  String get mainKey => dotenv.env['GET_NOTIFICATIONS_KEY'] ?? '';
  String get registerKey => dotenv.env['REGISTER_DEVICE_KEY'] ?? '';
  String get markReadKey => dotenv.env['MARK_NOTIFICATIONS_READ_KEY'] ?? '';
  String get leaveApprovalKey =>
      dotenv.env['SEND_LEAVE_APPROVAL_NOTIFICATION_KEY'] ?? '';
  String get leaveRequestKey =>
      dotenv.env['SEND_LEAVE_REQUEST_NOTIFICATION_KEY'] ?? '';
  String get shiftKey => dotenv.env['SEND_SHIFT_NOTIFICATION_KEY'] ?? '';
  String get shiftCompleteKey =>
      dotenv.env['SEND_SHIFT_COMPLETED_NOTIFICATION_KEY'] ?? '';
  String get expectedFirebaseProjectId =>
      dotenv.env['EXPECTED_FIREBASE_PROJECT_ID'] ?? 'shiftsmart-bccd2';

  Future<void> initializeFCM({
    required int employeeId,
    required String userTag,
    void Function(RemoteMessage)? onForegroundMessage,
    void Function(RemoteMessage)? onNotificationOpenedApp,
  }) async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      if (!_isFirebaseProjectAligned()) {
        return;
      }

      final token = await _firebaseMessaging.getToken();

      if (token != null && employeeId != 0) {
        debugPrint("FCM TOKEN: $token");
        await registerDeviceTokenToBackend(
          token: token,
          employeeId: employeeId,
          tag: userTag,
        );
      }

      if (!_listenersConfigured) {
        _listenersConfigured = true;

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint("Foreground Message Received: ${message.data}");

          String? title;
          String? body;

          if (message.data.containsKey('shiftDetails')) {
            title = "New Shift Assigned";
            body = message.data['shiftDetails'];
          } else if (message.data.containsKey('completionDetails')) {
            title = "Shift Completed";
            body = message.data['completionDetails'];
          } else if (message.data.containsKey('Status')) {
            title = "Leave Update";
            body = "Your leave request is ${message.data['Status']}";
          } else if (message.notification != null) {
            title = message.notification?.title;
            body = message.notification?.body;
          }

          if (title != null && body != null) {
            _localNotifications.show(
              message.hashCode,
              title,
              body,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'high_importance_channel',
                  'High Importance Notifications',
                  channelDescription: 'Used for important notifications',
                  importance: Importance.max,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                ),
              ),
            );
          }

          if (onForegroundMessage != null) onForegroundMessage(message);
        });

        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint("Notification tapped (Opened from Background)");
          if (onNotificationOpenedApp != null) onNotificationOpenedApp(message);
        });
      }
    } catch (e) {
      debugPrint("FCM Initialization error: $e");
    }
  }

  Future<void> registerDeviceTokenToBackend({
    required String token,
    required int employeeId,
    required String tag,
  }) async {
    if (registerKey.isEmpty) {
      debugPrint("Missing REGISTER_DEVICE_KEY");
      return;
    }

    String url = '$baseUrl/RegisterDevice?code=$registerKey';
    final body = {
      "EmployeeId": employeeId,
      "DeviceToken": token,
      "Platform": _platformName,
      "Tag": tag,
    };

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);

      if (response.statusCode == 200) {
        debugPrint("Device registered successfully");
      } else {
        debugPrint(
            "Register failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Device registration error: $e");
    }
  }

  Future<List<NotificationItem>> fetchNotificationsread(int employeeId) async {
    if (mainKey.isEmpty) throw Exception("Missing NOTIFI_MAIN_KEY");

    final Map<String, String> queryParams = {
      'code': mainKey,
      'employeeId': employeeId.toString(),
      'status': 'read',
    };

    final uri = Uri.parse('$baseUrl/notifications')
        .replace(queryParameters: queryParams);

    final response = await _apiClient.get(uri.toString(), useAuth: true);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final notifications = data['notifications'];
      List<NotificationItem> items = [];
      for (var n in notifications) {
        items.add(NotificationItem.fromJson(n));
      }
      return items;
    } else {
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    }
  }

  Future<List<NotificationItem>> fetchNotificationsUnread(
      int employeeId) async {
    if (mainKey.isEmpty) throw Exception("Missing NOTIFI_MAIN_KEY");

    final Map<String, String> queryParams = {
      'code': mainKey,
      'employeeId': employeeId.toString(),
      'status': 'unread',
    };

    final uri = Uri.parse('$baseUrl/notifications')
        .replace(queryParameters: queryParams);

    final response = await _apiClient.get(uri.toString(), useAuth: true);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final notifications = data['notifications'];
      List<NotificationItem> items = [];
      for (var n in notifications) {
        items.add(NotificationItem.fromJson(n));
      }
      return items;
    } else {
      throw Exception('Failed to fetch notifications: ${response.statusCode}');
    }
  }

  Future<void> markAsRead(List<int> notificationIds) async {
    if (markReadKey.isEmpty) throw Exception("Missing NOTIFI_MARK_READ_KEY");

    final url = '$baseUrl/notifications/mark-read?code=$markReadKey';

    final response = await _apiClient.post(
      url,
      body: {"NotificationIds": notificationIds},
      useAuth: true,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notifications as read');
    }
  }

  Future<void> sendShiftNotification(
      int employeeId, String shiftDetails) async {
    if (shiftKey.isEmpty) {
      debugPrint("Missing NOTIFI_SHIFT_KEY");
      return;
    }

    String url = '$baseUrl/SendShiftNotification?code=$shiftKey';

    final payload = {
      "userTag": "user_$employeeId",
      "shiftDetails": shiftDetails,
    };

    try {
      final response = await _apiClient.post(url, body: payload, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Notification sent to user_$employeeId");
      } else if (response.statusCode == 404) {
        debugPrint(
            "Notification not sent: user_$employeeId has no registered device.");
      } else {
        debugPrint("Failed to send notification: ${response.body}");
      }
    } catch (e) {
      debugPrint("Notification sending error: $e");
    }
  }

  Future<void> sendLeaveRequeststoManager(int employeeId, String? leaveType,
      String startDate, String endDate, String reason) async {
    if (leaveRequestKey.isEmpty) {
      debugPrint("Missing NOTIFI_LEAVE_REQUEST_KEY");
      return;
    }

    final url = '$baseUrl/SendLeaveRequestNotification?code=$leaveRequestKey';

    final body = {
      "EmployeeId": employeeId,
      "LeaveType": leaveType,
      "StartDate": startDate,
      "EndDate": endDate,
      "Reason": reason,
    };

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Leave request notification sent");
      } else {
        debugPrint("Failed to send leave request: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error sending leave request: $e");
    }
  }

  Future<void> leaveNotification(int id, String newStatus) async {
    if (leaveApprovalKey.isEmpty) {
      debugPrint("Missing NOTIFI_LEAVE_APPROVAL_KEY");
      return;
    }

    final url =
        '$baseUrl/SendLeaveApprovalNotificationFunction?code=$leaveApprovalKey';
    final body = {"EmployeeId": id, "Status": newStatus};

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Leave $newStatus notification sent");
      } else if (response.statusCode == 404) {
        debugPrint("Notification not sent: Employee has no registered device.");
      } else {
        debugPrint(
            "Failed to send notification: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Warning: Error sending leave notification: $e");
    }
  }

  Future<void> sendShiftCompletionNotification(
    String? employeeName,
    int shiftId,
    DateTime clockOutTime,
  ) async {
    if (shiftCompleteKey.isEmpty) {
      debugPrint("Missing NOTIFI_SHIFT_COMPLETE_KEY");
      return;
    }

    final url =
        '$baseUrl/SendShiftCompletedNotification?code=$shiftCompleteKey';

    final formattedTime =
        DateFormat('h:mma').format(clockOutTime).toLowerCase();
    final message = "$employeeName completed shift #$shiftId at $formattedTime";
    final body = {"completionDetails": message};

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Notification sent: $message");
      } else {
        throw Exception("Failed to send notification: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error sending shift completion notification: $e");
    }
  }

  Future<void> sendEmergencyNotification(
    String? employeeName,
    int shiftId,
    String? reason,
    DateTime clockOutTime,
  ) async {
    if (shiftCompleteKey.isEmpty) {
      debugPrint("Missing NOTIFI_SHIFT_COMPLETE_KEY");
      return;
    }

    final url =
        '$baseUrl/SendShiftCompletedNotification?code=$shiftCompleteKey';

    final formattedTime =
        DateFormat('h:mma').format(clockOutTime).toLowerCase();
    final message =
        " EMERGENCY: $employeeName clocked out early from shift #$shiftId at $formattedTime. Reason: ${reason ?? 'Not provided'}";
    final body = {"CompletionDetails": message};

    try {
      final response = await _apiClient.post(url, body: body, useAuth: true);
      if (response.statusCode == 200) {
        debugPrint("Emergency notification sent: $message");
      } else {
        throw Exception("Failed to send notification: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error sending emergency notification: $e");
    }
  }

  bool _isFirebaseProjectAligned() {
    final actualProjectId = Firebase.app().options.projectId;
    final actualSenderId = Firebase.app().options.messagingSenderId;

    debugPrint(
      "Firebase project: $actualProjectId, sender: $actualSenderId",
    );

    if (expectedFirebaseProjectId.isEmpty ||
        actualProjectId == expectedFirebaseProjectId) {
      return true;
    }

    debugPrint(
      "Firebase project mismatch. Expected $expectedFirebaseProjectId but "
      "mobile config loaded $actualProjectId. Device token registration skipped.",
    );
    return false;
  }

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'ios';
      default:
        return 'android';
    }
  }
}
