import 'package:flutter/material.dart';
import '../services/pantry_service.dart';

class PantryEditorScreen extends StatefulWidget {
  const PantryEditorScreen({super.key});

  @override
  State<PantryEditorScreen> createState() => _PantryEditorScreenState();
}

class _PantryEditorScreenState extends State<PantryEditorScreen> {
  List<String> _items = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await PantryService.get();
    setState(() { _items = List.from(items)..sort(); _loading = false; });
  }

  Future<void> _remove(String item) async {
    await PantryService.remove(item);
    setState(() => _items.remove(item));
  }

  Future<void> _add() async {
    final text = _ctrl.text.trim().toLowerCase();
    if (text.isEmpty || _items.contains(text)) return;
    await PantryService.add(text);
    _ctrl.clear();
    setState(() { _items.add(text); _items.sort(); });
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text('This will replace your pantry list with the default staples.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Color(0xFFE8622A))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PantryService.resetToDefaults();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    final border = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF2C2C2A) : const Color(0xFFECEAE6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Pantry Staples',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: textPrimary)),
                  ),
                  TextButton(
                    onPressed: _resetDefaults,
                    child: const Text('Reset', style: TextStyle(fontSize: 13, color: Color(0xFF888480))),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Text(
                'Items here are pre-deselected when adding to your grocery list.',
                style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
              ),
            ),

            // Add field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      textCapitalization: TextCapitalization.none,
                      style: TextStyle(color: textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Add an item…',
                        hintStyle: TextStyle(color: textSecondary),
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE8622A)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _add,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8622A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: border),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8622A), strokeWidth: 2))
                  : _items.isEmpty
                      ? Center(child: Text('No pantry items', style: TextStyle(color: textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => Divider(height: 1, indent: 20, color: border),
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              leading: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8622A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(item, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary)),
                              trailing: GestureDetector(
                                onTap: () => _remove(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 16, color: textSecondary),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
