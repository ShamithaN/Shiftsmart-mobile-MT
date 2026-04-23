//lib/screens/Notifications.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/models/notification.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<NotificationItem> allNotifications = [];
  List<int> unreadNotificationIds = [];
  bool isLoading = true;
  int _selectedTabIndex = 2; // 0 for Unread, 1 for Read, 2 for Announcements

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    print(' loadNotifications STARTED');
    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('employeeId');

      if (employeeId == null) {
        throw Exception("Employee ID not found in SharedPreferences");
      }

      // Fetch read and unread notifications separately
      final readNotifications =
          await _notificationService.fetchNotificationsread(employeeId);
      final unreadNotifications =
          await _notificationService.fetchNotificationsUnread(employeeId);

      // Store unread IDs for marking later
      unreadNotificationIds = unreadNotifications.map((n) => n.id).toList();

      final result = [...readNotifications, ...unreadNotifications];

      debugPrint(' Notifications fetched: ${result.length}');

      setState(() {
        allNotifications = result;
        isLoading = false;
      });
    } catch (e, stack) {
      debugPrint(" Error loading notifications: $e");
      debugPrint(stack.toString());
      setState(() => isLoading = false);
    }
  }

  Future<void> _markAllUnreadAsRead() async {
    try {
      if (unreadNotificationIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No unread notifications.")),
        );
        return;
      }

      await _notificationService.markAsRead(unreadNotificationIds);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marked unread notifications as read.")),
      );

      // Refresh after marking
      loadNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark as read: $e")),
      );
    }
  }

  Map<String, List<NotificationItem>> groupNotifications(
      List<NotificationItem> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <String, List<NotificationItem>>{
      'New': [],
      'Earlier Today': [],
      'Yesterday': [],
      'Older': [],
    };

    for (var notif in all) {
      final notifDate = notif.createdAt;
      final difference = now.difference(notifDate);

      if (difference.inMinutes < 60) {
        grouped['New']!.add(notif);
      } else if (notifDate.isAfter(today)) {
        grouped['Earlier Today']!.add(notif);
      } else if (notifDate.isAfter(yesterday)) {
        grouped['Yesterday']!.add(notif);
      } else {
        grouped['Older']!.add(notif);
      }
    }

    return grouped;
  }

  List<Widget> buildGroupedNotifications(
      Map<String, List<NotificationItem>> grouped) {
    final widgets = <Widget>[];

    grouped.forEach((section, notifications) {
      if (notifications.isEmpty) return;

      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Text(
          section,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));

      for (var notif in notifications) {
        final isUnread =
            unreadNotificationIds.contains(notif.id); //  check if unread

        widgets.add(Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          color: Colors.transparent,
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isUnread
                    ? [
                        const Color.fromARGB(
                            200, 60, 70, 90), // Lighter for unread
                        const Color.fromARGB(200, 40, 50, 70),
                      ]
                    : [
                        const Color.fromARGB(180, 42, 50, 67),
                        const Color.fromARGB(180, 34, 40, 52),
                      ],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              leading: const Icon(Icons.notifications, color: Colors.white),
              title: Text(
                notif.subject,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                notif.message,
                style: TextStyle(
                  color: isUnread ? Colors.white70 : Colors.grey,
                ),
              ),
            ),
          ),
        ));
      }
    });

    return widgets;
  }

  // Mock Announcements
  final List<Map<String, String>> mockAnnouncements = [
    {
      "title": "Reminders",
      "body": "Don't forget to complete your profile.",
      "date": "01/04/2026, 03:19:46"
    },
    {
      "title": "Billing alert",
      "body": "please aware of the billing date",
      "date": "01/04/2026, 03:05:27"
    }
  ];

  Widget _buildTabButton(String title, int index, {IconData? icon}) {
    final isActive = _selectedTabIndex == index;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: isActive ? const Color(0xFFFFD700) : Colors.white, size: 16),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFFFFD700) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 2,
              width: 100, // Approximate width for underline
              color: const Color(0xFFFFD700),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: mockAnnouncements.length,
      itemBuilder: (context, index) {
        final ann = mockAnnouncements[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2230),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              // Yellow vertical bar
              Container(
                width: 4,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.campaign, color: Color(0xFFFFD700), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ann['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ann['body']!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ann['date']!,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupNotifications(allNotifications);

    return Stack(
      children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      const Icon(Icons.notifications, color: Colors.blueAccent, size: 28),
                      const SizedBox(width: 10),
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: loadNotifications,
                        child: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Main container box
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3243).withOpacity(0.9), // Dark grayish blue
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tabs
                          Padding(
                            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 10),
                            child: Row(
                              children: [
                                _buildTabButton("Unread", 0),
                                const SizedBox(width: 20),
                                _buildTabButton("Read", 1),
                                const SizedBox(width: 20),
                                _buildTabButton("Announcements", 2, icon: Icons.campaign),
                              ],
                            ),
                          ),
                          // Content area
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: _selectedTabIndex == 2
                                ? _buildAnnouncementsList()
                                : (isLoading 
                                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                                    : ListView(
                                        padding: const EdgeInsets.only(top: 10),
                                        children: [
                                          if (_selectedTabIndex == 0 && unreadNotificationIds.isNotEmpty)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: _markAllUnreadAsRead,
                                                child: const Text("Mark all as read", style: TextStyle(color: Colors.blueAccent)),
                                              ),
                                            ),
                                          ...buildGroupedNotifications(grouped)
                                        ],
                                      )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Close Button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A8B9C), // Teal button
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
