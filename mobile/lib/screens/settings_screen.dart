import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/planner_prefs.dart';
import '../storage/storage.dart';
import '../api.dart';
import 'pantry_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final VoidCallback onStorageChange;
  const SettingsScreen({super.key, required this.user, required this.onLogout, required this.onStorageChange});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _weekStart = 0;

  @override
  void initState() {
    super.initState();
    PlannerPrefs.weekStart().then((v) => setState(() => _weekStart = v));
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Edit profile ─────────────────────────────────────────────────────
  void _editProfile() {
    final nameCtrl  = TextEditingController(text: widget.user['name'] as String? ?? '');
    final emailCtrl = TextEditingController(text: widget.user['email'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,  decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name  = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              if (name.isEmpty || email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final r = await Api.put('/users/me', {'name': name, 'email': email});
                if (r.statusCode == 200 && mounted) {
                  final updated = jsonDecode(r.body) as Map<String, dynamic>;
                  final prefs = await SharedPreferences.getInstance();
                  final stored = jsonDecode(prefs.getString('mise_user') ?? '{}') as Map<String, dynamic>;
                  stored['name']  = updated['name'];
                  stored['email'] = updated['email'];
                  await prefs.setString('mise_user', jsonEncode(stored));
                  _snack('Profile updated');
                } else if (mounted) {
                  final err = jsonDecode(r.body) as Map<String, dynamic>;
                  _snack(err['detail'] as String? ?? 'Failed to update profile', error: true);
                }
              } catch (_) { _snack('Network error', error: true); }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Change password ──────────────────────────────────────────────────
  void _changePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: currentCtrl, decoration: const InputDecoration(labelText: 'Current password'), obscureText: true),
          const SizedBox(height: 12),
          TextField(controller: newCtrl,     decoration: const InputDecoration(labelText: 'New password'),     obscureText: true),
          const SizedBox(height: 12),
          TextField(controller: confirmCtrl, decoration: const InputDecoration(labelText: 'Confirm new password'), obscureText: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) { _snack('Passwords do not match', error: true); return; }
              if (newCtrl.text.length < 6) { _snack('Password must be at least 6 characters', error: true); return; }
              Navigator.pop(ctx);
              try {
                final r = await Api.put('/users/me/password', {
                  'current_password': currentCtrl.text,
                  'new_password': newCtrl.text,
                });
                if (r.statusCode == 200 && mounted) {
                  _snack('Password changed');
                } else if (mounted) {
                  final err = jsonDecode(r.body) as Map<String, dynamic>;
                  _snack(err['detail'] as String? ?? 'Failed to change password', error: true);
                }
              } catch (_) { _snack('Network error', error: true); }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  // ── Delete account ───────────────────────────────────────────────────
  void _deleteAccount() {
    final pwCtrl      = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Permanently deletes your account and all your recipes. This cannot be undone.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(controller: pwCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          const SizedBox(height: 12),
          TextField(controller: confirmCtrl, decoration: const InputDecoration(labelText: 'Type "delete my account"')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              if (confirmCtrl.text.trim() != 'delete my account') {
                _snack('Type "delete my account" to confirm', error: true);
                return;
              }
              Navigator.pop(ctx);
              try {
                final r = await Api.deleteWithBody('/users/me', {'password': pwCtrl.text});
                if (r.statusCode == 200 && mounted) {
                  await Api.clearSession();
                  widget.onLogout();
                } else if (mounted) {
                  final err = jsonDecode(r.body) as Map<String, dynamic>;
                  _snack(err['detail'] as String? ?? 'Failed to delete account', error: true);
                }
              } catch (_) { _snack('Network error', error: true); }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final tp  = Theme.of(context).colorScheme.onSurface;
    final ts  = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final border  = Theme.of(context).dividerColor;
    final isServer = Store.isReady && Store.i.mode == StorageMode.server;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: tp)),
            const SizedBox(height: 28),

            _sectionLabel('Appearance', ts),
            const SizedBox(height: 10),
            _ThemePicker(),

            const SizedBox(height: 28),
            _sectionLabel('Storage', ts),
            const SizedBox(height: 10),
            _card(surface, border, _row(icon: Icons.storage_outlined, label: 'Storage mode',
              value: Store.isReady ? _modeLabel(Store.i.mode) : '—', tp: tp, ts: ts, onTap: widget.onStorageChange)),

            const SizedBox(height: 28),
            _sectionLabel('Planner', ts),
            const SizedBox(height: 10),
            _card(surface, border, _row(
              icon: Icons.calendar_month_outlined, label: 'Week starts on',
              value: _weekStart == 0 ? 'Sunday' : 'Monday', tp: tp, ts: ts,
              onTap: () async {
                final next = _weekStart == 0 ? 1 : 0;
                await PlannerPrefs.setWeekStart(next);
                setState(() => _weekStart = next);
              },
            )),

            const SizedBox(height: 28),
            _sectionLabel('Grocery', ts),
            const SizedBox(height: 10),
            _card(surface, border, _row(
              icon: Icons.kitchen_outlined, label: 'Pantry staples', tp: tp, ts: ts,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantryEditorScreen())),
            )),

            if (isServer) ...[
              const SizedBox(height: 28),
              _sectionLabel('Account', ts),
              const SizedBox(height: 10),
              _card(surface, border, Column(children: [
                _row(icon: Icons.person_outline, label: widget.user['email'] as String? ?? 'User', tp: tp, ts: ts),
                Divider(height: 1, color: border),
                _row(icon: Icons.edit_outlined,  label: 'Edit profile',    tp: tp, ts: ts, onTap: _editProfile),
                Divider(height: 1, color: border),
                _row(icon: Icons.lock_outline,   label: 'Change password', tp: tp, ts: ts, onTap: _changePassword),
                Divider(height: 1, color: border),
                _row(icon: Icons.logout,         label: 'Sign out',        tp: tp, ts: ts, destructive: true,
                  onTap: () async {
                    await Api.clearSession();
                    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                    widget.onLogout();
                  }),
              ])),
              const SizedBox(height: 12),
              _card(surface, border,
                _row(icon: Icons.delete_forever_outlined, label: 'Delete account',
                  tp: tp, ts: ts, destructive: true, onTap: _deleteAccount)),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8)),
  );

  Widget _card(Color surface, Color border, Widget child) => Container(
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
    clipBehavior: Clip.hardEdge,
    child: child,
  );

  Widget _row({required IconData icon, required String label, String? value,
      bool destructive = false, required Color tp, required Color ts, VoidCallback? onTap}) {
    final color = destructive ? const Color(0xFFDC2626) : tp;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: destructive ? const Color(0xFFDC2626) : ts),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color))),
          if (value != null) ...[
            Text(value, style: TextStyle(fontSize: 14, color: ts)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: ts),
          ] else if (onTap != null)
            Icon(Icons.chevron_right, size: 18, color: ts),
        ]),
      ),
    );
  }

  String _modeLabel(StorageMode m) => switch (m) {
    StorageMode.local  => 'Local',
    StorageMode.server => 'My Server',
    StorageMode.cloud  => 'Cloud',
  };
}

// ── Theme picker ──────────────────────────────────────────────────────────────
class _ThemePicker extends StatefulWidget {
  @override
  State<_ThemePicker> createState() => _ThemePickerState();
}

class _ThemePickerState extends State<_ThemePicker> {
  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final border  = Theme.of(context).dividerColor;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.notifier,
      builder: (_, current, __) => Container(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _opt(Icons.wb_sunny_outlined,    'Light',  ThemeMode.light,  current, () { ThemeService.set(ThemeMode.light);  setState(() {}); }),
          const SizedBox(width: 8),
          _opt(Icons.nights_stay_outlined, 'Dark',   ThemeMode.dark,   current, () { ThemeService.set(ThemeMode.dark);   setState(() {}); }),
          const SizedBox(width: 8),
          _opt(Icons.phone_iphone,         'System', ThemeMode.system, current, () { ThemeService.set(ThemeMode.system); setState(() {}); }),
        ]),
      ),
    );
  }

  Widget _opt(IconData icon, String label, ThemeMode mode, ThemeMode current, VoidCallback onTap) {
    final active = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1A1918) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Icon(icon, size: 22, color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ]),
        ),
      ),
    );
  }
}
