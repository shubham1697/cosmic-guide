import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/zodiac.dart';
import '../services/api_service.dart';
import '../widgets/starry_background.dart';
import 'tarot_screen.dart';
import 'fortune_screen.dart';
import 'story_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final String userSign;

  const DiscoverScreen({super.key, required this.userSign});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<AstrologyStory> _stories = [];
  String _selectedCategory = 'All';
  Set<String> _bookmarkedTitles = {};

  @override
  void initState() {
    super.initState();
    _loadStories();
    _loadBookmarks();
  }

  Future<void> _loadStories() async {
    final stories = await ApiService.getStories();
    if (mounted) setState(() => _stories = stories);
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bookmarked_stories') ?? [];
    if (mounted) setState(() => _bookmarkedTitles = saved.toSet());
  }

  Future<void> _toggleBookmark(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_bookmarkedTitles.contains(title)) {
        _bookmarkedTitles.remove(title);
      } else {
        _bookmarkedTitles.add(title);
      }
    });
    await prefs.setStringList('bookmarked_stories', _bookmarkedTitles.toList());
  }

  @override
  Widget build(BuildContext context) {
    final rawCategories =
        _stories
            .map((s) => s.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final categories = ['All', '⭐ Saved', ...rawCategories];

    final filtered = _selectedCategory == 'All'
        ? _stories
        : _selectedCategory == '⭐ Saved'
        ? _stories.where((s) => _bookmarkedTitles.contains(s.title)).toList()
        : _stories.where((s) => s.category == _selectedCategory).toList();

    return StarryBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: _loadStories,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (Navigator.of(context).canPop())
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Back',
                            color: AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                      Text(
                        'Discover',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Explore the cosmic realm',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.style,
                              title: 'Tarot',
                              subtitle: 'Draw your card',
                              color: AppColors.purple,
                              gradient: AppColors.gradientPurple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TarotScreen(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.auto_awesome,
                              title: 'Fortune',
                              subtitle: 'Get your reading',
                              color: AppColors.accent,
                              gradient: AppColors.gradientGold,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FortuneScreen(userSign: widget.userSign),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text(
                            'Cosmic Stories',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          Text(
                            '${filtered.length} articles',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final cat = categories[i];
                            final isSelected = cat == _selectedCategory;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accent.withAlpha(30)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.textMuted.withAlpha(51),
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _StoryCard(
                      story: filtered[i],
                      isBookmarked: _bookmarkedTitles.contains(
                        filtered[i].title,
                      ),
                      onBookmarkToggle: () =>
                          _toggleBookmark(filtered[i].title),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Gradient gradient;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(77)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: color, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final AstrologyStory story;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  const _StoryCard({
    required this.story,
    required this.isBookmarked,
    required this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StoryDetailScreen(story: story)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.gradientPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    story.summary,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                GestureDetector(
                  onTap: onBookmarkToggle,
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked
                        ? AppColors.accent
                        : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  story.readTime,
                  style: const TextStyle(color: AppColors.accent, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
