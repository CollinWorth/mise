import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../storage/storage.dart';
import 'public_recipe_detail_screen.dart';
import 'user_profile_screen.dart';

const _kAccent  = Color(0xFFE8622A);
const _kSurface = Colors.white;
const _kBorder  = Color(0xFFE5E2DC);
const _kBg      = Color(0xFFF7F6F3);
const _kTextSec = Color(0xFF888480);
const _kText    = Color(0xFF1A1918);

const _cuisineBg = {
  'italian':       Color(0xFFF5EDE8),
  'mexican':       Color(0xFFE9F2E9),
  'japanese':      Color(0xFFF2EDF4),
  'chinese':       Color(0xFFF5EDEC),
  'indian':        Color(0xFFF5F0E8),
  'american':      Color(0xFFEBF0F5),
  'french':        Color(0xFFEEF0F8),
  'thai':          Color(0xFFF3F2E7),
  'mediterranean': Color(0xFFE8F2EF),
  'greek':         Color(0xFFEDF0F8),
  'korean':        Color(0xFFF4EDF2),
};
Color _getBg(String? c) => (c != null ? _cuisineBg[c.toLowerCase()] : null) ?? const Color(0xFFF2F0EB);

class ExploreScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool embedded;
  final VoidCallback? onRecipeSaved;
  const ExploreScreen({super.key, required this.user, this.embedded = false, this.onRecipeSaved});

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
    if (_likedIds.contains(id)) return;
    setState(() {
      _likedIds.add(id);
      _likeCounts[id] = ((_likeCounts[id] ?? 0) + 1).clamp(0, 999999);
    });
    await _persistLiked();
    try {
      await Api.post('/recipes/$id/like', {});
    } catch (_) {
      setState(() {
        _likedIds.remove(id);
        _likeCounts[id] = ((_likeCounts[id] ?? 1) - 1).clamp(0, 999999);
      });
    }
  }

  Future<void> _save(String id) async {
    if (_savedIds.contains(id)) return;
    setState(() => _savingId = id);
    try {
      final r = await Api.post('/recipes/$id/save', {});
      if (r.statusCode == 200 && mounted) {
        setState(() => _savedIds.add(id));
        widget.onRecipeSaved?.call();
      }
    } catch (_) {}
    if (mounted) setState(() => _savingId = null);
  }

  List<String> get _tabs {
    final cats = <String>{};
    final cuisines = <String>{};
    for (final r in _recipes) {
      final c  = r['category'] as String?;
      final cu = r['cuisine']  as String?;
      if (c  != null && c.isNotEmpty)  cats.add(c);
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
        (r['category']    as String? ?? '').toLowerCase().contains(q) ||
        (r['cuisine']     as String? ?? '').toLowerCase().contains(q) ||
        (r['tags']        as String? ?? '').toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  String _tabLabel(String id) {
    switch (id) {
      case 'all':      return 'All';
      case 'trending': return '🔥 Trending';
      case 'quick':    return '⚡ Quick';
      default:         return id;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final surface  = Theme.of(context).colorScheme.surface;
    final border   = Theme.of(context).dividerColor;
    final textSec  = Theme.of(context).colorScheme.onSurface.withOpacity(0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search recipes…',
          hintStyle: TextStyle(color: textSec, fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 17, color: textSec),
          filled: true, fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent)),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final surface   = Theme.of(context).colorScheme.surface;
    final border    = Theme.of(context).dividerColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
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
                color: active ? onSurface : surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: active ? onSurface : border, width: 1.5),
              ),
              child: Text(
                _tabLabel(tab),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? Theme.of(context).colorScheme.surface : onSurface.withOpacity(0.6)),
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
              const Text('Explore requires server mode',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Connect to a mise server to browse shared recipes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kTextSec)),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(children: List.generate(3, (i) => _buildSkeletonCard(i.isEven ? 140.0 : 100.0))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(children: [
                const SizedBox(height: 40),
                ...List.generate(3, (i) => _buildSkeletonCard(i.isEven ? 100.0 : 140.0)),
              ]),
            ),
          ],
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

    // Manual two-column masonry
    final left  = <Map<String, dynamic>>[];
    final right = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      (i.isEven ? left : right).add(items[i]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left.map(_buildCard).toList())),
          const SizedBox(width: 10),
          Expanded(child: Column(children: right.map(_buildCard).toList())),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(double imageHeight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kBorder,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(height: imageHeight, color: _kBorder),
          Container(height: 64, decoration: const BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
          )),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> recipe) {
    final id         = recipe['_id'] as String;
    final imageUrl   = recipe['image_url'] as String?;
    final hasImage   = imageUrl != null && imageUrl.isNotEmpty;
    final name       = recipe['recipe_name'] as String? ?? '';
    final cuisine    = recipe['cuisine']     as String? ?? '';
    final category   = recipe['category']   as String? ?? '';
    final authorName = recipe['author_name'] as String?;
    final authorId   = recipe['user_id']    as String?;
    final prep = (recipe['prep_time'] as num?)?.toInt() ?? 0;
    final cook = (recipe['cook_time'] as num?)?.toInt() ?? 0;
    final total = prep + cook;
    final liked      = _likedIds.contains(id);
    final saved      = _savedIds.contains(id);
    final likeCount  = _likeCounts[id] ?? 0;
    final saving     = _savingId == id;
    final dark       = Theme.of(context).brightness == Brightness.dark;
    final surface    = Theme.of(context).colorScheme.surface;
    final border     = Theme.of(context).dividerColor;
    final textSec    = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final noImgBg    = dark
        ? Color.lerp(_getBg(cuisine), const Color(0xFF1A1918), 0.72)!
        : _getBg(cuisine);

    return GestureDetector(
      onTap: () async {
        final wasLiked = _likedIds.contains(id);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PublicRecipeDetailScreen(recipe: recipe, user: widget.user)),
        );
        await _loadLiked();
        final isNowLiked = _likedIds.contains(id);
        if (wasLiked != isNowLiked && mounted) {
          setState(() => _likeCounts[id] = ((_likeCounts[id] ?? 0) + (isNowLiked ? 1 : -1)).clamp(0, 999999));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: hasImage ? surface : noImgBg,
          borderRadius: BorderRadius.circular(14),
          border: hasImage ? Border.all(color: border, width: 1.5) : null,
          boxShadow: hasImage ? null : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (hasImage)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: _getBg(cuisine),
                        alignment: Alignment.center,
                        child: Text(name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFFBBB8B2))),
                      ),
                    ),
                    if (cuisine.isNotEmpty)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.60),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(cuisine,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),

            // Body
            Padding(
              padding: EdgeInsets.fromLTRB(10, hasImage ? 8 : 12, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: TextStyle(
                      fontSize: hasImage ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: _kText,
                    ),
                    maxLines: hasImage ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category.isNotEmpty || total > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(category,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kAccent),
                              overflow: TextOverflow.ellipsis),
                          ),
                        if (category.isNotEmpty && total > 0) const SizedBox(width: 5),
                        if (total > 0)
                          Text('${total}m', style: TextStyle(fontSize: 10, color: textSec, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: Row(
                children: [
                  if (authorName != null && authorId != null) ...[
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: authorId, currentUser: widget.user))),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16, height: 16,
                            decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                            child: Center(child: Text(authorName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 80),
                            child: Text(authorName,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textSec),
                              overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ] else const Spacer(),
                  // Like
                  GestureDetector(
                    onTap: () => _toggleLike(id),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(children: [
                        Icon(liked ? Icons.favorite : Icons.favorite_border,
                          size: 13, color: liked ? _kAccent : textSec),
                        if (likeCount > 0) ...[
                          const SizedBox(width: 2),
                          Text('$likeCount',
                            style: TextStyle(fontSize: 10, color: textSec, fontWeight: FontWeight.w600)),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Save
                  GestureDetector(
                    onTap: saving ? null : () => _save(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: saved ? const Color(0xFF34A853) : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: saved ? const Color(0xFF34A853) : border,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        saving ? '…' : saved ? '✓' : '+',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: saved ? Colors.white : textSec,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
