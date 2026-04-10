import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../storage/storage.dart';
import 'public_recipe_detail_screen.dart';
import 'user_profile_screen.dart';

const _kAccent = Color(0xFFE8622A);
const _kBg = Color(0xFFF7F6F3);
const _kDark = Color(0xFF1A1918);
const _kBorder = Color(0xFFE5E2DC);
const _kTextSec = Color(0xFF888480);

class FeedScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool embedded;
  const FeedScreen({super.key, required this.user, this.embedded = false});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  Set<String> _likedIds = {};
  Map<String, int> _likeCounts = {};
  Set<String> _savedIds = {};

  @override
  void initState() {
    super.initState();
    _loadLiked();
    _load();
  }

  bool get _isServer => Store.isReady && Store.i.mode == StorageMode.server;

  Future<void> _loadLiked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mise_liked');
    if (raw != null && mounted) {
      setState(() => _likedIds = Set.from((jsonDecode(raw) as List).cast<String>()));
    }
  }

  Future<void> _persistLiked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mise_liked', jsonEncode(_likedIds.toList()));
  }

  Future<void> _load() async {
    if (!_isServer) { if (mounted) setState(() => _loading = false); return; }
    try {
      final r = await Api.get('/recipes/feed');
      if (r.statusCode == 200) {
        final data = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        final counts = <String, int>{};
        for (final p in data) counts[p['_id'] as String] = (p['like_count'] as num?)?.toInt() ?? 0;
        if (mounted) setState(() { _posts = data; _likeCounts = counts; });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLike(String id) async {
    final wasLiked = _likedIds.contains(id);
    final delta = wasLiked ? -1 : 1;
    setState(() {
      wasLiked ? _likedIds.remove(id) : _likedIds.add(id);
      _likeCounts[id] = ((_likeCounts[id] ?? 0) + delta).clamp(0, 999999);
    });
    await _persistLiked();
    try {
      await Api.post('/recipes/$id/${wasLiked ? 'unlike' : 'like'}', {});
    } catch (_) {
      if (mounted) setState(() {
        wasLiked ? _likedIds.add(id) : _likedIds.remove(id);
        _likeCounts[id] = ((_likeCounts[id] ?? 0) - delta).clamp(0, 999999);
      });
    }
  }

  Future<void> _save(String id) async {
    if (_savedIds.contains(id)) return;
    try {
      final r = await Api.post('/recipes/$id/save', {});
      if (r.statusCode == 200 && mounted) setState(() => _savedIds.add(id));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Feed', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  ),
                  if (_isServer)
                    IconButton(
                      icon: const Icon(Icons.refresh_outlined, size: 20, color: _kTextSec),
                      onPressed: () { setState(() { _loading = true; _posts = []; }); _load(); },
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_isServer) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📡', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Feed requires server mode', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Connect to a mise server to see recipes from people you follow.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kTextSec)),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }
    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👨‍🍳', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Your feed is empty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Follow some cooks on Explore to see their recipes here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kTextSec)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _kAccent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final post = _posts[i];
          final id = post['_id'] as String;
          return _FeedCard(
            post: post,
            liked: _likedIds.contains(id),
            likeCount: _likeCounts[id] ?? 0,
            saved: _savedIds.contains(id),
            onLike: () => _toggleLike(id),
            onSave: () => _save(id),
            onTapAuthor: () {
              final authorId = post['user_id'] as String?;
              if (authorId != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: authorId, currentUser: widget.user)));
              }
            },
            onTap: () async {
              final wasLiked = _likedIds.contains(id);
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => PublicRecipeDetailScreen(recipe: post, user: widget.user)));
              await _loadLiked();
              final isNowLiked = _likedIds.contains(id);
              if (wasLiked != isNowLiked && mounted) {
                setState(() => _likeCounts[id] = ((_likeCounts[id] ?? 0) + (isNowLiked ? 1 : -1)).clamp(0, 999999));
              }
            },
          );
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool liked;
  final int likeCount;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onTapAuthor;
  final VoidCallback onTap;

  const _FeedCard({
    required this.post, required this.liked, required this.likeCount,
    required this.saved, required this.onLike, required this.onSave,
    required this.onTapAuthor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = post['recipe_name'] as String? ?? '';
    final imageUrl = post['image_url'] as String?;
    final authorName = post['author_name'] as String?;
    final cuisine = post['cuisine'] as String? ?? '';
    final category = post['category'] as String? ?? '';
    final prep = (post['prep_time'] as num?)?.toInt() ?? 0;
    final cook = (post['cook_time'] as num?)?.toInt() ?? 0;
    final total = prep + cook;
    final tags = (post['tags'] as String? ?? '').split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          if (authorName != null)
            GestureDetector(
              onTap: onTapAuthor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                      child: Center(child: Text(authorName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                    const SizedBox(width: 10),
                    Text(authorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (cuisine.isNotEmpty)
                      Text(cuisine, style: const TextStyle(fontSize: 12, color: _kTextSec)),
                  ],
                ),
              ),
            ),

          // Image
          GestureDetector(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFFF0EEE9),
                      child: Center(child: Text(_emoji(cuisine), style: const TextStyle(fontSize: 64))),
                    ),
            ),
          ),

          // Actions row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _actionBtn(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? _kAccent : _kDark,
                  onTap: onLike,
                ),
                const SizedBox(width: 4),
                if (likeCount > 0)
                  Text('$likeCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onTap,
                  child: const Icon(Icons.chat_bubble_outline, size: 22, color: _kDark),
                ),
                const Spacer(),
                _actionBtn(
                  icon: saved ? Icons.bookmark : Icons.bookmark_border_outlined,
                  color: saved ? _kDark : _kDark,
                  onTap: onSave,
                ),
              ],
            ),
          ),

          // Recipe info
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (category.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kAccent)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (total > 0)
                      Text('${total}m', style: const TextStyle(fontSize: 12, color: _kTextSec)),
                  ]),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: tags.map((t) => Text('#$t',
                        style: const TextStyle(fontSize: 12, color: _kTextSec, fontWeight: FontWeight.w500))).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }

  String _emoji(String? c) => (c != null ? const {
    'italian': '🍝', 'mexican': '🌮', 'japanese': '🍱', 'chinese': '🥡',
    'indian': '🍛', 'american': '🍔', 'french': '🥐', 'thai': '🍜',
    'mediterranean': '🫒', 'greek': '🫙',
  }[c.toLowerCase()] : null) ?? '🍽';
}
