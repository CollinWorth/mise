import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../storage/storage.dart';
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
  int _recipeCount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final uid = widget.user['id'] ?? widget.user['_id'];
      if (uid == null || uid == 'local') { setState(() => _loaded = true); return; }
      final r = await Api.get('/recipes/user/$uid');
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        setState(() { _recipeCount = data.length; _loaded = true; });
      }
    } catch (_) {
      setState(() => _loaded = true);
    }
  }

  Widget _menuRow({required IconData icon, required String label, required Color color, required Color textColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor))),
            Icon(Icons.chevron_right, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          user: widget.user,
          onLogout: widget.onLogout,
          onStorageChange: widget.onStorageChange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;

    final name = widget.user['name'] as String? ?? 'You';
    final email = widget.user['email'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isServer = Store.isReady && Store.i.mode == StorageMode.server;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),

            // ── Top bar ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                    letterSpacing: -0.5, color: textPrimary)),
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: textSecondary, size: 22),
                  onPressed: _openSettings,
                  padding: EdgeInsets.zero,
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Avatar + info ─────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 84, height: 84,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8622A),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(initial,
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  Text(name,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                      letterSpacing: -0.3, color: textPrimary)),
                  if (isServer && email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(email,
                      style: TextStyle(fontSize: 14, color: textSecondary)),
                  ],
                  const SizedBox(height: 16),

                  // Recipe count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loaded ? '$_recipeCount' : '—',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFE8622A))),
                        const SizedBox(width: 6),
                        Text('recipes',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ── Menu rows ─────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              clipBehavior: Clip.hardEdge,
              child: _menuRow(
                icon: Icons.settings_outlined,
                label: 'Settings',
                color: textSecondary,
                textColor: textPrimary,
                onTap: _openSettings,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
