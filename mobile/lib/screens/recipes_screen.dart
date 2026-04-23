import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../storage/storage.dart';
import '../models/recipe.dart';
import 'recipe_detail_screen.dart';

// ── Sort options ──────────────────────────────────────────────────────────────
enum _Sort {
  defaultOrder('Default',       Icons.apps_rounded),
  nameAZ      ('A → Z',         Icons.sort_by_alpha),
  nameZA      ('Z → A',         Icons.sort_by_alpha),
  quickest    ('Quickest',      Icons.timer_outlined),
  longest     ('Longest',       Icons.hourglass_bottom_outlined),
  mostProtein ('Most protein',  Icons.fitness_center_rounded),
  fewest      ('Fewest ingred.', Icons.format_list_numbered_rtl);

  const _Sort(this.label, this.icon);
  final String label;
  final IconData icon;
}

// ── Protein scoring ───────────────────────────────────────────────────────────
const _proteinKeywords = [
  'chicken', 'beef', 'pork', 'lamb', 'turkey', 'duck', 'steak', 'salmon',
  'tuna', 'shrimp', 'fish', 'egg', 'eggs', 'tofu', 'tempeh', 'lentil',
  'lentils', 'chickpeas', 'beans', 'edamame', 'cheese', 'greek yogurt',
  'cottage cheese', 'ground beef', 'ground turkey', 'sausage', 'bacon',
];

int _proteinScore(Recipe r) {
  final text = r.ingredients.map((i) => i.name.toLowerCase()).join(' ');
  return _proteinKeywords.where((kw) => text.contains(kw)).length;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class RecipesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const RecipesScreen({super.key, required this.user});

  @override
  State<RecipesScreen> createState() => RecipesScreenState();
}

class RecipesScreenState extends State<RecipesScreen> {
  void reload() => _load();

