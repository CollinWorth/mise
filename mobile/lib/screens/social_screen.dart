import 'package:flutter/material.dart';
import 'feed_screen.dart';
import 'explore_screen.dart';
import 'user_search_screen.dart';

const _kBg = Color(0xFFF7F6F3);
const _kDark = Color(0xFF1A1918);
const _kBorder = Color(0xFFE5E2DC);

class SocialScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRecipeSaved;
  const SocialScreen({super.key, required this.user, this.onRecipeSaved});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _tab = 0; // 0 = Feed, 1 = Explore, 2 = People
  final _feedKey = GlobalKey<FeedScreenState>();

  @override
  Widget build(BuildContext context) {
    final bg        = Theme.of(context).scaffoldBackgroundColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface   = Theme.of(context).colorScheme.surface;
    final border    = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header with pill switcher ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  _pill('Feed',    0, onSurface, surface, border),
                  const SizedBox(width: 8),
                  _pill('Explore', 1, onSurface, surface, border),
                  const SizedBox(width: 8),
                  _pill('People',  2, onSurface, surface, border),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  FeedScreen(key: _feedKey, user: widget.user, embedded: true),
                  ExploreScreen(user: widget.user, embedded: true, onRecipeSaved: widget.onRecipeSaved),
                  UserSearchScreen(
                    currentUser: widget.user,
                    onFollowChanged: () => _feedKey.currentState?.reload(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, int index, Color onSurface, Color surface, Color border) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? onSurface : surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? onSurface : border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? surface : onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}
