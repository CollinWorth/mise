import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api.dart';
import 'follow_list_screen.dart';
import 'public_recipe_detail_screen.dart';

const _kAccent = Color(0xFFE8622A);
const _kBg = Color(0xFFF7F6F3);
const _kBorder = Color(0xFFE5E2DC);
const _kTextSec = Color(0xFF888480);

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> currentUser;

  const UserProfileScreen({super.key, required this.userId, required this.currentUser});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _recipes = [];
  bool _loading = true;
  bool _isFollowing = false;
  bool _followLoading = false;
  int _followerCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _currentUserId => (widget.currentUser['id'] ?? widget.currentUser['_id'] ?? '') as String;
  bool get _isOwnProfile => _currentUserId == widget.userId;

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.get('/users/${widget.userId}'),
        Api.get('/users/${widget.userId}/recipes'),
        if (!_isOwnProfile) Api.get('/follows/${widget.userId}/status'),
      ]);

      final profileR = results[0];
      final recipesR = results[1];

      if (profileR.statusCode == 200) {
        final data = jsonDecode(profileR.body) as Map<String, dynamic>;
        _profile = data;
        _followerCount = (data['follower_count'] as num?)?.toInt() ?? 0;
      }
      if (recipesR.statusCode == 200) {
        _recipes = (jsonDecode(recipesR.body) as List).cast<Map<String, dynamic>>();
      }
      if (!_isOwnProfile && results.length > 2) {
        final statusR = results[2];
        if (statusR.statusCode == 200) {
          _isFollowing = (jsonDecode(statusR.body) as Map)['is_following'] as bool? ?? false;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    setState(() => _followLoading = true);
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !_isFollowing;
      _followerCount = (_followerCount + (_isFollowing ? 1 : -1)).clamp(0, 999999);
    });
    try {
      if (wasFollowing) {
        await Api.delete('/follows/${widget.userId}');
      } else {
        await Api.post('/follows/${widget.userId}', {});
      }
    } catch (_) {
      if (mounted) setState(() {
        _isFollowing = wasFollowing;
        _followerCount = (_followerCount + (wasFollowing ? 1 : -1)).clamp(0, 999999);
      });
    }
    if (mounted) setState(() => _followLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: _kAccent)),
      );
    }

    final name = _profile?['name'] as String? ?? 'Chef';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final followingCount = (_profile?['following_count'] as num?)?.toInt() ?? 0;
    final recipeCount = (_profile?['public_recipe_count'] as num?)?.toInt() ?? _recipes.length;

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _kBg,
            elevation: 0,
            title: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                    child: Center(child: Text(initial,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))),
                  ),
                  const SizedBox(height: 12),
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      _statCol('$recipeCount', 'Recipes'),
                      _statDivider(),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowListScreen(
                              userId: widget.userId,
                              type: 'followers',
                              currentUser: widget.currentUser,
                            ),
                          ),
                        ),
                        child: _statCol('$_followerCount', 'Followers'),
                      ),
                      _statDivider(),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowListScreen(
                              userId: widget.userId,
                              type: 'following',
                              currentUser: widget.currentUser,
                            ),
                          ),
                        ),
                        child: _statCol('$followingCount', 'Following'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Follow / unfollow button
                  if (!_isOwnProfile)
                    SizedBox(
                      width: double.infinity,
                      child: _isFollowing
                          ? OutlinedButton(
                              onPressed: _followLoading ? null : _toggleFollow,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade400,
                                side: BorderSide(color: Colors.red.shade200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _followLoading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Unfollow', style: TextStyle(fontWeight: FontWeight.w700)),
                            )
                          : FilledButton(
                              onPressed: _followLoading ? null : _toggleFollow,
                              style: FilledButton.styleFrom(
                                backgroundColor: _kAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _followLoading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Follow', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                    ),
                ],
              ),
            ),
          ),

          // Recipe grid
          if (_recipes.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No public recipes yet', style: TextStyle(fontSize: 14, color: _kTextSec)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final r = _recipes[i];
                    final imageUrl = r['image_url'] as String?;
                    final name = r['recipe_name'] as String? ?? '';
                    final cuisine = r['cuisine'] as String? ?? '';
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PublicRecipeDetailScreen(recipe: r, user: widget.currentUser))),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder, width: 1.5),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, width: double.infinity)
                                  : Container(
                                      color: const Color(0xFFF0EEE9),
                                      child: Center(child: Text(_emoji(cuisine), style: const TextStyle(fontSize: 32))),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _recipes.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label) {
    return Expanded(
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: _kTextSec, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 32, color: _kBorder);

  String _emoji(String? c) => (c != null ? const {
    'italian': '🍝', 'mexican': '🌮', 'japanese': '🍱', 'chinese': '🥡',
    'indian': '🍛', 'american': '🍔', 'french': '🥐', 'thai': '🍜',
    'mediterranean': '🫒', 'greek': '🫙',
  }[c.toLowerCase()] : null) ?? '🍽';
}
