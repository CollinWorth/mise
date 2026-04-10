import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

const _kAccent = Color(0xFFE8622A);
const _kBg = Color(0xFFF7F6F3);
const _kBorder = Color(0xFFE5E2DC);
const _kTextSec = Color(0xFF888480);

class CommentsWidget extends StatefulWidget {
  final String recipeId;
  final Map<String, dynamic> currentUser;

  const CommentsWidget({
    super.key,
    required this.recipeId,
    required this.currentUser,
  });

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _submitting = false;

  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // When set, replying to this comment
  Map<String, dynamic>? _replyingTo;

  // Which top-level comment IDs have replies expanded
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _currentUserId =>
      (widget.currentUser['id'] ?? widget.currentUser['_id'] ?? '') as String;

  Future<void> _loadComments() async {
    try {
      final r = await Api.get('/comments/${widget.recipeId}');
      if (r.statusCode == 200 && mounted) {
        setState(() {
          _comments =
              (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);

    // Determine parent_id: if replying to a reply, use the reply's own parent;
    // otherwise use the comment's _id. This flattens to 1 level in data.
    String? parentId;
    if (_replyingTo != null) {
      final replyParent = _replyingTo!['parent_id'] as String?;
      parentId = (replyParent != null && replyParent.isNotEmpty)
          ? replyParent
          : _replyingTo!['_id'] as String?;
    }

    try {
      final body = <String, dynamic>{'text': text};
      if (parentId != null) body['parent_id'] = parentId;
      final r = await Api.post('/comments/${widget.recipeId}', body);
      if (r.statusCode == 200 && mounted) {
        final c = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() {
          _comments.add(c);
          _inputCtrl.clear();
          // Auto-expand the parent thread so the reply is visible
          if (parentId != null) _expanded.add(parentId);
          _replyingTo = null;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final r = await Api.delete('/comments/$commentId');
      if (r.statusCode == 200 && mounted) {
        setState(() => _comments.removeWhere((c) => c['_id'] == commentId));
      }
    } catch (_) {}
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    DateTime? dt;
    if (ts is String) dt = DateTime.tryParse(ts);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _avatar(String name, {double size = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Split into top-level and replies map
    final topLevel = _comments
        .where((c) {
          final pid = c['parent_id'] as String?;
          return pid == null || pid.isEmpty;
        })
        .toList();

    final repliesMap = <String, List<Map<String, dynamic>>>{};
    for (final c in _comments) {
      final pid = c['parent_id'] as String?;
      if (pid != null && pid.isNotEmpty) {
        repliesMap.putIfAbsent(pid, () => []).add(c);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────
        const Divider(height: 1),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'Comments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                '${topLevel.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kTextSec,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Reply-to banner ─────────────────────────────────
        if (_replyingTo != null) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text(
                  '\u21a9 Replying to ',
                  style: TextStyle(fontSize: 12, color: _kTextSec),
                ),
                Text(
                  '@${_replyingTo!['user_name'] ?? 'Chef'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kAccent,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _replyingTo = null),
                  child: const Text(
                    '\u00d7',
                    style: TextStyle(
                      fontSize: 16,
                      color: _kTextSec,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── Input row ───────────────────────────────────────
        Row(
          children: [
            _avatar(
              widget.currentUser['name'] as String? ?? '?',
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: _replyingTo != null
                      ? 'Write a reply…'
                      : 'Add a comment…',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFBBB8B2),
                  ),
                  filled: true,
                  fillColor: _kBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: const BorderSide(color: _kAccent),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: _kAccent,
                  shape: BoxShape.circle,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 16,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Comments list ───────────────────────────────────
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: _kAccent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (topLevel.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No comments yet \u2014 be the first!',
              style: TextStyle(fontSize: 13, color: _kTextSec),
            ),
          )
        else
          ...topLevel.map((c) => _buildTopLevelComment(c, repliesMap)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTopLevelComment(
    Map<String, dynamic> c,
    Map<String, List<Map<String, dynamic>>> repliesMap,
  ) {
    final cId = c['_id'] as String? ?? '';
    final cUserId = c['user_id'] as String? ?? '';
    final cName = c['user_name'] as String? ?? 'Chef';
    final cText = c['text'] as String? ?? '';
    final cTime = c['created_at'];
    final isOwn = cUserId == _currentUserId;
    final replies = repliesMap[cId] ?? [];
    final isExpanded = _expanded.contains(cId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(cName, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _timeAgo(cTime),
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTextSec,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cText,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF3A3836),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Reply button
                    GestureDetector(
                      onTap: () {
                        setState(() => _replyingTo = c);
                        _focusNode.requestFocus();
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kTextSec,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwn)
                GestureDetector(
                  onTap: () => _deleteComment(cId),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Color(0xFFCCC9C3),
                    ),
                  ),
                ),
            ],
          ),

          // Replies toggle + list
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle button
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expanded.remove(cId);
                      } else {
                        _expanded.add(cId);
                      }
                    }),
                    child: Text(
                      isExpanded
                          ? 'Hide replies \u25b4'
                          : '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'} \u25be',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextSec,
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 8),
                    ...replies.map((reply) => _buildReply(reply)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReply(Map<String, dynamic> c) {
    final cId = c['_id'] as String? ?? '';
    final cUserId = c['user_id'] as String? ?? '';
    final cName = c['user_name'] as String? ?? 'Chef';
    final cText = c['text'] as String? ?? '';
    final cTime = c['created_at'];
    final isOwn = cUserId == _currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left border accent line
          Container(
            width: 2,
            height: 40,
            color: _kBorder,
            margin: const EdgeInsets.only(right: 10),
          ),
          _avatar(cName, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      cName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(cTime),
                      style: const TextStyle(
                        fontSize: 10,
                        color: _kTextSec,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  cText,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF3A3836),
                  ),
                ),
                const SizedBox(height: 4),
                // Reply to a reply — use same parent_id (flattens)
                GestureDetector(
                  onTap: () {
                    setState(() => _replyingTo = c);
                    _focusNode.requestFocus();
                  },
                  child: const Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kTextSec,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isOwn)
            GestureDetector(
              onTap: () => _deleteComment(cId),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.delete_outline,
                  size: 14,
                  color: Color(0xFFCCC9C3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
