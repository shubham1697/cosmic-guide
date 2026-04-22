import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/zodiac_signs_data.dart';
import '../widgets/starry_background.dart';

class ProfileScreen extends StatefulWidget {
  final String userSign;
  final String userName;
  final void Function(String name, String sign)? onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.userSign,
    required this.userName,
    this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _name;
  late String _sign;
  String _birthDate = '';
  String _birthTime = '';
  String _birthPlace = '';

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _sign = widget.userSign;
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _birthDate = prefs.getString('birthDate') ?? '';
        _birthTime = prefs.getString('birthTime') ?? '';
        _birthPlace = prefs.getString('birthPlace') ?? '';
      });
    }
  }

  String _calculateZodiac(DateTime date) {
    final m = date.month;
    final d = date.day;
    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'Aries';
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'Taurus';
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'Gemini';
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'Cancer';
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'Leo';
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'Virgo';
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'Libra';
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'Scorpio';
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return 'Sagittarius';
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'Capricorn';
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'Aquarius';
    return 'Pisces';
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        initialName: _name,
        initialSign: _sign,
        initialBirthDate: _birthDate,
        initialBirthTime: _birthTime,
        initialBirthPlace: _birthPlace,
        calculateZodiac: _calculateZodiac,
        onSave: (name, sign, birthDate, birthTime, birthPlace) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', name);
          await prefs.setString('userSign', sign);
          await prefs.setString('birthDate', birthDate);
          await prefs.setString('birthTime', birthTime);
          await prefs.setString('birthPlace', birthPlace);
          if (mounted) {
            setState(() {
              _name = name;
              _sign = sign;
              _birthDate = birthDate;
              _birthTime = birthTime;
              _birthPlace = birthPlace;
            });
            widget.onProfileUpdated?.call(name, sign);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sign = zodiacSigns.firstWhere(
      (z) => z.name == _sign,
      orElse: () => zodiacSigns.first,
    );
    final traits = _getTraits(_sign);

    return StarryBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildAvatar(sign),
              const SizedBox(height: 16),
              Text(
                _name,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sign.name} ${sign.symbol} | ${sign.dateRange}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openEditSheet,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withAlpha(128)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 28),
              _buildBirthDetails(),
              const SizedBox(height: 28),
              _buildStatsRow(),
              const SizedBox(height: 28),
              _buildPersonalitySection(sign, traits),
              const SizedBox(height: 24),
              _buildSignDetails(sign),
              const SizedBox(height: 24),
              _buildPremiumCard(),
              const SizedBox(height: 24),
              _buildMenuItems(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(dynamic sign) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.gradientPurple,
        border: Border.all(color: AppColors.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withAlpha(102),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(sign.symbol, style: const TextStyle(fontSize: 44)),
      ),
    );
  }

  Widget _buildBirthDetails() {
    final hasAny =
        _birthDate.isNotEmpty ||
        _birthTime.isNotEmpty ||
        _birthPlace.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cake_outlined,
                color: AppColors.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Birth Details',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasAny)
            GestureDetector(
              onTap: _openEditSheet,
              child: const Text(
                'Tap to add birth date, time and place for accurate chart readings.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            )
          else ...[
            if (_birthDate.isNotEmpty)
              _detailChip(Icons.calendar_today, 'Date', _birthDate),
            if (_birthTime.isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailChip(Icons.access_time, 'Time', _birthTime),
            ],
            if (_birthPlace.isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailChip(Icons.location_on_outlined, 'Place', _birthPlace),
            ],
          ],
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStat('Readings', '0'),
        Container(
          width: 1,
          height: 40,
          color: AppColors.textMuted.withAlpha(51),
        ),
        _buildStat('Streak', '0 days'),
        Container(
          width: 1,
          height: 40,
          color: AppColors.textMuted.withAlpha(51),
        ),
        _buildStat('Fortune', '0'),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPersonalitySection(dynamic sign, Map<String, String> traits) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personality Traits',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTraitRow('Strengths', traits['strengths']!, AppColors.health),
          const SizedBox(height: 12),
          _buildTraitRow('Weaknesses', traits['weaknesses']!, AppColors.love),
          const SizedBox(height: 12),
          _buildTraitRow(
            'Emotional',
            traits['emotional']!,
            AppColors.mysticTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildTraitRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignDetails(dynamic sign) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.water_drop, 'Element', sign.element),
          const Divider(color: AppColors.surface, height: 24),
          _buildDetailRow(Icons.public, 'Ruling Planet', sign.rulingPlanet),
          const Divider(color: AppColors.surface, height: 24),
          _buildDetailRow(Icons.calendar_today, 'Date Range', sign.dateRange),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientGold,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'Unlock advanced reports & unlimited readings',
                  style: TextStyle(color: AppColors.secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            color: AppColors.primary,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final items = [
      _MenuItem(
        Icons.notifications_outlined,
        'Notifications',
        AppColors.accent,
      ),
      _MenuItem(Icons.history, 'Reading History', AppColors.purple),
      _MenuItem(Icons.settings_outlined, 'Settings', AppColors.textSecondary),
      _MenuItem(Icons.help_outline, 'Help & Support', AppColors.mysticTeal),
    ];

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(item.icon, color: item.color),
            title: Text(
              item.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Map<String, String> _getTraits(String sign) {
    final allTraits = {
      'Aries': {
        'strengths': 'Courageous, determined, confident, enthusiastic',
        'weaknesses': 'Impatient, moody, aggressive',
        'emotional': 'Passionate and direct with feelings',
      },
      'Taurus': {
        'strengths': 'Reliable, patient, devoted, stable',
        'weaknesses': 'Stubborn, possessive, uncompromising',
        'emotional': 'Deep and steady emotional connections',
      },
      'Gemini': {
        'strengths': 'Versatile, curious, witty, communicative',
        'weaknesses': 'Inconsistent, restless, superficial',
        'emotional': 'Expressive yet guarded, processes feelings through words',
      },
      'Cancer': {
        'strengths': 'Nurturing, protective, loyal, empathetic',
        'weaknesses': 'Overly sensitive, clingy, moody',
        'emotional': 'Deeply intuitive with powerful emotional memory',
      },
      'Leo': {
        'strengths': 'Generous, warm-hearted, creative, charismatic',
        'weaknesses': 'Arrogant, stubborn, attention-seeking',
        'emotional': 'Wears heart on sleeve, needs admiration and loyalty',
      },
      'Virgo': {
        'strengths': 'Analytical, practical, diligent, detail-oriented',
        'weaknesses': 'Overly critical, perfectionist, anxious',
        'emotional': 'Reserved on the surface but deeply caring underneath',
      },
      'Libra': {
        'strengths': 'Diplomatic, gracious, fair-minded, social',
        'weaknesses': 'Indecisive, avoids confrontation, people-pleasing',
        'emotional': 'Seeks harmony in all relationships, dislikes conflict',
      },
      'Scorpio': {
        'strengths': 'Resourceful, brave, passionate, loyal',
        'weaknesses': 'Jealous, secretive, dominating',
        'emotional': 'Intensely emotional and deeply intuitive',
      },
      'Sagittarius': {
        'strengths': 'Optimistic, adventurous, honest, philosophical',
        'weaknesses': 'Tactless, impatient, overconfident',
        'emotional':
            'Free-spirited, avoids heavy emotions but deeply idealistic',
      },
      'Capricorn': {
        'strengths': 'Disciplined, ambitious, responsible, patient',
        'weaknesses': 'Pessimistic, rigid, workaholic tendencies',
        'emotional': 'Guarded but fiercely loyal once trust is earned',
      },
      'Aquarius': {
        'strengths': 'Progressive, original, independent, humanitarian',
        'weaknesses': 'Emotionally detached, unpredictable, aloof',
        'emotional': 'Values intellectual bonds, struggles with vulnerability',
      },
      'Pisces': {
        'strengths': 'Compassionate, artistic, intuitive, gentle',
        'weaknesses': 'Escapist, overly trusting, easily overwhelmed',
        'emotional':
            'Absorbs others\u2019 emotions like a sponge, deeply empathetic',
      },
    };
    return allTraits[sign] ??
        {
          'strengths': 'Adaptable, intuitive, creative, compassionate',
          'weaknesses': 'Overthinking, indecisive at times',
          'emotional': 'Deeply empathetic and emotionally aware',
        };
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem(this.icon, this.label, this.color);
}

// ─── Edit Profile Bottom Sheet ────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialSign;
  final String initialBirthDate;
  final String initialBirthTime;
  final String initialBirthPlace;
  final String Function(DateTime) calculateZodiac;
  final void Function(
    String name,
    String sign,
    String birthDate,
    String birthTime,
    String birthPlace,
  )
  onSave;

  const _EditProfileSheet({
    required this.initialName,
    required this.initialSign,
    required this.initialBirthDate,
    required this.initialBirthTime,
    required this.initialBirthPlace,
    required this.calculateZodiac,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _placeController;
  late String _selectedSign;
  DateTime? _birthDate;
  TimeOfDay? _birthTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _placeController = TextEditingController(text: widget.initialBirthPlace);
    _selectedSign = widget.initialSign;

    if (widget.initialBirthDate.isNotEmpty) {
      try {
        final parts = widget.initialBirthDate.split('-');
        if (parts.length == 3) {
          _birthDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
    }

    if (widget.initialBirthTime.isNotEmpty) {
      try {
        final parts = widget.initialBirthTime.split(':');
        if (parts.length == 2) {
          _birthTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1995),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _birthDate = date;
        _selectedSign = widget.calculateZodiac(date);
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _birthTime = time);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final birthDate = _birthDate != null
        ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
        : widget.initialBirthDate;
    final birthTime = _birthTime != null
        ? '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}'
        : widget.initialBirthTime;
    widget.onSave(
      name,
      _selectedSign,
      birthDate,
      birthTime,
      _placeController.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kbHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + kbHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Edit Profile',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _label('Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Your name',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Date of Birth'),
            const SizedBox(height: 8),
            _tapField(
              icon: Icons.calendar_today,
              text: _birthDate != null
                  ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                  : 'Select date',
              isEmpty: _birthDate == null,
              onTap: _pickDate,
            ),
            if (_birthDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.accent,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Zodiac auto-updated to $_selectedSign',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _label('Birth Time'),
            const SizedBox(height: 8),
            _tapField(
              icon: Icons.access_time,
              text: _birthTime != null
                  ? _birthTime!.format(context)
                  : 'Select time (optional)',
              isEmpty: _birthTime == null,
              onTap: _pickTime,
            ),
            const SizedBox(height: 6),
            const Text(
              'Used for accurate Moon & Rising sign calculation.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 20),
            _label('Birth Place'),
            const SizedBox(height: 8),
            TextField(
              controller: _placeController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'City, Country (optional)',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_birthDate == null) ...[
              _label('Zodiac Sign'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textMuted.withAlpha(51)),
                ),
                child: DropdownButton<String>(
                  value: _selectedSign,
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  underline: const SizedBox(),
                  items: zodiacSigns.map((z) {
                    return DropdownMenuItem(
                      value: z.name,
                      child: Text(
                        '${z.symbol}  ${z.name}',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedSign = v);
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _tapField({
    required IconData icon,
    required String text,
    required bool isEmpty,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textMuted.withAlpha(51)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
