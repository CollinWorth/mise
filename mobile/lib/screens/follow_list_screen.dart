import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import 'user_profile_screen.dart';

const _kAccent = Color(0xFFE8622A);
const _kBg = Color(0xFFF7F6F3);
const _kBorder = Color(0xFFE5E2DC);
const _kTextSec = Color(0xFF888480);

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String type; // 'followers' or 'following'
  final Map<String, dynamic> currentUser;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.type,
    required this.currentUser,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  // Track follow state per user id
  final Map<String, bool> _following = {};
  final Map<String, bool> _followLoading = {};

  String get _currentUserId =>
      (widget.currentUser['id'] ?? widget.currentUser['_id'] ?? '') as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.get('/users/${widget.userId}/${widget.type}');
      if (r.statusCode == 200 && mounted) {
        final list =
            (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        setState(() => _users = list);
        // Load follow status for each user (skip own profile)
        await Future.wait(list.map((u) => _loadFollowStatus(u['id'] as String)));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
    final title = widget.type == 'followers' ? 'Followers' : 'Following';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _kAccent),
            )
          : _users.isEmpty
              ? Center(
                  child: Text(
                    widget.type == 'followers'
                        ? 'No followers yet'
                        : 'Not following anyone yet',
                    style:
                        const TextStyle(fontSize: 14, color: _kTextSec),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (_, i) => _buildUserTile(_users[i]),
                ),
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
          // Avatar — tappable
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

          // Name — tappable
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

          // Follow/Unfollow button (skip own profile)
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
