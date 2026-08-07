import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../widgets/starry_background.dart';

/// Settings screen for push notifications. Lets the user toggle the daily
/// horoscope reminder, shows whether push is fully configured, and offers a
/// test send. Preferences are persisted locally and synced to the backend by
/// [NotificationService] once a push token is available.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  bool _pushAvailable = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  String _sign = 'Aries';
  String _tradition = 'both';
  String _birthDate = '';
  String _birthTime = '';
  String _birthPlace = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = await NotificationService.isEnabled();
    final available = await NotificationService.isPushAvailable();
    final time = await NotificationService.getReminderTime();
    if (!mounted) return;
    setState(() {
      _sign = prefs.getString('userSign') ?? 'Aries';
      _tradition = prefs.getString('tradition') ?? 'both';
      _birthDate = prefs.getString('birthDate') ?? '';
      _birthTime = prefs.getString('birthTime') ?? '';
      _birthPlace = prefs.getString('birthPlace') ?? '';
      _enabled = enabled;
      _pushAvailable = available;
      _reminderTime = TimeOfDay(hour: time.$1, minute: time.$2);
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _enabled = value;
      _busy = true;
    });
    final ok = await NotificationService.setEnabled(
      enabled: value,
      zodiacSign: _sign,
      tradition: _tradition,
      birthDate: _birthDate,
      birthTime: _birthTime,
      birthPlace: _birthPlace,
    );
    final available = await NotificationService.isPushAvailable();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pushAvailable = available;
    });
    final messenger = ScaffoldMessenger.of(context);
    if (value && !ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Enable notifications in Settings to receive your reminder.',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Daily reminder set for ${_formatTime(_reminderTime)}.'
                : 'Daily reminder turned off.',
          ),
        ),
      );
    }
  }

  Future<void> _sendTest() async {
    setState(() => _busy = true);
    final sent = await NotificationService.sendTest();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Test notification sent.'
              : 'Enable notifications in Settings to see it.',
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Daily reminder time',
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderTime = picked);
    await NotificationService.setReminderTime(
      hour: picked.hour,
      minute: picked.minute,
      zodiacSign: _sign,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _enabled
              ? 'Reminder time updated to ${_formatTime(picked)}.'
              : 'Reminder time set to ${_formatTime(picked)}.',
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) => t.format(context);

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Notifications', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildReminderCard(),
                  const SizedBox(height: 20),
                  _buildTestButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final active = _pushAvailable;
    final color = active ? AppColors.health : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.notifications_active : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              active
                  ? 'Notifications are on for this device. Your daily reminder '
                        'will arrive at the time you choose below.'
                  : 'Notifications are turned off for CosmicGuide. Enable them '
                        'in your device Settings to receive your daily reminder.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _enabled,
            onChanged: _busy ? null : _toggle,
            activeThumbColor: AppColors.accent,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              'Daily horoscope reminder',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'A gentle nudge with your reading each day.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.textMuted.withAlpha(38),
          ),
          ListTile(
            enabled: _enabled && !_busy,
            onTap: (_enabled && !_busy) ? _pickTime : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(
              Icons.schedule,
              color: _enabled ? AppColors.accent : AppColors.textMuted,
            ),
            title: Text(
              'Reminder time',
              style: GoogleFonts.poppins(
                color: _enabled ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Text(
              _formatTime(_reminderTime),
              style: GoogleFonts.poppins(
                color: _enabled ? AppColors.accent : AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _sendTest,
        icon: const Icon(Icons.send_outlined, size: 18),
        label: const Text('Send test notification'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
