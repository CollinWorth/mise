import 'package:flutter/material.dart';
import '../storage/storage.dart';
import '../api.dart';

class StorageSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const StorageSetupScreen({super.key, required this.onComplete});

  @override
  State<StorageSetupScreen> createState() => _StorageSetupScreenState();
}

class _StorageSetupScreenState extends State<StorageSetupScreen> {
  StorageMode? _selected;
  final _urlCtrl = TextEditingController(text: kBaseUrl);
  bool _loading = false;

  Future<void> _confirm() async {
    if (_selected == null || _loading) return;
    setState(() => _loading = true);

    if (_selected == StorageMode.local) {
      Store.setLocal();
      await Store.saveMode(StorageMode.local);
      if (mounted) widget.onComplete();
    } else if (_selected == StorageMode.server) {
      final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
      Api.setBaseUrl(url);
      Store.setServer(baseUrl: url);
      await Store.saveMode(StorageMode.server, serverUrl: url);
      if (mounted) widget.onComplete();
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      // Use resizeToAvoidBottomInset so keyboard pushes content up
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Where should\nmise store your data?',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can change this in settings later.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF888480)),
                    ),
                    const SizedBox(height: 32),

                    _ModeCard(
                      icon: '📱',
                      title: 'Local',
                      subtitle: 'Stored on this device only. Works offline. No account needed.',
                      selected: _selected == StorageMode.local,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _selected = StorageMode.local);
                      },
                    ),
                    const SizedBox(height: 12),

                    _ModeCard(
                      icon: '🖥',
                      title: 'My Server',
                      subtitle: 'Self-hosted backend. You control the data.',
                      selected: _selected == StorageMode.server,
                      onTap: () => setState(() => _selected = StorageMode.server),
                    ),

                    if (_selected == StorageMode.server) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _urlCtrl,
                          autofocus: false,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Server URL',
                            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF888480)),
                            hintText: 'http://100.x.x.x:8000',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: '☁️',
                      title: 'Cloud',
                      subtitle: 'Coming soon — sync across all your devices.',
                      selected: false,
                      disabled: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Sticky footer button
            Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F6F3),
                border: Border(top: BorderSide(color: Color(0xFFE5E2DC))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selected == null || _loading) ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8622A),
                    disabledBackgroundColor: const Color(0xFFE5E2DC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: disabled ? const Color(0xFFF0EEE9) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFE8622A) : const Color(0xFFE5E2DC),
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: disabled ? const Color(0xFFBBB8B2) : const Color(0xFF1A1918),
                      )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: disabled ? const Color(0xFFCCC9C3) : const Color(0xFF888480),
                      )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? const Color(0xFFE8622A) : Colors.transparent,
                  border: Border.all(
                    color: selected ? const Color(0xFFE8622A) : (disabled ? const Color(0xFFDDDAD5) : const Color(0xFFCCC9C3)),
                    width: 2,
                  ),
                ),
                child: selected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
