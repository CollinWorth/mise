import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../models/recipe.dart';
import 'add_recipe_screen.dart';
import 'comments_widget.dart';
import 'user_profile_screen.dart';

const _kAccent = Color(0xFFE8622A);
const _kBg = Color(0xFFF7F6F3);
const _kDark = Color(0xFF1A1918);
const _kBorder = Color(0xFFE5E2DC);
const _kTextSec = Color(0xFF888480);
const _kPastels = {
  'italian': Color(0xFFF5EDE8), 'mexican': Color(0xFFE9F2E9),
  'japanese': Color(0xFFF2EDF4), 'chinese': Color(0xFFF5EDEC),
  'indian': Color(0xFFF5F0E8), 'american': Color(0xFFEBF0F5),
  'french': Color(0xFFEEF0F8), 'thai': Color(0xFFF3F2E7),
  'mediterranean': Color(0xFFE8F2EF), 'greek': Color(0xFFEDF0F8),
  'korean': Color(0xFFF4EDF2),
};

class PublicRecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final Map<String, dynamic> user;

  const PublicRecipeDetailScreen({super.key, required this.recipe, required this.user});

  @override
  State<PublicRecipeDetailScreen> createState() => _PublicRecipeDetailScreenState();
}

class _PublicRecipeDetailScreenState extends State<PublicRecipeDetailScreen> {
  bool _liked = false;
  late int _likeCount;
  bool _saved = false;
  bool _saving = false;
  List<Map<String, dynamic>> _versions = [];
  bool _showVersions = false;
  int _servings = 4;
  int _baseServings = 0;

  @override
  void initState() {
    super.initState();
    _likeCount = (widget.recipe['like_count'] as num?)?.toInt() ?? 0;
    _baseServings = (widget.recipe['servings'] as num?)?.toInt() ?? 0;
    _servings = _baseServings > 0 ? _baseServings : 4;
    _loadLiked();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    try {
      final r = await Api.get('/recipes/$_id/versions');
      if (r.statusCode == 200 && mounted) {
        final data = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        setState(() => _versions = data);
      }
    } catch (_) {}
  }

  String get _id => widget.recipe['_id'] as String;
  String get _name => widget.recipe['recipe_name'] as String? ?? '';
  String get _cuisine => widget.recipe['cuisine'] as String? ?? '';
  String get _category => widget.recipe['category'] as String? ?? '';
  String? get _imageUrl => widget.recipe['image_url'] as String?;
  String? get _authorName => widget.recipe['author_name'] as String?;
  String? get _authorId => widget.recipe['user_id'] as String?;

