import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import 'comments_widget.dart';
import 'user_profile_screen.dart';

const _kAccent = Color(0xFFE8622A);
const _kBg = Color(0xFFF7F6F3);
const _kDark = Color(0xFF1A1918);
const _kBorder = Color(0xFFE5E2DC);
const _kTextSec = Color(0xFF888480);

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

  @override
  void initState() {
    super.initState();
    _likeCount = (widget.recipe['like_count'] as num?)?.toInt() ?? 0;
    _loadLiked();
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
    final wasLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likeCount = (_likeCount + (_liked ? 1 : -1)).clamp(0, 999999);
    });
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mise_liked');
    final list = raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
    _liked ? (list.contains(_id) ? null : list.add(_id)) : list.remove(_id);
    await prefs.setString('mise_liked', jsonEncode(list));
    try {
      await Api.post('/recipes/$_id/${wasLiked ? 'unlike' : 'like'}', {});
    } catch (_) {
      if (mounted) setState(() { _liked = wasLiked; _likeCount = (_likeCount + (wasLiked ? 1 : -1)).clamp(0, 999999); });
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
                  onPressed: () {/* navigate to edit */},
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
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF2C2C2C), Color(0xFF4A4A4A)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: Center(child: Text(_emoji(_cuisine), style: const TextStyle(fontSize: 64))),
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
                    const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                              [ing['quantity'], ing['unit']].where((s) => s != null && s.toString().isNotEmpty).join(' '),
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

  String _emoji(String? c) => (c != null ? const {
    'italian': '🍝', 'mexican': '🌮', 'japanese': '🍱', 'chinese': '🥡',
    'indian': '🍛', 'american': '🍔', 'french': '🥐', 'thai': '🍜',
    'mediterranean': '🫒', 'greek': '🫙',
  }[c.toLowerCase()] : null) ?? '🍽';
}
