import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'models/zodiac.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/horoscope_screen.dart';
import 'screens/tarot_screen.dart';
import 'screens/fortune_screen.dart';
import 'screens/compatibility_screen.dart';
import 'screens/kundli_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(const CosmicGuideApp());
}

class CosmicGuideApp extends StatelessWidget {
  const CosmicGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmicGuide',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _loading = true;
  bool _onboarded = false;
  String _userName = '';
  String _userSign = 'Aries';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboarded = prefs.getBool('onboarded') ?? false;
      _userName = prefs.getString('userName') ?? '';
      _userSign = prefs.getString('userSign') ?? 'Aries';
      _loading = false;
    });
  }

  void _onOnboardingComplete(String name, String sign) {
    setState(() {
      _userName = name;
      _userSign = sign;
      _onboarded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (!_onboarded) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    return MainShell(userName: _userName, userSign: _userSign);
  }
}

class MainShell extends StatefulWidget {
  final String userName;
  final String userSign;

  const MainShell({super.key, required this.userName, required this.userSign});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  HoroscopeData? _sharedHoroscope;

  @override
  void initState() {
    super.initState();
    _fetchSharedHoroscope();
  }

  Future<void> _fetchSharedHoroscope() async {
    final data = await ApiService.getHoroscope(widget.userSign);
    if (mounted) setState(() => _sharedHoroscope = data);
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        userName: widget.userName,
        userSign: widget.userSign,
        initialHoroscope: _sharedHoroscope,
        onHoroscopeTap: () => _navigateToTab(1),
        onTarotTap: () => _pushScreen(context, const TarotScreen()),
        onFortuneTap: () =>
            _pushScreen(context, FortuneScreen(userSign: widget.userSign)),
        onCompatibilityTap: () =>
            _pushScreen(context, const CompatibilityScreen()),
        onKundliTap: () => _pushScreen(context, const KundliScreen()),
      ),
      HoroscopeScreen(
        userSign: widget.userSign,
        initialHoroscope: _sharedHoroscope,
      ),
      const TarotScreen(),
      const CompatibilityScreen(),
      ProfileScreen(userSign: widget.userSign, userName: widget.userName),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.secondary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome),
              label: 'Horoscope',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.style_outlined),
              activeIcon: Icon(Icons.style),
              label: 'Tarot',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: 'Match',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _pushScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