  Future<void> _loadLiked() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mise_liked');
    if (raw != null && mounted) {
      final list = (jsonDecode(raw) as List).cast<String>();
      setState(() => _liked = list.contains(_id));
    }
  }

  Future<void> _toggleLike() async {
    if (_liked) return;
    setState(() { _liked = true; _likeCount = _likeCount + 1; });
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mise_liked');
    final list = raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
    if (!list.contains(_id)) list.add(_id);
    await prefs.setString('mise_liked', jsonEncode(list));
    try {
      await Api.post('/recipes/$_id/like', {});
    } catch (_) {
      if (mounted) setState(() { _liked = false; _likeCount = (_likeCount - 1).clamp(0, 999999); });
    }
  }

  Future<void> _save() async {
    if (_saved || _saving) return;
    setState(() => _saving = true);
    try {
      final r = await Api.post('/recipes/$_id/save', {});
      if (r.statusCode == 200 && mounted) setState(() => _saved = true);
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
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
    final url = '$webBase/recipe/$_id';
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
        border: Border.all(color: _kBorder),
      ),
      child: Icon(icon, size: 14,
        color: onTap != null ? _kDark : const Color(0xFFCCCCC0)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ingredients = (widget.recipe['ingredients'] as List? ?? []).cast<Map<String, dynamic>>();
    final instructions = widget.recipe['instructions'] as String? ?? '';
    final prep = (widget.recipe['prep_time'] as num?)?.toInt() ?? 0;
    final cook = (widget.recipe['cook_time'] as num?)?.toInt() ?? 0;
    final servings = (widget.recipe['servings'] as num?)?.toInt() ?? 0;
    final tags = (widget.recipe['tags'] as String? ?? '').split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final currentUserId = widget.user['id'] ?? widget.user['_id'];
    final isOwn = currentUserId != null && currentUserId == _authorId;

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // ── Hero ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _kDark,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (isOwn)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit recipe',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddRecipeScreen(
                      user: widget.user,
                      existingRecipe: Recipe.fromJson(widget.recipe),
                    ),
                  )),
                ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                tooltip: 'Share',
                onPressed: _share,
              ),
              // Like button in app bar
              GestureDetector(
                onTap: _toggleLike,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(_liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? _kAccent : Colors.white, size: 22),
                      if (_likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text('$_likeCount', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _imageUrl != null && _imageUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: _imageUrl!, fit: BoxFit.cover)
                      : Container(color: _kPastels[_cuisine.toLowerCase()] ?? const Color(0xFFF2F0EB)),
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
                        stops: [0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cuisine + category pills
                  if (_cuisine.isNotEmpty || _category.isNotEmpty)
                    Wrap(spacing: 6, children: [
                      if (_cuisine.isNotEmpty) _pill(_cuisine, bg: _kAccent.withOpacity(0.1), color: _kAccent),
                      if (_category.isNotEmpty) _pill(_category, bg: _kAccent.withOpacity(0.08), color: _kAccent, italic: true),
                    ]),
                  const SizedBox(height: 10),

                  // Title
                  Text(_name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1)),
                  const SizedBox(height: 6),

                  // Author row
                  if (_authorName != null)
                    GestureDetector(
                      onTap: () {
                        if (_authorId != null) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: _authorId!, currentUser: widget.user)));
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                            child: Center(child: Text(_authorName![0].toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                          const SizedBox(width: 6),
                          Text(_authorName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 14, color: _kTextSec),
                        ],
                      ),
                    ),

                  // Provenance row
                  if ((widget.recipe['is_modified'] as bool? ?? false) &&
                      widget.recipe['original_author_name'] != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: _kTextSec),
                        const SizedBox(width: 4),
                        Text('modified from ', style: const TextStyle(fontSize: 12, color: _kTextSec, fontStyle: FontStyle.italic)),
                        Text(widget.recipe['original_author_name'] as String,
                          style: const TextStyle(fontSize: 12, color: _kTextSec, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ],

                  // Versions / remixes
                  if (_versions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showVersions = !_showVersions),
                      child: Row(
                        children: [
                          Icon(_showVersions ? Icons.expand_less : Icons.expand_more, size: 16, color: _kAccent),
                          const SizedBox(width: 4),
                          Text(
                            '${_versions.length} remix${_versions.length != 1 ? 'es' : ''} of this recipe',
                            style: const TextStyle(fontSize: 12, color: _kAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (_showVersions) ...[
                      const SizedBox(height: 8),
                      ...(_versions.map((v) => GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PublicRecipeDetailScreen(recipe: v, user: widget.user))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v['recipe_name'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (v['author_name'] != null)
                                    Text('by ${v['author_name']}', style: const TextStyle(fontSize: 11, color: _kTextSec)),
                                ],
                              )),
                              const Icon(Icons.chevron_right, size: 16, color: _kTextSec),
                            ],
                          ),
                        ),
                      ))),
                    ],
                  ],
                  const SizedBox(height: 16),

                  // Tags
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EEE9),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Text(t, style: const TextStyle(fontSize: 11, color: _kTextSec, fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  if (tags.isNotEmpty) const SizedBox(height: 16),

                  // Stats
                  if (prep > 0 || cook > 0 || servings > 0)
                    Row(
                      children: [
                        if (prep > 0) _stat('Prep', '${prep}m'),
                        if (cook > 0) _stat('Cook', '${cook}m'),
                        if (prep > 0 && cook > 0) _stat('Total', '${prep + cook}m'),
                        if (servings > 0) _stat('Serves', '$servings'),
                      ],
                    ),
                  if (prep > 0 || cook > 0 || servings > 0) const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_saved || _saving) ? null : _save,
                      icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border_outlined, size: 18),
                      label: Text(_saving ? 'Saving…' : _saved ? 'Saved to your recipes' : 'Save to my recipes',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _saved ? Colors.green.shade700 : _kAccent,
                        side: BorderSide(color: _saved ? Colors.green.shade400 : _kAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ingredients
                  if (ingredients.isNotEmpty) ...[
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
                    ...ingredients.map((ing) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(ing['name'] ?? '', style: const TextStyle(fontSize: 14))),
                          if ((ing['quantity'] ?? '').toString().isNotEmpty || (ing['unit'] ?? '').toString().isNotEmpty)
                            Text(
                              [_scaleQty((ing['quantity'] ?? '').toString()), (ing['unit'] ?? '').toString()].where((s) => s.isNotEmpty).join(' '),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec),
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Instructions
                  if (instructions.isNotEmpty) ...[
                    const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ...instructions.split('\n').where((s) => s.trim().isNotEmpty).toList().asMap().entries.map((e) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(color: _kDark, borderRadius: BorderRadius.circular(99)),
                              child: Center(child: Text('${e.key + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(e.value.trim(), style: const TextStyle(fontSize: 14, height: 1.5))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Comments ────────────────────────────────────
                  CommentsWidget(recipeId: _id, currentUser: widget.user),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, {required Color bg, required Color color, bool italic = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontStyle: italic ? FontStyle.italic : FontStyle.normal)),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _kTextSec, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

}
