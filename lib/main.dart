import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReminderApp());
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ReminderHomePage(),
    );
  }
}

class ReminderHomePage extends StatefulWidget {
  const ReminderHomePage({super.key});

  @override
  State<ReminderHomePage> createState() => _ReminderHomePageState();
}

class _ReminderHomePageState extends State<ReminderHomePage> {
  final TextEditingController _titleController = TextEditingController();
  DateTime? _selectedDateTime;
  int _nextId = DateTime.now().millisecondsSinceEpoch % 100000;
  List<PendingNotificationRequest> _pending = [];
  bool _notificationsSupported = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await NotificationService().init();
    await NotificationService().requestPermissions();
    await _refreshPending();
    // reflect whether notifications are supported on this platform (web is not)
    if (!mounted) return;
    setState(() => _notificationsSupported = NotificationService().isSupported);
  }

  Future<void> _refreshPending() async {
    final list = await NotificationService().getPendingNotifications();
    if (!mounted) return;
    setState(() => _pending = list);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
    );
    if (time == null) return;

    final DateTime combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!mounted) return;
    setState(() => _selectedDateTime = combined);
  }

  Future<void> _schedule() async {
    final title = _titleController.text.trim();
    final when = _selectedDateTime;
    if (title.isEmpty || when == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title and pick date/time'),
        ),
      );
      return;
    }
    if (when.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a future time')),
      );
      return;
    }

    final id = _nextId++;
    await NotificationService().scheduleNotification(
      id: id,
      title: title,
      body: 'Reminder: $title',
      scheduledDate: when,
    );

    _titleController.clear();
    if (mounted) setState(() => _selectedDateTime = null);
    await _refreshPending();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder scheduled')));
  }

  Future<void> _cancel(int id) async {
    await NotificationService().cancel(id);
    await _refreshPending();
  }

  @override
  Widget build(BuildContext context) {
    String formatDateTime(DateTime dt) {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final d = dt.toLocal();
      final mm = months[d.month - 1];
      final hh = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '${d.day} $mm ${d.year} $hh:$min';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder Scheduler')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Enter reminder title',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDateTime != null
                                  ? 'At: ${formatDateTime(_selectedDateTime!)}'
                                  : 'No date/time selected',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickDateTime,
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Pick'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _notificationsSupported
                                  ? _schedule
                                  : null,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14.0),
                                child: Text('Schedule Reminder'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_notificationsSupported)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Scheduling notifications is not supported on web. Run the app on Android or iOS to test notifications.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pending reminders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _pending.isEmpty
                  ? const Text('No scheduled reminders')
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pending.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, idx) {
                        final pn = _pending[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            title: Text(pn.title ?? 'Reminder'),
                            subtitle: Text(pn.body ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _cancel(pn.id),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
