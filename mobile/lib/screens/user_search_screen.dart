import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import 'user_profile_screen.dart';

const _kAccent = Color(0xFFE8622A);
const _kBorder = Color(0xFFE5E2DC);
const _kTextSec = Color(0xFF888480);

class UserSearchScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const UserSearchScreen({super.key, required this.currentUser});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  // Follow state per user id
  final Map<String, bool> _following = {};
  final Map<String, bool> _followLoading = {};

  Timer? _debounce;

  String get _currentUserId =>
      (widget.currentUser['id'] ?? widget.currentUser['_id'] ?? '') as String;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final r = await Api.get('/users/search?q=${Uri.encodeQueryComponent(q)}');
      if (r.statusCode == 200 && mounted) {
        final list =
            (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        setState(() {
          _results = list;
          _hasSearched = true;
        });
        // Load follow status for results
        await Future.wait(list.map((u) => _loadFollowStatus(u['id'] as String)));
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _loadFollowStatus(String uid) async {
    if (uid == _currentUserId) return;
    try {
      final r = await Api.get('/follows/$uid/status');
      if (r.statusCode == 200 && mounted) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() {
          _following[uid] = data['is_following'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow(String uid) async {
    if (_followLoading[uid] == true) return;
    setState(() => _followLoading[uid] = true);
    final wasFollowing = _following[uid] ?? false;
    setState(() => _following[uid] = !wasFollowing);
    try {
      if (wasFollowing) {
        await Api.delete('/follows/$uid');
      } else {
        await Api.post('/follows/$uid', {});
      }
    } catch (_) {
      if (mounted) setState(() => _following[uid] = wasFollowing);
    }
    if (mounted) setState(() => _followLoading[uid] = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search field ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _focusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search people…',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBB8B2)),
              prefixIcon: const Icon(Icons.search, color: _kTextSec, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _focusNode.requestFocus();
                      },
                      child: const Icon(
                        Icons.cancel,
                        color: _kTextSec,
                        size: 18,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kAccent),
              ),
            ),
          ),
        ),

        // ── Content ─────────────────────────────────────────
        Expanded(
          child: _searching
              ? const Center(
                  child: CircularProgressIndicator(color: _kAccent),
                )
              : !_hasSearched
                  ? const Center(
                      child: Text(
                        'Search for people to follow',
                        style: TextStyle(fontSize: 14, color: _kTextSec),
                      ),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(fontSize: 14, color: _kTextSec),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: _kBorder),
                          itemBuilder: (_, i) =>
                              _buildUserTile(_results[i]),
                        ),
        ),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> u) {
    final uid = u['id'] as String? ?? '';
    final name = u['name'] as String? ?? 'Chef';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isOwn = uid == _currentUserId;
    final isFollowing = _following[uid] ?? false;
    final loading = _followLoading[uid] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userId: uid,
                  currentUser: widget.currentUser,
                ),
              ),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _kAccent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: uid,
                    currentUser: widget.currentUser,
                  ),
                ),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Follow/Unfollow (skip own)
          if (!isOwn) ...[
            const SizedBox(width: 8),
            isFollowing
                ? OutlinedButton(
                    onPressed: loading ? null : () => _toggleFollow(uid),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Unfollow',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  )
                : FilledButton(
                    onPressed: loading ? null : () => _toggleFollow(uid),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Follow',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
          ],
        ],
      ),
    );
  }
}
