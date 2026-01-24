import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_reader/request.dart';
import 'package:qr_reader/settings.dart';
import 'package:intl/intl.dart';
import 'package:qr_reader/reassign_duty_screen.dart';

class NotificationBadge extends StatefulWidget {
  const NotificationBadge({super.key});

  static final GlobalKey<_NotificationBadgeState> globalKey =
      GlobalKey<_NotificationBadgeState>();

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = int.parse(await config.userId.getSetting() ?? '0');
      final response = await sendRequest("GET", "users/notifications/$userId/");
      final notifications = response as List<dynamic>;
      setState(() {
        _unreadCount = notifications.where((n) => n['is_seen'] == false).length;
      });
    } catch (error) {
      print('Error loading notification count: $error');
    }
  }

  void refreshUnreadCount() {
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Icon(
          Icons.notifications,
          size: 28,
          color: Colors.white,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  List<dynamic> notifications = [];
  bool isLoadingNotifications = true;
  late int userId;
  int _unreadCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        _loadNotifications();
      }
    });
  }

  Future<void> _loadNotifications() async {
    try {
      userId = int.parse(await config.userId.getSetting() ?? '0');
      final response = await sendRequest("GET", "users/notifications/$userId/");
      if (!mounted) return;
      setState(() {
        notifications = response;
        isLoadingNotifications = false;
        _unreadCount = notifications.where((n) => n['is_seen'] == false).length;
      });
      NotificationBadge.globalKey.currentState?.refreshUnreadCount();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingNotifications = false;
      });
      print('Error fetching notifications: $error');
    }
  }

  Future<void> _readNotification(int notificationId) async {
    try {
      userId = int.parse(await config.userId.getSetting() ?? '0');

      await sendRequest(
          "POST", "users/notifications/$userId/mark_as_read/$notificationId/");

      setState(() {
        // _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        final index =
            notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          notifications[index]['is_seen'] = true;
        }
      });

      await _loadNotifications(); // Обновляем список
      NotificationBadge.globalKey.currentState?.refreshUnreadCount();
    } catch (error) {
      setState(() {
        _unreadCount++;
      });
      print('Error marking notification as read: $error');
    }
  }

  bool _isDutyRefusalNotification(Map<String, dynamic> notification) {
    final dutyActionId = notification['duty_action_id'];
    if (dutyActionId == null) {
      return false;
    }
    final isResolvedVal = notification['is_resolved'];
    final isResolved = isResolvedVal is bool
        ? isResolvedVal
        : (isResolvedVal is int ? isResolvedVal != 0 : false);
    return !isResolved;
  }

  bool _isDutyResolvedNotification(Map<String, dynamic> notification) {
    final dutyActionId = notification['duty_action_id'];
    if (dutyActionId == null) {
      return false;
    }
    final isResolvedVal = notification['is_resolved'];
    final isResolved = isResolvedVal is bool
        ? isResolvedVal
        : (isResolvedVal is int ? isResolvedVal != 0 : false);
    return isResolved;
  }

  Map<String, dynamic>? _extractDutyRefusalData(
      Map<String, dynamic> notification) {
    return {
      'duty_id': notification['duty_id'] is int ? notification['duty_id'] : int.parse(notification['duty_id']),
      'refusal_reason': notification['duty_action_reason'],
    };
  }

  void _handleDutyRefusalNotification(Map<String, dynamic> notification) {
    var data = _extractDutyRefusalData(notification);
    if (data != null && data['duty_id'] != null) {
      int dutyId = data['duty_id'] as int;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReassignDutyScreen(
            dutyId: dutyId,
            notificationId: notification['id'],
            refusalReason: data['refusal_reason'],
          ),
        ),
      ).then((_) {
        // Обновляем уведомления после возврата
        _loadNotifications();
      });
    }
  }

  Widget _buildReadButton(bool isSeen, int notificationId) {
    if (isSeen) {
      // Если уже прочитано - неактивная кнопка
      return FilledButton.tonal(
        onPressed: null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.grey.shade100,
          foregroundColor: Colors.grey.shade600,
        ),
        child: const Text('Прочитано'),
      );
    } else {
      // Если не прочитано - активная кнопка
      return FilledButton.tonal(
        onPressed: () {
          _readNotification(notificationId);
        },
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blueGrey.shade100,
          foregroundColor: Colors.grey.shade800,
        ),
        child: const Text('Прочитать'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).canvasColor,
        toolbarHeight: 65,
        title: Text('Уведомления'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).canvasColor),
            onPressed: () {
              setState(() {
                isLoadingNotifications = true;
              });
              _loadNotifications();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: isLoadingNotifications
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text('Нет уведомлений'))
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notification = notifications[index];

                    String title = notification['title'];
                    String text = notification['text'];
                    String source = notification['source'];

                    if (text.length > 500) {
                      text = "${text.substring(0, 500)}...";
                    }

                    String formattedDate = "";
                    if (notification['created_at'] != null) {
                      DateTime createdAt =
                          DateTime.parse(notification['created_at']).toLocal();
                      formattedDate =
                          DateFormat('dd.MM.yyyy HH:mm').format(createdAt);
                    }

                    bool isDutyRefusal =
                        _isDutyRefusalNotification(notification);
                    bool isDutyResolved =
                        _isDutyResolvedNotification(notification);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      color: isDutyRefusal ? Colors.red.shade50 : isDutyResolved ? Colors.green.shade50 : null,
                      child: InkWell(
                        onTap: isDutyRefusal
                            ? () => _handleDutyRefusalNotification(notification)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(text,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                  if (isDutyRefusal)
                                    Icon(Icons.assignment_ind,
                                        color: Colors.red.shade700),
                                ],
                              ),
                              if (isDutyRefusal) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 16, color: Colors.red.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Нажмите для переназначения дежурства',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (isDutyResolved) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 16, color: Colors.green.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Дежурство переназначено',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text('Заголовок: $title',
                                  style: TextStyle(color: Colors.grey[700])),
                              Text('Источник: $source',
                                  style: TextStyle(color: Colors.grey[700])),
                              Text('Дата: $formattedDate',
                                  style: TextStyle(color: Colors.grey[700])),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: _buildReadButton(
                                      notification['is_seen'] ?? false,
                                      notification['id']))
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
