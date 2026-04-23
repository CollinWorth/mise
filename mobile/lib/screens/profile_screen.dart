import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../storage/storage.dart';
import 'follow_list_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final VoidCallback onStorageChange;
  const ProfileScreen({super.key, required this.user, required this.onLogout, required this.onStorageChange});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _recipeCount    = 0;
  int _followerCount  = 0;
  int _followingCount = 0;
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = widget.user['id'] ?? widget.user['_id'];
      if (uid == null || uid == 'local') { setState(() => _loaded = true); return; }
      final results = await Future.wait([Api.get('/recipes/user/$uid'), Api.get('/users/$uid')]);
      if (results[0].statusCode == 200) {
        _recipeCount = (jsonDecode(results[0].body) as List).length;
      }
      if (results[1].statusCode == 200) {
        final p = jsonDecode(results[1].body) as Map<String, dynamic>;
        _followerCount  = (p['follower_count']  as num?)?.toInt() ?? 0;
        _followingCount = (p['following_count'] as num?)?.toInt() ?? 0;
      }
      if (mounted) setState(() => _loaded = true);
    } catch (_) { if (mounted) setState(() => _loaded = true); }
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
      user: widget.user, onLogout: widget.onLogout, onStorageChange: widget.onStorageChange,
    ))).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final tp  = Theme.of(context).colorScheme.onSurface;
    final ts  = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final surface = Theme.of(context).colorScheme.surface;
    final border  = Theme.of(context).dividerColor;
    final name    = widget.user['name'] as String? ?? 'You';
    final email   = widget.user['email'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isServer = Store.isReady && Store.i.mode == StorageMode.server;
    final uid = widget.user['id'] ?? widget.user['_id'];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profile', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tp)),
                  IconButton(icon: Icon(Icons.settings_outlined, color: ts, size: 22), onPressed: _openSettings, padding: EdgeInsets.zero),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(children: [
                  Container(
                    width: 84, height: 84,
                    decoration: const BoxDecoration(color: Color(0xFFE8622A), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initial, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: tp)),
                  if (isServer && email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(email, style: TextStyle(fontSize: 14, color: ts)),
                  ],
                  const SizedBox(height: 20),
                  // Stats row
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _stat(surface, border, tp, ts, value: _loaded ? '$_recipeCount' : '—', label: 'recipes'),
                      if (isServer && uid != null && uid != 'local') ...[
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => FollowListScreen(userId: uid, type: 'followers', currentUser: widget.user))),
                          child: _stat(surface, border, tp, ts, value: _loaded ? '$_followerCount' : '—', label: 'followers'),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => FollowListScreen(userId: uid, type: 'following', currentUser: widget.user))),
                          child: _stat(surface, border, tp, ts, value: _loaded ? '$_followingCount' : '—', label: 'following'),
                        ),
                      ],
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: _openSettings,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(children: [
                      Icon(Icons.settings_outlined, size: 20, color: ts),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tp))),
                      Icon(Icons.chevron_right, size: 18, color: ts),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(Color surface, Color border, Color tp, Color ts, {required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFE8622A))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ts)),
      ]),
    );
  }
}
