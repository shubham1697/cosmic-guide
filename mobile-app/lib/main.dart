import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'models/zodiac.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/match_screen.dart';
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
  String _userName = '';
  String _userSign = '';
  String _birthDate = '';
  String _birthTime = '';
  String _birthPlace = '';

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _userSign = widget.userSign;
    _fetchSharedHoroscope();
    _loadBirthData();
  }

  Future<void> _loadBirthData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _birthDate = prefs.getString('birthDate') ?? '';
        _birthTime = prefs.getString('birthTime') ?? '';
        _birthPlace = prefs.getString('birthPlace') ?? '';
      });
    }
  }

  @override
  void didUpdateWidget(MainShell old) {
    super.didUpdateWidget(old);
    // Sync when AppEntry re-passes updated prefs values
    if (widget.userName != old.userName && _userName == old.userName) {
      _userName = widget.userName;
    }
    if (widget.userSign != old.userSign && _userSign == old.userSign) {
      _userSign = widget.userSign;
      _sharedHoroscope = null;
      _fetchSharedHoroscope();
    }
  }

  Future<void> _fetchSharedHoroscope() async {
    final data = await ApiService.getHoroscope(_userSign);
    if (mounted) setState(() => _sharedHoroscope = data);
  }

  void _updateSharedHoroscope(HoroscopeData data) {
    if (!mounted) return;
    if (_sharedHoroscope == data) return;
    setState(() => _sharedHoroscope = data);
  }

  void _onProfileUpdated(String name, String sign) {
    setState(() {
      _userName = name;
      _userSign = sign;
      _sharedHoroscope = null;
    });
    _fetchSharedHoroscope();
    _loadBirthData();
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        userName: _userName,
        userSign: _userSign,
        initialHoroscope: _sharedHoroscope,
        onHoroscopeUpdated: _updateSharedHoroscope,
        onChartTap: () => _navigateToTab(1),
        onDiscoverTap: () => _navigateToTab(2),
      ),
      ChartScreen(
        userSign: _userSign,
        initialHoroscope: _sharedHoroscope,
        onHoroscopeUpdated: _updateSharedHoroscope,
        birthDate: _birthDate.isNotEmpty ? _birthDate : null,
        birthTime: _birthTime.isNotEmpty ? _birthTime : null,
        birthPlace: _birthPlace.isNotEmpty ? _birthPlace : null,
      ),
      DiscoverScreen(userSign: _userSign),
      const MatchScreen(),
      ProfileScreen(
        userSign: _userSign,
        userName: _userName,
        onProfileUpdated: _onProfileUpdated,
      ),
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
              label: 'Chart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Discover',
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
}
