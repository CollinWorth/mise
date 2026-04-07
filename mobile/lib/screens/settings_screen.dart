import 'package:flutter/material.dart';
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
  int _weekStart = 0; // 0=Sun, 1=Mon

  @override
  void initState() {
    super.initState();
    PlannerPrefs.weekStart().then((v) => setState(() => _weekStart = v));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final border = Theme.of(context).dividerColor;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: textPrimary)),
            const SizedBox(height: 28),

            _sectionLabel('Appearance', textSecondary),
            const SizedBox(height: 10),
            _ThemePicker(),

            const SizedBox(height: 28),
            _sectionLabel('Storage', textSecondary),
            const SizedBox(height: 10),
            _card(
              surface: surface, border: border,
              child: Column(
                children: [
                  _row(
                    icon: Icons.storage_outlined,
                    label: 'Storage mode',
                    value: Store.isReady ? _modeLabel(Store.i.mode) : '—',
                    textPrimary: textPrimary, textSecondary: textSecondary,
                    onTap: widget.onStorageChange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            _sectionLabel('Planner', textSecondary),
            const SizedBox(height: 10),
            _card(
              surface: surface, border: border,
              child: _row(
                icon: Icons.calendar_month_outlined,
                label: 'Week starts on',
                value: _weekStart == 0 ? 'Sunday' : 'Monday',
                textPrimary: textPrimary, textSecondary: textSecondary,
                onTap: () async {
                  final next = _weekStart == 0 ? 1 : 0;
                  await PlannerPrefs.setWeekStart(next);
                  setState(() => _weekStart = next);
                },
              ),
            ),

            const SizedBox(height: 28),
            _sectionLabel('Grocery', textSecondary),
            const SizedBox(height: 10),
            _card(
              surface: surface, border: border,
              child: _row(
                icon: Icons.kitchen_outlined,
                label: 'Pantry staples',
                textPrimary: textPrimary, textSecondary: textSecondary,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantryEditorScreen())),
              ),
            ),

            if (Store.isReady && Store.i.mode == StorageMode.server) ...[
              const SizedBox(height: 28),
              _sectionLabel('Account', textSecondary),
              const SizedBox(height: 10),
              _card(
                surface: surface, border: border,
                child: Column(
                  children: [
                    _row(
                      icon: Icons.person_outline,
                      label: widget.user['email'] as String? ?? 'User',
                      textPrimary: textPrimary, textSecondary: textSecondary,
                    ),
                    Divider(height: 1, color: border),
                    _row(
                      icon: Icons.logout,
                      label: 'Sign out',
                      isDestructive: true,
                      textPrimary: textPrimary, textSecondary: textSecondary,
                      onTap: () async {
                        await Api.clearSession();
                        widget.onLogout();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8)),
  );

  Widget _card({required Color surface, required Color border, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    String? value,
    bool isDestructive = false,
    required Color textPrimary,
    required Color textSecondary,
    VoidCallback? onTap,
  }) {
    final color = isDestructive ? const Color(0xFFE8622A) : textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDestructive ? const Color(0xFFE8622A) : textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color))),
            if (value != null) ...[
              Text(value, style: TextStyle(fontSize: 14, color: textSecondary)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: textSecondary),
            ] else if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: textSecondary),
          ],
        ),
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
    final border = Theme.of(context).dividerColor;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.notifier,
      builder: (_, current, __) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ThemeOption(
                icon: Icons.wb_sunny_outlined,
                label: 'Light',
                mode: ThemeMode.light,
                current: current,
                onTap: () { ThemeService.set(ThemeMode.light); setState(() {}); },
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                icon: Icons.nights_stay_outlined,
                label: 'Dark',
                mode: ThemeMode.dark,
                current: current,
                onTap: () { ThemeService.set(ThemeMode.dark); setState(() {}); },
              ),
              const SizedBox(width: 8),
              _ThemeOption(
                icon: Icons.phone_iphone,
                label: 'System',
                mode: ThemeMode.system,
                current: current,
                onTap: () { ThemeService.set(ThemeMode.system); setState(() {}); },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon, required this.label, required this.mode,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Icon(icon, size: 22, color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
