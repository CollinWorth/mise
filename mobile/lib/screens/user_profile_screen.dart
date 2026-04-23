import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api.dart';
import 'follow_list_screen.dart';
import 'public_recipe_detail_screen.dart';

const _kAccent = Color(0xFFE8622A);

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

  static const _pastels = {
    'italian': Color(0xFFF5EDE8), 'mexican': Color(0xFFE9F2E9),
    'japanese': Color(0xFFF2EDF4), 'chinese': Color(0xFFF5EDEC),
    'indian': Color(0xFFF5F0E8), 'american': Color(0xFFEBF0F5),
    'french': Color(0xFFEEF0F8), 'thai': Color(0xFFF3F2E7),
    'mediterranean': Color(0xFFE8F2EF), 'greek': Color(0xFFEDF0F8),
    'korean': Color(0xFFF4EDF2),
  };

  @override
  Widget build(BuildContext context) {
    final bg      = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;
    final border  = Theme.of(context).dividerColor;
    final tp      = Theme.of(context).colorScheme.onSurface;
    final ts      = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final dark    = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
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
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: bg,
            elevation: 0,
            iconTheme: IconThemeData(color: tp),
            title: Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tp)),
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
                  Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: tp)),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      Expanded(child: _statCol('$recipeCount', 'Recipes', ts)),
                      _statDivider(border),
                      Expanded(
                        child: GestureDetector(
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
                          child: _statCol('$_followerCount', 'Followers', ts),
                        ),
                      ),
                      _statDivider(border),
                      Expanded(
                        child: GestureDetector(
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
                          child: _statCol('$followingCount', 'Following', ts),
                        ),
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
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No public recipes yet', style: TextStyle(fontSize: 14, color: ts)),
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
                    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
                    final recipeName = r['recipe_name'] as String? ?? '';
                    final cuisine = r['cuisine'] as String? ?? '';
                    final category = r['category'] as String? ?? '';
                    final pastelBase = _pastels[cuisine.toLowerCase()] ?? const Color(0xFFF2F0EB);
                    final cardBg = hasImage
                        ? surface
                        : (dark ? Color.lerp(pastelBase, const Color(0xFF1A1918), 0.72)! : pastelBase);
                    final textOnCard = dark ? Colors.white.withOpacity(0.85) : const Color(0xFF1A1918);

                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PublicRecipeDetailScreen(recipe: r, user: widget.currentUser))),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: hasImage ? Border.all(color: border, width: 1.5) : null,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: hasImage
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: CachedNetworkImage(
                                    imageUrl: imageUrl!, fit: BoxFit.cover, width: double.infinity)),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(recipeName,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tp),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              )
                            : Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (category.isNotEmpty || cuisine.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: textOnCard.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          category.isNotEmpty ? category : cuisine,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                            color: textOnCard.withOpacity(0.55)),
                                          overflow: TextOverflow.ellipsis),
                                      ),
                                    const Spacer(),
                                    Text(recipeName,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                        color: textOnCard, height: 1.2),
                                      maxLines: 3, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
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

  Widget _statCol(String value, String label, Color labelColor) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kAccent)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _statDivider(Color color) => Container(width: 1, height: 32, color: color);
}