  List<Recipe> _recipes = [];
  List<Recipe> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _activeFilter = 'All';
  _Sort _sort = _Sort.defaultOrder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.user['id'] ?? widget.user['_id'];
    try {
      final list = await Store.i.getRecipes(uid);
      if (!mounted) return;
      setState(() {
        _recipes = list.map((j) => Recipe.fromJson(j)).toList();
        _filter();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    setState(() {
      var list = _recipes.where((r) {
        final matchSearch = r.name.toLowerCase().contains(_search.toLowerCase());
        final matchFilter = _activeFilter == 'All' || r.cuisine == _activeFilter;
        return matchSearch && matchFilter;
      }).toList();

      switch (_sort) {
        case _Sort.nameAZ:
          list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        case _Sort.nameZA:
          list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        case _Sort.quickest:
          list.sort((a, b) {
            final at = a.totalTime > 0 ? a.totalTime : 9999;
            final bt = b.totalTime > 0 ? b.totalTime : 9999;
            return at.compareTo(bt);
          });
        case _Sort.longest:
          list.sort((a, b) => b.totalTime.compareTo(a.totalTime));
        case _Sort.mostProtein:
          list.sort((a, b) => _proteinScore(b).compareTo(_proteinScore(a)));
        case _Sort.fewest:
          list.sort((a, b) => a.ingredients.length.compareTo(b.ingredients.length));
        case _Sort.defaultOrder:
          break;
      }

      _filtered = list;
    });
  }

  // Rotate featured card daily
  int get _featuredIndex {
    if (_filtered.isEmpty) return 0;
    final daysSinceEpoch = DateTime.now().difference(DateTime(2024)).inDays;
    return daysSinceEpoch % _filtered.length;
  }

  List<String> get _cuisines =>
      ['All', ..._recipes.map((r) => r.cuisine).where((c) => c.isNotEmpty).toSet().toList()..sort()];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (!_loading) _buildFilters(),
            if (_loading) _buildSkeletons(),
            if (!_loading && _filtered.isEmpty) _buildEmpty(),
            if (!_loading && _filtered.isNotEmpty) _buildGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = Theme.of(context).colorScheme.onSurface.withOpacity(0.45);
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Recipes',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: textPrimary)),
                const SizedBox(width: 8),
                if (_recipes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('${_recipes.length}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                  ),
                const Spacer(),
                // Sort dropdown
                _SortButton(current: _sort, onSelected: (s) { setState(() => _sort = s); _filter(); }),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) { _search = v; _filter(); },
              style: TextStyle(color: textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                hintStyle: TextStyle(color: textSecondary),
                prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final hasCuisines = _cuisines.length > 1;
    if (!hasCuisines) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;
    final textSecondary = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: _cuisines.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { setState(() => _activeFilter = c); _filter(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: c == _activeFilter ? const Color(0xFFE8622A) : surface,
                  border: Border.all(
                    color: c == _activeFilter ? const Color(0xFFE8622A) : border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(c,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: c == _activeFilter ? Colors.white : textSecondary,
                  ),
                ),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final fi = _featuredIndex;
    final featured = _filtered[fi];
    final rest = [..._filtered.sublist(0, fi), ..._filtered.sublist(fi + 1)];

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Featured card
          GestureDetector(
            onTap: () => _openRecipe(featured),
            child: featured.imageUrl != null
              ? _featuredImageCard(featured)
              : _featuredTextCard(featured),
          ),
          const SizedBox(height: 16),
          // Grid
          if (rest.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 4 / 3,
              ),
              itemCount: rest.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openRecipe(rest[i]),
                child: rest[i].imageUrl != null
                  ? _gridImageCard(rest[i])
                  : _gridTextCard(rest[i]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _featuredImageCard(Recipe r) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _recipeImage(r, BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD0A0A0A)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (r.cuisine.isNotEmpty) _badge(r.cuisine),
                const SizedBox(height: 8),
                Text(r.name,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                if (r.totalTime > 0)
                  Text('${r.totalTime} min',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featuredTextCard(Recipe r) {
    final bg   = _cardBg(r.cuisine);
    final text = _cardText(r.cuisine);
    final tags = r.tags.isNotEmpty
      ? r.tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).take(3).toList()
      : <String>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        child: Container(
          color: bg,
          padding: const EdgeInsets.all(22),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: pills + time
                  Row(children: [
                    if (r.cuisine.isNotEmpty) ...[
                      _textCardPill(r.cuisine, text),
                      const SizedBox(width: 6),
                    ],
                    if (r.category.isNotEmpty && r.category != r.cuisine) ...[
                      _textCardPill(r.category, text),
                      const SizedBox(width: 6),
                    ],
                    const Spacer(),
                    if (r.totalTime > 0)
                      Text('${r.totalTime} min',
                        style: TextStyle(fontSize: 12, color: text.withOpacity(0.45), fontWeight: FontWeight.w500)),
                  ]),
                  const Spacer(),
                  // Name
                  Text(r.name,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                      color: text, letterSpacing: -0.5, height: 1.15)),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 5, runSpacing: 5,
                      children: tags.map((t) => _textCardPill(t, text)).toList()),
                  ],
                ],
          ),
        ),
      ),
    );
  }

  Widget _gridImageCard(Recipe r) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _recipeImage(r, BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC0A0A0A)],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 12, left: 12, right: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.cuisine.isNotEmpty) _badge(r.cuisine),
              const SizedBox(height: 4),
              Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              if (r.totalTime > 0)
                Text('${r.totalTime} min',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _gridTextCard(Recipe r) {
    final bg   = _cardBg(r.cuisine);
    final text = _cardText(r.cuisine);
    final topLabel = r.cuisine.isNotEmpty ? r.cuisine : (r.category.isNotEmpty ? r.category : null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (topLabel != null) ...[
              _textCardPill(topLabel, text),
              const SizedBox(height: 7),
            ],
            Text(r.name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: text, height: 1.2, letterSpacing: -0.2)),
            if (r.totalTime > 0) ...[
              const SizedBox(height: 3),
              Text('${r.totalTime}m',
                style: TextStyle(fontSize: 11, color: text.withOpacity(0.45), fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _textCardPill(String label, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: textColor.withOpacity(0.12)),
      ),
      child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7))),
    );
  }

  void _openRecipe(Recipe r) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RecipeDetailScreen(recipe: r, user: widget.user),
    )).then((_) => _load()); // refresh in case recipe was edited
  }

  static const _cuisineBg = {
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

  Color _cardBg(String cuisine) {
    final base = _cuisineBg[cuisine.toLowerCase()] ?? const Color(0xFFF2F0EB);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Color.lerp(base, const Color(0xFF1A1918), 0.72)! : base;
  }

  Color _cardText(String cuisine) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFECEAE6) : const Color(0xFF1A1918);
  }

  Widget _recipeImage(Recipe r, BoxFit fit) {
    if (r.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: r.imageUrl!, fit: fit,
        errorWidget: (_, __, ___) => _buildImageErrorCard(r),
      );
    }
    return _buildImageErrorCard(r);
  }

  // Pastel fallback fill used inside Stack when image fails to load
  Widget _buildImageErrorCard(Recipe r) {
    return Container(color: _cardBg(r.cuisine));
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
    );
  }

  Widget _buildSkeletons() {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _skeleton(height: 260),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 4 / 3,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => _skeleton(),
          ),
        ]),
      ),
    );
  }

  Widget _skeleton({double? height}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2C2C2A) : const Color(0xFFE5E2DC),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildEmpty() {
    final textSecondary = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return SliverFillRemaining(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🍽', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(_recipes.isEmpty ? 'No recipes yet' : 'No results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 8),
          Text(
            _recipes.isEmpty ? 'Add recipes on the web app first.' : 'Try a different search or filter.',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ]),
      ),
    );
  }
}

// ── Sort button / popup ───────────────────────────────────────────────────────
class _SortButton extends StatelessWidget {
  final _Sort current;
  final ValueChanged<_Sort> onSelected;
  const _SortButton({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final isDefault = current == _Sort.defaultOrder;

    return PopupMenuButton<_Sort>(
      onSelected: onSelected,
      offset: const Offset(0, 42),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      itemBuilder: (_) => _Sort.values.map((s) => PopupMenuItem<_Sort>(
        value: s,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(s.icon, size: 16,
              color: current == s ? const Color(0xFFE8622A) : textPrimary.withOpacity(0.5)),
            const SizedBox(width: 10),
            Text(s.label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: current == s ? const Color(0xFFE8622A) : textPrimary,
              )),
            if (current == s) ...[
              const Spacer(),
              const Icon(Icons.check, size: 14, color: Color(0xFFE8622A)),
            ],
          ],
        ),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDefault ? surface : const Color(0xFFE8622A).withOpacity(0.12),
          border: Border.all(
            color: isDefault ? border : const Color(0xFFE8622A).withOpacity(0.4),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 15,
              color: isDefault ? textPrimary.withOpacity(0.5) : const Color(0xFFE8622A)),
            const SizedBox(width: 5),
            Text(
              isDefault ? 'Sort' : current.label,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isDefault ? textPrimary.withOpacity(0.6) : const Color(0xFFE8622A),
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 15,
              color: isDefault ? textPrimary.withOpacity(0.4) : const Color(0xFFE8622A)),
          ],
        ),
      ),
    );
  }
}
