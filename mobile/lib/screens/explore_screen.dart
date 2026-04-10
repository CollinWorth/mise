import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../storage/storage.dart';
import 'public_recipe_detail_screen.dart';

const _kAccent = Color(0xFFE8622A);
const _kSurface = Colors.white;
const _kBorder = Color(0xFFE5E2DC);
const _kBg = Color(0xFFF7F6F3);
const _kTextSec = Color(0xFF888480);

const _cuisineEmoji = {
  'italian': '🍝', 'mexican': '🌮', 'japanese': '🍱', 'chinese': '🥡',
  'indian': '🍛', 'american': '🍔', 'french': '🥐', 'thai': '🍜',
  'mediterranean': '🫒', 'greek': '🫙',
};
String _emoji(String? c) => (c != null ? _cuisineEmoji[c.toLowerCase()] : null) ?? '🍽';

class ExploreScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool embedded;
  const ExploreScreen({super.key, required this.user, this.embedded = false});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Map<String, dynamic>> _recipes = [];
  bool _loading = true;
  String _search = '';
  String _activeTab = 'all';
  Set<String> _likedIds = {};
  Map<String, int> _likeCounts = {};
  Set<String> _savedIds = {};
  String? _savingId;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLiked();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLiked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mise_liked');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<String>();
      if (mounted) setState(() => _likedIds = Set.from(list));
    }
  }

  Future<void> _persistLiked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mise_liked', jsonEncode(_likedIds.toList()));
  }

  bool get _isServer => Store.isReady && Store.i.mode == StorageMode.server;

  Future<void> _load() async {
    if (!_isServer) { if (mounted) setState(() => _loading = false); return; }
    try {
      final r = await Api.get('/recipes/explore');
      if (r.statusCode == 200) {
        final data = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        final counts = <String, int>{};
        for (final rec in data) {
          counts[rec['_id'] as String] = (rec['like_count'] as num?)?.toInt() ?? 0;
        }
        if (mounted) setState(() { _recipes = data; _likeCounts = counts; });
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
      setState(() {
        wasLiked ? _likedIds.add(id) : _likedIds.remove(id);
        _likeCounts[id] = ((_likeCounts[id] ?? 0) - delta).clamp(0, 999999);
      });
    }
  }

  Future<void> _save(String id) async {
    if (_savedIds.contains(id)) return;
    setState(() => _savingId = id);
    try {
      final r = await Api.post('/recipes/$id/save', {});
      if (r.statusCode == 200 && mounted) setState(() => _savedIds.add(id));
    } catch (_) {}
    if (mounted) setState(() => _savingId = null);
  }

  List<String> get _tabs {
    final cats = <String>{};
    final cuisines = <String>{};
    for (final r in _recipes) {
      final c = r['category'] as String?;
      final cu = r['cuisine'] as String?;
      if (c != null && c.isNotEmpty) cats.add(c);
      if (cu != null && cu.isNotEmpty) cuisines.add(cu);
    }
    return ['all', 'trending', 'quick', ...cats, ...cuisines.where((c) => !cats.contains(c))];
  }

  List<Map<String, dynamic>> get _filtered {
    var list = [..._recipes];
    if (_activeTab == 'trending') {
      list.sort((a, b) => ((b['like_count'] as num?) ?? 0).compareTo((a['like_count'] as num?) ?? 0));
    } else if (_activeTab == 'quick') {
      list = list.where((r) {
        final t = ((r['prep_time'] as num?) ?? 0).toInt() + ((r['cook_time'] as num?) ?? 0).toInt();
        return t > 0 && t <= 30;
      }).toList();
    } else if (_activeTab != 'all') {
      list = list.where((r) {
        final tags = (r['tags'] as String? ?? '').toLowerCase().split(',').map((t) => t.trim()).toList();
        return r['cuisine'] == _activeTab || r['category'] == _activeTab || tags.contains(_activeTab.toLowerCase());
      }).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
        (r['recipe_name'] as String? ?? '').toLowerCase().contains(q) ||
        (r['category'] as String? ?? '').toLowerCase().contains(q) ||
        (r['cuisine'] as String? ?? '').toLowerCase().contains(q) ||
        (r['tags'] as String? ?? '').toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  String _tabLabel(String id) {
    switch (id) {
      case 'all': return 'All';
      case 'trending': return '🔥 Trending';
      case 'quick': return '⚡ Quick';
      default: return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearch(),
          if (_isServer && _recipes.isNotEmpty) _buildTabs(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      );
    }
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearch(),
            if (_isServer && _recipes.isNotEmpty) _buildTabs(),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text('Explore', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          if (_isServer)
            IconButton(
              icon: const Icon(Icons.refresh_outlined, size: 20, color: _kTextSec),
              onPressed: () { setState(() { _loading = true; _recipes = []; }); _load(); },
            ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search recipes…',
          hintStyle: const TextStyle(color: Color(0xFFBBB8B2), fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 17, color: _kTextSec),
          filled: true, fillColor: _kSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent)),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tab = _tabs[i];
          final active = tab == _activeTab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF1A1918) : _kSurface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: active ? const Color(0xFF1A1918) : _kBorder, width: 1.5),
              ),
              child: Text(
                _tabLabel(tab),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF555250)),
              ),
            ),
          );
        },
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
              const Text('🌍', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Explore requires server mode', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Connect to a mise server to browse shared recipes.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _kTextSec)),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌍', style: TextStyle(fontSize: 40, color: Color(0xFFBBB8B2))),
              const SizedBox(height: 12),
              Text(_recipes.isEmpty ? 'Nothing shared yet' : 'No results',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                _recipes.isEmpty
                  ? 'Open a recipe, toggle "Share publicly", and it\'ll appear here.'
                  : 'Try a different search or category.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _kTextSec),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.66,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _RecipeCard(
        recipe: items[i],
        liked: _likedIds.contains(items[i]['_id'] as String),
        likeCount: _likeCounts[items[i]['_id'] as String] ?? 0,
        saved: _savedIds.contains(items[i]['_id'] as String),
        saving: _savingId == items[i]['_id'],
        onLike: () => _toggleLike(items[i]['_id'] as String),
        onSave: () => _save(items[i]['_id'] as String),
        onTap: () async {
          final id = items[i]['_id'] as String;
          final wasLiked = _likedIds.contains(id);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PublicRecipeDetailScreen(recipe: items[i], user: widget.user)),
          );
          await _loadLiked();
          final isNowLiked = _likedIds.contains(id);
          if (wasLiked != isNowLiked && mounted) {
            setState(() => _likeCounts[id] = ((_likeCounts[id] ?? 0) + (isNowLiked ? 1 : -1)).clamp(0, 999999));
          }
        },
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final bool liked;
  final int likeCount;
  final bool saved;
  final bool saving;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe, required this.liked, required this.likeCount,
    required this.saved, required this.saving,
    required this.onLike, required this.onSave, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe['image_url'] as String?;
    final cuisine = recipe['cuisine'] as String? ?? '';
    final category = recipe['category'] as String? ?? '';
    final name = recipe['recipe_name'] as String? ?? '';
    final authorName = recipe['author_name'] as String?;
    final prep = (recipe['prep_time'] as num?)?.toInt() ?? 0;
    final cook = (recipe['cook_time'] as num?)?.toInt() ?? 0;
    final total = prep + cook;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder, width: 1.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (3:2 ratio)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFF0EEE9),
                          child: Center(child: Text(_emoji(cuisine), style: const TextStyle(fontSize: 36))),
                        ),
                  if (cuisine.isNotEmpty)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(cuisine, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.25),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kAccent), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (total > 0)
                        Text('${total}m', style: const TextStyle(fontSize: 11, color: _kTextSec)),
                    ]),
                    const Spacer(),
                    Row(
                      children: [
                        if (authorName != null) ...[
                          Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                            child: Center(child: Text(authorName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                          const SizedBox(width: 4),
                          Expanded(child: Text(authorName,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _kTextSec),
                            overflow: TextOverflow.ellipsis)),
                        ] else const Spacer(),
                        GestureDetector(
                          onTap: onLike,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Row(children: [
                              Icon(liked ? Icons.favorite : Icons.favorite_border,
                                size: 14, color: liked ? _kAccent : const Color(0xFFBBB8B2)),
                              if (likeCount > 0) ...[
                                const SizedBox(width: 2),
                                Text('$likeCount', style: const TextStyle(fontSize: 10, color: _kTextSec, fontWeight: FontWeight.w600)),
                              ],
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
