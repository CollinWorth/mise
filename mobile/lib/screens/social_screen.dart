import 'package:flutter/material.dart';
import 'feed_screen.dart';
import 'explore_screen.dart';
import 'user_search_screen.dart';

const _kBg = Color(0xFFF7F6F3);
const _kDark = Color(0xFF1A1918);
const _kBorder = Color(0xFFE5E2DC);

class SocialScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const SocialScreen({super.key, required this.user});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _tab = 0; // 0 = Feed, 1 = Explore, 2 = People

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
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
                  _pill('Feed', 0),
                  const SizedBox(width: 8),
                  _pill('Explore', 1),
                  const SizedBox(width: 8),
                  _pill('People', 2),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  FeedScreen(user: widget.user, embedded: true),
                  ExploreScreen(user: widget.user, embedded: true),
                  UserSearchScreen(currentUser: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kDark : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? _kDark : _kBorder, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF555250),
          ),
        ),
      ),
    );
  }
}
