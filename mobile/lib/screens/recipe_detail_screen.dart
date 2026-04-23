import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../models/recipe.dart';
import '../storage/storage.dart';
import 'add_recipe_screen.dart';
import 'add_to_grocery_sheet.dart';
import 'comments_widget.dart';
import 'cook_mode_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final Map<String, dynamic> user;
  const RecipeDetailScreen({super.key, required this.recipe, required this.user});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Recipe _recipe;
  Recipe get recipe => _recipe;
  Map<String, dynamic> get user => widget.user;

  // Serving scaler
  int _servings = 4;
  int _baseServings = 0;

  // Social state (only used when server mode + recipe is public)
  bool _liked = false;
  late int _likeCount;

  // Versions/remixes
  List<Map<String, dynamic>> _versions = [];
  bool _versionsExpanded = false;

  bool get _showSocial => Store.isReady && Store.i.mode == StorageMode.server && recipe.isPublic;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _baseServings = widget.recipe.servings;
    _servings = _baseServings > 0 ? _baseServings : 4;
    _likeCount = recipe.likeCount;
    if (_showSocial) {
      _loadLiked();
      _loadVersions();
    }
  }

  Future<void> _loadVersions() async {
    try {
      final r = await Api.get('/recipes/${recipe.id}/versions');
      if (r.statusCode == 200 && mounted) {
        final data = jsonDecode(r.body) as List;
        setState(() => _versions = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadLiked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mise_liked');
    if (raw != null && mounted) {
      final list = (jsonDecode(raw) as List).cast<String>();
      setState(() => _liked = list.contains(recipe.id));
    }
  }

  Future<void> _toggleLike() async {
    if (_liked) return;
    setState(() { _liked = true; _likeCount = _likeCount + 1; });
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mise_liked');
    final list = raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
    if (!list.contains(recipe.id)) list.add(recipe.id);
    await prefs.setString('mise_liked', jsonEncode(list));
    try {
      await Api.post('/recipes/${recipe.id}/like', {});
    } catch (_) {
      if (mounted) setState(() { _liked = false; _likeCount = (_likeCount - 1).clamp(0, 999999); });
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecipeScreen(user: user, existingRecipe: _recipe),
        fullscreenDialog: true,
      ),
    );
    if (updated == true && mounted) {
      // Reload from server so detail screen reflects changes immediately
      final data = await Store.i.getRecipe(_recipe.id);
      if (data != null && mounted) {
        setState(() => _recipe = Recipe.fromJson(data));
      }
    }
  }

  Future<void> _deleteRecipe(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('${recipe.name} will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await Store.i.deleteRecipe(recipe.id);
      if (context.mounted) Navigator.pop(context, 'deleted');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete recipe')));
      }
    }
  }

  double get _scaleFactor => _baseServings > 0 ? _servings / _baseServings : 1.0;

  String _scaleQty(String qty) {
    if (qty.isEmpty) return qty;
    final s = qty.trim();
    final mixed = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)$').firstMatch(s);
    if (mixed != null) {
      final v = (double.parse(mixed.group(1)!) + double.parse(mixed.group(2)!) / double.parse(mixed.group(3)!)) * _scaleFactor;
      return _fmtNum(v);
    }
    final frac = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(s);
    if (frac != null) {
      return _fmtNum(double.parse(frac.group(1)!) / double.parse(frac.group(2)!) * _scaleFactor);
    }
    final n = double.tryParse(s);
    if (n != null) return _fmtNum(n * _scaleFactor);
    return qty;
  }

  String _fmtNum(double n) {
    final r = (n * 4).round() / 4;
    if (r == r.truncateToDouble()) return '${r.truncate()}';
    final whole = r.truncate();
    final frac = r - whole;
    final fracStr = (frac - 0.25).abs() < 0.01 ? '¼' : (frac - 0.5).abs() < 0.01 ? '½' : '¾';
    return whole > 0 ? '$whole$fracStr' : fracStr;
  }

  void _share() {
    final webBase = kBaseUrl.contains(':8000') ? kBaseUrl.replaceFirst(':8000', ':3000') : kBaseUrl;
    final url = '$webBase/recipe/${recipe.id}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard'), behavior: SnackBarBehavior.floating));
  }

  Widget _scalerBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEE9),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE5E2DC)),
      ),
      child: Icon(icon, size: 14,
        color: onTap != null ? const Color(0xFF1A1918) : const Color(0xFFCCCCC0)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      bottomNavigationBar: recipe.ingredients.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CookModeScreen(recipe: recipe)),
                  ),
                  icon: const Icon(Icons.local_fire_department_outlined, size: 18),
                  label: const Text('Start Cooking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1918),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF1A1918),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (_showSocial)
                GestureDetector(
                  onTap: _toggleLike,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Row(children: [
                      Icon(_liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? const Color(0xFFE8622A) : Colors.white, size: 21),
                      if (_likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text('$_likeCount', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                tooltip: 'Add to grocery list',
                onPressed: () => showAddToGrocerySheet(context, recipe: recipe, user: user),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                tooltip: 'Share',
                onPressed: _share,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: _openEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'Delete recipe',
                onPressed: () => _deleteRecipe(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  recipe.imageUrl != null
                      ? CachedNetworkImage(imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                      : _cuisineGradient(recipe.cuisine),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0x661A1918), Colors.transparent],
                        stops: [0.0, 0.38],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC1A1918)],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipe.cuisine.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8622A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFE8622A).withOpacity(0.3)),
                      ),
                      child: Text(recipe.cuisine, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE8622A))),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(recipe.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1)),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      if (recipe.prepTime > 0) _stat('Prep', '${recipe.prepTime}m'),
                      if (recipe.cookTime > 0) _stat('Cook', '${recipe.cookTime}m'),
                      if (recipe.totalTime > 0) _stat('Total', '${recipe.totalTime}m'),
                      if (recipe.servings > 0) _stat('Serves', '${recipe.servings}'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Versions / remixes
                  if (_versions.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => setState(() => _versionsExpanded = !_versionsExpanded),
                      child: Row(children: [
                        Icon(_versionsExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 18, color: const Color(0xFFE8622A)),
                        const SizedBox(width: 6),
                        Text(
                          '${_versions.length} remix${_versions.length != 1 ? 'es' : ''} of this recipe',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE8622A)),
                        ),
                      ]),
                    ),
                    if (_versionsExpanded) ...[
                      const SizedBox(height: 8),
                      ..._versions.map((v) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F6F3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEAEAE5)),
                          ),
                          child: Row(children: [
                            Expanded(child: Text(
                              v['recipe_name'] as String? ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            )),
                            if (v['author_name'] != null)
                              Text('by ${v['author_name']}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9A9893))),
                          ]),
                        ),
                      )),
                    ],
                    const SizedBox(height: 20),
                  ],

                  // Ingredients
                  if (recipe.ingredients.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(child: Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                        if (_baseServings > 0) ...[
                          _scalerBtn(Icons.remove, _servings > 1 ? () => setState(() => _servings--) : null),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('$_servings', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          _scalerBtn(Icons.add, () => setState(() => _servings++)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...recipe.ingredients.map((ing) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFE8622A), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(ing.name, style: const TextStyle(fontSize: 14))),
                          if (ing.quantity.isNotEmpty || ing.unit.isNotEmpty)
                            Text(
                              [_scaleQty(ing.quantity), ing.unit].where((s) => s.isNotEmpty).join(' '),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888480)),
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 28),
                  ],

                  // Instructions
                  if (recipe.instructions.isNotEmpty) ...[
                    const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ...recipe.instructions.split('\n').where((s) => s.trim().isNotEmpty).toList().asMap().entries.map((e) {
                      final step = e.value.trim();
                      final idx = e.key + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(color: const Color(0xFF1A1918), borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Text('$idx', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(step, style: const TextStyle(fontSize: 14, height: 1.5))),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // ── Social section (only for public server recipes) ──
                  if (_showSocial)
                    CommentsWidget(recipeId: recipe.id, currentUser: user),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E2DC)),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888480), fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _cuisineGradient(String cuisine) {
    const pastels = {
      'italian': Color(0xFFF5EDE8), 'mexican': Color(0xFFE9F2E9),
      'japanese': Color(0xFFF2EDF4), 'chinese': Color(0xFFF5EDEC),
      'indian': Color(0xFFF5F0E8), 'american': Color(0xFFEBF0F5),
      'french': Color(0xFFEEF0F8), 'thai': Color(0xFFF3F2E7),
      'mediterranean': Color(0xFFE8F2EF), 'greek': Color(0xFFEDF0F8),
      'korean': Color(0xFFF4EDF2),
    };
    return Container(color: pastels[cuisine.toLowerCase()] ?? const Color(0xFFF2F0EB));
  }
}
