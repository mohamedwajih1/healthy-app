import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/habit_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/habit_provider.dart';
import '../../services/notifications_inbox_service.dart';
import '../habits/edit_habit_screen.dart';

// In-app notifications inbox: gathers chat/follow notifications and all habit
// reminders into a single place.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Text(
            'الإشعارات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الإشعارات', icon: Icon(Icons.notifications_rounded)),
              Tab(text: 'التذكيرات', icon: Icon(Icons.alarm_rounded)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _NotificationsTab(),
            _RemindersTab(),
          ],
        ),
      ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.uid;
    final service = NotificationsInboxService();

    if (userId == null) {
      return const _EmptyState(
        icon: Icons.notifications_off_rounded,
        message: 'سجّل الدخول لعرض الإشعارات',
      );
    }

    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              onPressed: () => service.markAllAsRead(userId),
              icon: const Icon(Icons.done_all_rounded, size: 20),
              label: const Text('تعليم الكل كمقروء'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NotificationModel>>(
            stream: service.streamForUser(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const _EmptyState(
                  icon: Icons.notifications_none_rounded,
                  message: 'لا توجد إشعارات بعد',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => service.delete(item.id),
                    child: _NotificationTile(
                      item: item,
                      onTap: () {
                        service.markAsRead(item.id);
                        _handleTap(context, item);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleTap(BuildContext context, NotificationModel item) {
    final screen = item.data['screen']?.toString();
    switch (screen) {
      case 'chat':
        Navigator.pushNamed(context, '/chat');
        break;
      case 'stats':
        Navigator.pushNamed(context, '/stats');
        break;
      case 'ai_insights':
        Navigator.pushNamed(context, '/ai_insights');
        break;
      default:
        break;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(item.type, context);
    return Material(
      color: item.read
          ? Theme.of(context).cardColor
          : color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(_iconFor(item.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.read
                            ? FontWeight.w500
                            : FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(item.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!item.read)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemindersTab extends StatelessWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final habits = habitProvider.habits;

    final reminders = <_ReminderEntry>[];
    for (final habit in habits) {
      final habitReminders = habit.reminders ?? [];
      for (final r in habitReminders) {
        final hour = (r['hour'] ?? 0) as int;
        final minute = (r['minute'] ?? 0) as int;
        reminders.add(
          _ReminderEntry(
            habit: habit,
            hour: hour,
            minute: minute,
            message: (r['message'] ?? '').toString(),
          ),
        );
      }
    }

    reminders.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });

    if (reminders.isEmpty) {
      return const _EmptyState(
        icon: Icons.alarm_off_rounded,
        message: 'لا توجد تذكيرات مجدولة\nأضف تذكيرًا من شاشة العادة',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: reminders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = reminders[index];
        return Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditHabitScreen(habit: entry.habit),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.timeFormatted,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.habit.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.message.isNotEmpty
                              ? entry.message
                              : 'حان وقت عادتك! 🎯',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _frequencyLabel(entry.habit.frequency),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReminderEntry {
  final HabitModel habit;
  final int hour;
  final int minute;
  final String message;

  _ReminderEntry({
    required this.habit,
    required this.hour,
    required this.minute,
    required this.message,
  });

  String get timeFormatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.chat:
      return Icons.chat_bubble_rounded;
    case AppNotificationType.follow:
      return Icons.person_add_rounded;
    case AppNotificationType.reminder:
      return Icons.alarm_rounded;
    case AppNotificationType.general:
      return Icons.notifications_rounded;
  }
}

Color _colorFor(AppNotificationType type, BuildContext context) {
  switch (type) {
    case AppNotificationType.chat:
      return const Color(0xFF2196F3);
    case AppNotificationType.follow:
      return const Color(0xFF4CAF50);
    case AppNotificationType.reminder:
      return const Color(0xFFFB8C00);
    case AppNotificationType.general:
      return Theme.of(context).colorScheme.primary;
  }
}

String _frequencyLabel(HabitFrequency frequency) {
  switch (frequency) {
    case HabitFrequency.daily:
      return 'يومي';
    case HabitFrequency.weekly:
      return 'أسبوعي';
    case HabitFrequency.custom:
      return 'مخصص';
  }
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  return '${date.day}/${date.month}/${date.year}';
}
