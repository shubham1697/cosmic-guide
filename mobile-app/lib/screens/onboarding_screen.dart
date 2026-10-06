import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/zodiac_signs_data.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';
import '../widgets/city_autocomplete_field.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(String name, String sign) onComplete;

  /// Name already captured at sign-up; when set, the name step is skipped.
  final String initialName;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.initialName = '',
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  String? _selectedSign;
  String? _selectedBirthPlace;
  String _birthPlaceRawText = '';
  bool _showBirthPlaceError = false;
  bool _isRevealing = false;
  String _tradition = 'western';

  /// True when the user picked a sign themselves instead of accepting the one
  /// derived from their birth date (cusp birthdays can fall either way).
  bool _signOverridden = false;

  bool get _skipNamePage => widget.initialName.trim().isNotEmpty;

  int get _pageCount => _skipNamePage ? 4 : 5;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName.trim();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _calculateZodiac(DateTime date) {
    final month = date.month;
    final day = date.day;
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'Aries';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'Taurus';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'Gemini';
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'Cancer';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Leo';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'Virgo';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'Libra';
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) {
      return 'Scorpio';
    }
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
      return 'Sagittarius';
    }
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
      return 'Capricorn';
    }
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) {
      return 'Aquarius';
    }
    return 'Pisces';
  }

  void _goToNext() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickBirthTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.card,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _birthTime = time;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.card,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _birthDate = date;
        _selectedSign = _calculateZodiac(date);
        _signOverridden = false;
      });
    }
  }

  Future<void> _showSignPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.secondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your sign',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Born on a cusp? Pick whichever sign you identify with.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: zodiacSigns.map((z) {
                  final isSelected = z.name == _selectedSign;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, z.name),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withAlpha(30)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textMuted.withAlpha(51),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(z.symbol, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            z.name,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedSign = picked;
      _signOverridden =
          _birthDate != null && picked != _calculateZodiac(_birthDate!);
    });
  }

  Future<void> _completeOnboarding() async {
    if (_nameController.text.isEmpty || _selectedSign == null) return;
    // Block if user typed a city but didn't confirm a selection from the list.
    if (_birthPlaceRawText.isNotEmpty && _selectedBirthPlace == null) {
      setState(() => _showBirthPlaceError = true);
      return;
    }
    setState(() => _isRevealing = true);
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text);
    await prefs.setString('userSign', _selectedSign!);
    await prefs.setString('tradition', _tradition);
    await prefs.setBool('onboarded', true);
    String? birthTimeValue;
    String? birthDateValue;
    if (_birthTime != null) {
      birthTimeValue =
          '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}';
      await prefs.setString('birthTime', birthTimeValue);
    }
    if (_birthDate != null) {
      birthDateValue =
          '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
      await prefs.setString('birthDate', birthDateValue);
    }
    if (_selectedBirthPlace != null && _selectedBirthPlace!.isNotEmpty) {
      await prefs.setString('birthPlace', _selectedBirthPlace!);
    }

    // Best-effort sync so the profile restores on the user's next device.
    unawaited(
      ApiService.updateProfile(
        name: _nameController.text,
        zodiacSign: _selectedSign,
        tradition: _tradition,
        birthDate: birthDateValue,
        birthTime: birthTimeValue,
        birthPlace: _selectedBirthPlace,
      ),
    );

    widget.onComplete(_nameController.text, _selectedSign!);
  }

  @override
  Widget build(BuildContext context) {
    return StarryBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              _buildWelcomePage(),
              if (!_skipNamePage) _buildNamePage(),
              _buildBirthPage(),
              _buildTraditionPage(),
              _buildBirthDetailsPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 72),
          const SizedBox(height: 32),
          Text(
            'CosmicGuide',
            style: GoogleFonts.playfairDisplay(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your personal astrology companion.\nDiscover what the stars hold for you.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToNext,
              child: const Text('Begin Your Journey'),
            ),
          ),
          const SizedBox(height: 16),
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, color: AppColors.purple, size: 56),
          const SizedBox(height: 24),
          Text(
            'What\'s your name?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The stars wish to know you',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: 'Enter your name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nameController.text.isNotEmpty ? _goToNext : null,
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 16),
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildBirthPage() {
    final sign = _selectedSign != null
        ? zodiacSigns.firstWhere((z) => z.name == _selectedSign)
        : null;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_month,
            color: AppColors.mysticTeal,
            size: 56,
          ),
          const SizedBox(height: 24),
          Text(
            'When were you born?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll calculate your zodiac sign',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickBirthDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _birthDate != null
                      ? AppColors.accent
                      : AppColors.textMuted.withAlpha(77),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                        : 'Tap to select date',
                    style: TextStyle(
                      color: _birthDate != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sign != null) ...[
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Column(
                key: ValueKey(_selectedSign),
                children: [
                  Text(sign.symbol, style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 8),
                  Text(
                    sign.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    sign.dateRange,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_signOverridden)
              Text(
                'Chosen by you',
                style: GoogleFonts.poppins(
                  color: AppColors.mysticTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            TextButton(
              onPressed: _showSignPicker,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                _signOverridden
                    ? 'Pick a different sign'
                    : 'Not your sign? Choose it yourself',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedSign != null ? _goToNext : null,
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 16),
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildBirthDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.access_time, color: AppColors.purple, size: 56),
          const SizedBox(height: 24),
          Text(
            'A little more detail',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional — helps with accurate charts & Kundli',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Birth Time Picker
          GestureDetector(
            onTap: _pickBirthTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _birthTime != null
                      ? AppColors.accent
                      : AppColors.textMuted.withAlpha(77),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Text(
                    _birthTime != null
                        ? _birthTime!.format(context)
                        : 'Tap to select birth time',
                    style: TextStyle(
                      color: _birthTime != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Birth Place Input
          CityAutocompleteField(
            hintText: 'Search birth city…',
            showValidationError: _showBirthPlaceError,
            onRawTextChanged: (text) =>
                setState(() => _birthPlaceRawText = text),
            onCitySelected: (city) {
              setState(() {
                _selectedBirthPlace = city;
                if (city != null) _showBirthPlaceError = false;
              });
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !_isRevealing ? _completeOnboarding : null,
              child: _isRevealing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text('Reveal My Destiny'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: !_isRevealing ? _completeOnboarding : null,
            child: Text(
              'Skip for now',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildTraditionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.auto_awesome, color: AppColors.mysticTeal, size: 56),
          const SizedBox(height: 24),
          Text(
            'How do you read the stars?',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick the tradition you follow — or explore both. You can change this anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _buildTraditionOption(
            value: 'western',
            icon: Icons.wb_sunny_outlined,
            color: AppColors.accent,
            title: 'Western',
            subtitle:
                'Tropical zodiac · Sun-sign horoscopes, birth chart, tarot',
          ),
          _buildTraditionOption(
            value: 'vedic',
            icon: Icons.spa_outlined,
            color: AppColors.mysticTeal,
            title: 'Vedic',
            subtitle: 'Sidereal zodiac · Moon sign (rashi), Kundli, Panchang',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.mysticTeal.withAlpha(51)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.mysticTeal, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Good to know: the two systems differ by ~24°, so in Vedic '
                    'astrology your Sun is often the previous sign.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToNext,
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 12),
          _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildTraditionOption({
    required String value,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _tradition == value;
    return GestureDetector(
      onTap: () => setState(() => _tradition = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : AppColors.textMuted.withAlpha(51),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageCount, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.accent
                : AppColors.textMuted,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
