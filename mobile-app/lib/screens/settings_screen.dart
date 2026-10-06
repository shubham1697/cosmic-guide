import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_service.dart';
import '../services/sign_resolver.dart';
import '../widgets/starry_background.dart';
import 'help_screen.dart';
import 'notifications_screen.dart';

/// App-wide settings: reminders, local data management and app info.
///
/// Everything here acts on device-local state — CosmicGuide has no accounts,
/// so "delete all app data" really does erase everything the app holds.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remindersOn = false;
  TimeOfDay _reminderTime = const TimeOfDay(
    hour: NotificationService.defaultHour,
    minute: NotificationService.defaultMinute,
  );
  String _tradition = 'western';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = await NotificationService.isEnabled();
    final time = await NotificationService.getReminderTime();
    if (!mounted) return;
    setState(() {
      _remindersOn = enabled;
      _reminderTime = TimeOfDay(hour: time.$1, minute: time.$2);
      _tradition = normalizeTradition(prefs.getString('tradition'));
    });
  }

  String get _traditionLabel => switch (_tradition) {
    'vedic' => 'Vedic (Jyotish)',
    _ => 'Western',
  };

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    await _load();
  }

  Future<void> _refreshCaches() async {
    setState(() => _busy = true);
    final prefs = await SharedPreferences.getInstance();
    ApiService.clearCache();
    await SignResolver.clearCache();
    for (final key in const [
      'daily_tarot_date',
      'daily_tarot_name',
      'daily_tarot_number',
      'daily_tarot_meaning',
      'daily_tarot_interpretation',
      'daily_tarot_reversed_interpretation',
      'daily_tarot_reversed',
    ]) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _toast('Cached readings cleared. Pull to refresh on Home.');
  }

  Future<void> _clearHistory() async {
    final confirmed = await _confirm(
      title: 'Clear reading history?',
      message:
          'Your saved horoscope, tarot and fortune entries will be removed, '
          'and your streak will restart. Your profile stays.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    await HistoryService.clear();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast('Reading history cleared.');
  }

  Future<void> _deleteEverything() async {
    final confirmed = await _confirm(
      title: 'Delete all app data?',
      message:
          'This erases your name, birth details, reading history, bookmarks '
          'and reminders from this device. The app returns to onboarding. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);

    await LocalNotificationService.cancelDaily();
    ApiService.clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    // Rebuild from the app root so onboarding reads the now-empty prefs.
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppEntry()),
      (route) => false,
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? AppColors.love : AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Settings', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _section('Reminders'),
              _card([
                _tile(
                  icon: Icons.notifications_outlined,
                  color: AppColors.accent,
                  title: 'Daily reminder',
                  subtitle: _remindersOn
                      ? 'On · ${_reminderTime.format(context)}'
                      : 'Off',
                  onTap: _openNotifications,
                ),
              ]),
              const SizedBox(height: 24),
              _section('Reading style'),
              _card([
                _tile(
                  icon: Icons.auto_awesome_outlined,
                  color: AppColors.purple,
                  title: 'Tradition',
                  subtitle: '$_traditionLabel · change in Profile → Edit',
                  trailing: const SizedBox.shrink(),
                ),
              ]),
              const SizedBox(height: 24),
              _section('Data'),
              _card([
                _tile(
                  icon: Icons.refresh,
                  color: AppColors.mysticTeal,
                  title: 'Refresh cached readings',
                  subtitle:
                      'Clears today\'s cached horoscope, tarot and chart data',
                  onTap: _refreshCaches,
                ),
                _divider(),
                _tile(
                  icon: Icons.history,
                  color: AppColors.textSecondary,
                  title: 'Clear reading history',
                  subtitle: 'Removes saved readings and resets your streak',
                  onTap: _clearHistory,
                ),
                _divider(),
                _tile(
                  icon: Icons.delete_outline,
                  color: AppColors.love,
                  title: 'Delete all app data',
                  subtitle: 'Erase everything and start over',
                  titleColor: AppColors.love,
                  onTap: _deleteEverything,
                ),
              ]),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Your name, birth details and readings are stored on this '
                  'device. Birth details are sent to the CosmicGuide server '
                  'only to calculate a chart, and are not tied to an account.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _section('About'),
              _card([
                _tile(
                  icon: Icons.help_outline,
                  color: AppColors.mysticTeal,
                  title: 'Help & Support',
                  subtitle: 'FAQs and how to reach us',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _card(List<Widget> children) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );

  Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    indent: 56,
    color: AppColors.textMuted.withAlpha(30),
  );

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: titleColor ?? AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
      ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                )),
    );
  }
}
