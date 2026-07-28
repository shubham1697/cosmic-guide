import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/history_service.dart';
import '../widgets/starry_background.dart';

/// A unified timeline of the user's past readings — tarot draws, fortunes, and
/// daily horoscopes — grouped by day, with a filter and a clear action.
class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  List<ReadingEntry> _entries = [];
  bool _loading = true;
  String _filter = 'all';

  static const _filters = <String, String>{
    'all': 'All',
    ReadingType.horoscope: 'Horoscope',
    ReadingType.tarot: 'Tarot',
    ReadingType.fortune: 'Fortune',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await HistoryService.entries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear history?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This permanently removes all recorded readings and resets your stats.',
          style: TextStyle(color: AppColors.textMuted),
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
            child: const Text('Clear', style: TextStyle(color: AppColors.love)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HistoryService.clear();
      await _load();
    }
  }

  List<ReadingEntry> get _filtered => _filter == 'all'
      ? _entries
      : _entries.where((e) => e.type == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Reading History', style: GoogleFonts.playfairDisplay()),
          backgroundColor: Colors.transparent,
          actions: [
            if (_entries.isNotEmpty)
              IconButton(
                onPressed: _confirmClear,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.textMuted,
                tooltip: 'Clear history',
              ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : Column(
                children: [
                  _buildFilterBar(),
                  Expanded(
                    child: _filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: _buildTimeline(_filtered),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: _filters.entries.map((f) {
          final selected = _filter == f.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.gradientPurple : null,
                  color: selected ? null : AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppColors.purple
                        : AppColors.textMuted.withAlpha(60),
                  ),
                ),
                child: Text(
                  f.value,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildTimeline(List<ReadingEntry> items) {
    final widgets = <Widget>[];
    String? lastHeader;
    for (final entry in items) {
      final header = _dateHeader(entry.date);
      if (header != lastHeader) {
        widgets.add(_buildDateHeader(header));
        lastHeader = header;
      }
      widgets.add(_buildEntryCard(entry));
    }
    return widgets;
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildEntryCard(ReadingEntry entry) {
    final (icon, color) = _typeVisual(entry.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(90)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('h:mm a').format(entry.date),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: AppColors.textMuted.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              _filter == 'all'
                  ? 'No readings yet'
                  : 'No ${_filters[_filter]!.toLowerCase()} readings yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Draw a tarot card, generate a fortune, or check your daily '
              'horoscope and it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _typeVisual(String type) => switch (type) {
    ReadingType.tarot => (Icons.style, AppColors.purple),
    ReadingType.fortune => (Icons.auto_awesome, AppColors.accent),
    ReadingType.horoscope => (Icons.wb_sunny_outlined, AppColors.mysticTeal),
    _ => (Icons.circle_outlined, AppColors.textMuted),
  };

  String _dateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(d);
  }
}
