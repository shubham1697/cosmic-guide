import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'models/zodiac.dart';
import 'services/api_service.dart';
import 'services/sign_resolver.dart';
import 'screens/home_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/vedic_home_screen.dart';
import 'screens/match_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';

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
  bool _showSplash = true;
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

  void _onSplashComplete() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

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

enum AppTab { home, chart, vedic, match, profile }

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
  String _tradition = 'both';

  // Resolved reading identity (see SignResolver): which sign + system the
  // daily reading is keyed on. Western/Both use the tropical Sun sign; Vedic
  // uses the sidereal Moon rashi. Defaults track the Sun sign until resolved.
  String _readingSign = '';
  String _system = 'western';
  bool _needsBirthDetailsForVedic = false;

  // Tabs shown depend on the chosen reading tradition. 'both' (default) sees
  // everything; 'western'/'vedic' get a focused nav.
  List<AppTab> get _visibleTabs => switch (_tradition) {
    'western' => const [
      AppTab.home,
      AppTab.chart,
      AppTab.match,
      AppTab.profile,
    ],
    'vedic' => const [AppTab.home, AppTab.vedic, AppTab.match, AppTab.profile],
    _ => const [
      AppTab.home,
      AppTab.chart,
      AppTab.vedic,
      AppTab.match,
      AppTab.profile,
    ],
  };

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _userSign = widget.userSign;
    _readingSign = widget.userSign;
    _init();
  }

  // Birth data (tradition + birth details) must be loaded before the horoscope
  // is fetched, because the reading identity depends on them.
  Future<void> _init() async {
    await _loadBirthData();
    await _fetchSharedHoroscope();
  }

  Future<void> _loadBirthData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    // Remember the current tab so we can keep the user on it if the visible
    // set changes (e.g. they switched tradition in Profile).
    final currentTab =
        _visibleTabs[_currentIndex.clamp(0, _visibleTabs.length - 1)];
    setState(() {
      _birthDate = prefs.getString('birthDate') ?? '';
      _birthTime = prefs.getString('birthTime') ?? '';
      _birthPlace = prefs.getString('birthPlace') ?? '';
      _tradition = prefs.getString('tradition') ?? 'both';
      final idx = _visibleTabs.indexOf(currentTab);
      _currentIndex = idx == -1 ? 0 : idx;
    });
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
    final identity = await SignResolver.resolve(
      tradition: _tradition,
      sunSign: _userSign,
      birthDate: _birthDate.isNotEmpty ? _birthDate : null,
      birthTime: _birthTime.isNotEmpty ? _birthTime : null,
      birthPlace: _birthPlace.isNotEmpty ? _birthPlace : null,
    );
    final data = await ApiService.getHoroscope(
      identity.readingSign,
      system: identity.system,
    );
    if (mounted) {
      setState(() {
        _readingSign = identity.readingSign;
        _system = identity.system;
        _needsBirthDetailsForVedic = identity.needsBirthDetailsForVedic;
        _sharedHoroscope = data;
      });
    }
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
    _reloadForProfileChange();
  }

  // Reload birth data first (tradition / birth details may have changed), then
  // re-resolve and fetch the horoscope so the identity stays consistent.
  Future<void> _reloadForProfileChange() async {
    await _loadBirthData();
    await _fetchSharedHoroscope();
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _navigateToAppTab(AppTab tab) {
    final idx = _visibleTabs.indexOf(tab);
    if (idx != -1) setState(() => _currentIndex = idx);
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Exit CosmicGuide?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'The stars will await your return.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Stay',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Exit',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs;
    final safeIndex = _currentIndex.clamp(0, tabs.length - 1);
    final screens = tabs.map(_screenFor).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(index: safeIndex, children: screens),
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
            currentIndex: safeIndex,
            onTap: _navigateToTab,
            items: tabs.map(_navItemFor).toList(),
          ),
        ),
      ),
    );
  }

  Widget _screenFor(AppTab tab) => switch (tab) {
    AppTab.home => HomeScreen(
      userName: _userName,
      userSign: _userSign,
      readingSign: _readingSign.isNotEmpty ? _readingSign : _userSign,
      system: _system,
      needsBirthDetailsForVedic: _needsBirthDetailsForVedic,
      tradition: _tradition,
      birthDate: _birthDate.isNotEmpty ? _birthDate : null,
      birthTime: _birthTime.isNotEmpty ? _birthTime : null,
      birthPlace: _birthPlace.isNotEmpty ? _birthPlace : null,
      initialHoroscope: _sharedHoroscope,
      onHoroscopeUpdated: _updateSharedHoroscope,
      onOpenProfile: () => _navigateToAppTab(AppTab.profile),
    ),
    AppTab.chart => ChartScreen(
      userSign: _userSign,
      initialHoroscope: _sharedHoroscope,
      onHoroscopeUpdated: _updateSharedHoroscope,
      birthDate: _birthDate.isNotEmpty ? _birthDate : null,
      birthTime: _birthTime.isNotEmpty ? _birthTime : null,
      birthPlace: _birthPlace.isNotEmpty ? _birthPlace : null,
    ),
    AppTab.vedic => VedicHomeScreen(
      birthDate: _birthDate.isNotEmpty ? _birthDate : null,
      birthTime: _birthTime.isNotEmpty ? _birthTime : null,
      birthPlace: _birthPlace.isNotEmpty ? _birthPlace : null,
    ),
    AppTab.match => const MatchScreen(),
    AppTab.profile => ProfileScreen(
      userSign: _userSign,
      userName: _userName,
      onProfileUpdated: _onProfileUpdated,
    ),
  };

  BottomNavigationBarItem _navItemFor(AppTab tab) => switch (tab) {
    AppTab.home => const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    AppTab.chart => const BottomNavigationBarItem(
      icon: Icon(Icons.auto_awesome_outlined),
      activeIcon: Icon(Icons.auto_awesome),
      label: 'Chart',
    ),
    AppTab.vedic => BottomNavigationBarItem(
      icon: const Icon(Icons.spa_outlined),
      activeIcon: const Icon(Icons.spa),
      label: _tradition == 'vedic' ? 'Kundli' : 'Vedic',
    ),
    AppTab.match => const BottomNavigationBarItem(
      icon: Icon(Icons.favorite_outline),
      activeIcon: Icon(Icons.favorite),
      label: 'Match',
    ),
    AppTab.profile => const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  };
}
