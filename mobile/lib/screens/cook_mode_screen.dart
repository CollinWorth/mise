import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/recipe.dart';

// ── In-memory cook state ─────────────────────────────────────────────────────
// Keyed by recipe ID. Resets when the app process dies (no persistence).
class _CookState {
  static final Map<String, Set<int>> _checked = {};
  static final Map<String, int> _multiplier = {};

  static Set<int> checked(String id) => _checked[id] ?? {};
  static int multiplier(String id) => _multiplier[id] ?? 1;

  static void toggle(String id, int i) {
    _checked[id] ??= {};
    if (!_checked[id]!.remove(i)) _checked[id]!.add(i);
  }

  static void setMultiplier(String id, int m) => _multiplier[id] = m;

  static void reset(String id) {
    _checked.remove(id);
    _multiplier.remove(id);
  }
}

// ── Quantity math ─────────────────────────────────────────────────────────────
double? _parseFraction(String s) {
  s = s.trim();
  // "1 1/2" mixed number
  final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s);
  if (mixed != null) {
    return double.parse(mixed.group(1)!) +
        double.parse(mixed.group(2)!) / double.parse(mixed.group(3)!);
  }
  // "3/4" simple fraction
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
  if (frac != null) return double.parse(frac.group(1)!) / double.parse(frac.group(2)!);
  // plain number
  return double.tryParse(s);
}

String _formatQty(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  final whole = v.floor();
  final frac = v - whole;
  final fracs = {
    1 / 8: '1/8', 1 / 4: '1/4', 1 / 3: '1/3',
    3 / 8: '3/8', 1 / 2: '1/2', 5 / 8: '5/8',
    2 / 3: '2/3', 3 / 4: '3/4', 7 / 8: '7/8',
  };
  for (final entry in fracs.entries) {
    if ((frac - entry.key).abs() < 0.04) {
      return whole > 0 ? '$whole ${entry.value}' : entry.value;
    }
  }
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

String multiplyQty(String qty, int mult) {
  if (qty.isEmpty || mult == 1) return qty;
  final v = _parseFraction(qty);
  if (v == null) return qty;
  return _formatQty(v * mult);
}

// ── Screen ────────────────────────────────────────────────────────────────────
class CookModeScreen extends StatefulWidget {
  final Recipe recipe;
  const CookModeScreen({super.key, required this.recipe});

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  String get _id => widget.recipe.id;
  bool _keepAwake = false;
  bool _showQtyHints = false;

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mult = _CookState.multiplier(_id);
    final checked = _CookState.checked(_id);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1A1918) : const Color(0xFFF7F6F3),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(mult, checked),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  if (widget.recipe.ingredients.isNotEmpty) ...[
                    _sectionLabel('Ingredients'),
                    const SizedBox(height: 10),
                    ...widget.recipe.ingredients.asMap().entries.map((e) =>
                      _IngredientRow(
                        ingredient: e.value,
                        index: e.key,
                        checked: checked.contains(e.key),
                        multiplier: mult,
                        onTap: () => setState(() => _CookState.toggle(_id, e.key)),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  if (widget.recipe.instructions.isNotEmpty) ...[
                    _sectionLabel('Instructions'),
                    const SizedBox(height: 12),
                    ...widget.recipe.instructions
                        .split('\n')
                        .where((s) => s.trim().isNotEmpty)
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => _StepRow(
                          step: e.value.trim(),
                          index: e.key + 1,
                          ingredients: _showQtyHints ? widget.recipe.ingredients : null,
                          multiplier: mult,
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int mult, Set<int> checked) {
    final total = widget.recipe.ingredients.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = dark ? const Color(0xFF2C2C2A) : const Color(0xFFECEAE6);
    final iconColor = dark ? Colors.white : const Color(0xFF1A1918);
    final borderColor = dark ? const Color(0xFF2C2C2A) : const Color(0xFFE5E2DC);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Icon(Icons.close, color: iconColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.recipe.name,
                  style: TextStyle(color: iconColor, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _CookState.reset(_id)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      checked.isEmpty ? '0/$total' : '${checked.length}/$total  ↺',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: checked.isEmpty ? const Color(0xFF888480) : const Color(0xFF2D9D5C),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              _toggleBtn(
                icon: _keepAwake ? Icons.coffee : Icons.coffee_outlined,
                active: _keepAwake,
                activeColor: const Color(0xFFE8622A),
                chipBg: chipBg,
                iconColor: iconColor,
                tooltip: _keepAwake ? 'Screen stays on' : 'Keep screen on',
                onTap: () {
                  setState(() => _keepAwake = !_keepAwake);
                  if (_keepAwake) WakelockPlus.enable(); else WakelockPlus.disable();
                },
              ),
              const SizedBox(width: 6),
              _toggleBtn(
                icon: _showQtyHints ? Icons.tips_and_updates : Icons.tips_and_updates_outlined,
                active: _showQtyHints,
                activeColor: const Color(0xFF4A7EC7),
                chipBg: chipBg,
                iconColor: iconColor,
                tooltip: _showQtyHints ? 'Hide qty hints' : 'Show qty hints in steps',
                onTap: () => setState(() => _showQtyHints = !_showQtyHints),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Servings:', style: TextStyle(fontSize: 13, color: Color(0xFF888480), fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              ...([1, 2, 3].map((m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _CookState.setMultiplier(_id, m)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44, height: 34,
                    decoration: BoxDecoration(
                      color: mult == m ? const Color(0xFFE8622A) : chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${m}x',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: mult == m ? Colors.white : const Color(0xFF888480),
                        ),
                      ),
                    ),
                  ),
                ),
              ))),
              if (widget.recipe.servings > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '= ${widget.recipe.servings * mult} servings',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF666360)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn({
    required IconData icon,
    required bool active,
    required Color activeColor,
    required Color chipBg,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? activeColor.withOpacity(0.15) : chipBg,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: active ? activeColor.withOpacity(0.5) : Colors.transparent),
          ),
          child: Icon(icon, size: 18, color: active ? activeColor : iconColor),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dark ? const Color(0xFF666360) : const Color(0xFF888480), letterSpacing: 1),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final Ingredient ingredient;
  final int index;
  final bool checked;
  final int multiplier;
  final VoidCallback onTap;

  const _IngredientRow({
    required this.ingredient,
    required this.index,
    required this.checked,
    required this.multiplier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qty = multiplyQty(ingredient.quantity, multiplier);
    final qtyLabel = [qty, ingredient.unit].where((s) => s.isNotEmpty).join(' ');
    final dark = Theme.of(context).brightness == Brightness.dark;

    final bgNormal  = dark ? const Color(0xFF242422) : Colors.white;
    final bgChecked = dark ? const Color(0xFF141413) : const Color(0xFFF0EEE9);
    final borderNormal  = dark ? const Color(0xFF333330) : const Color(0xFFE5E2DC);
    final borderChecked = dark ? const Color(0xFF2C2C2A) : const Color(0xFFDDDAD5);
    final textNormal  = dark ? Colors.white : const Color(0xFF1A1918);
    final textChecked = dark ? const Color(0xFF555552) : const Color(0xFFBBB8B2);
    final qtyBgNormal  = dark ? const Color(0xFF2C2C2A) : const Color(0xFFF7F6F3);
    final qtyBgChecked = dark ? const Color(0xFF1E1E1C) : const Color(0xFFECEAE6);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: checked ? bgChecked : bgNormal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: checked ? borderChecked : borderNormal),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: checked ? const Color(0xFF2D9D5C) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? const Color(0xFF2D9D5C) : (dark ? const Color(0xFF555552) : const Color(0xFFCCC9C3)),
                  width: 2,
                ),
              ),
              child: checked ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ingredient.name,
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500,
                  color: checked ? textChecked : textNormal,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  decorationColor: textChecked,
                ),
              ),
            ),
            if (qtyLabel.isNotEmpty) ...[
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: checked ? qtyBgChecked : qtyBgNormal,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  qtyLabel,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: checked ? (dark ? const Color(0xFF444440) : const Color(0xFFBBB8B2)) : const Color(0xFFE8622A),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final int index;
  final List<Ingredient>? ingredients;
  final int multiplier;

  const _StepRow({
    required this.step,
    required this.index,
    this.ingredients,
    this.multiplier = 1,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final hints = ingredients?.where((ing) {
      if (ing.name.trim().isEmpty) return false;
      return step.toLowerCase().contains(ing.name.trim().toLowerCase());
    }).toList() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF2C2C2A) : const Color(0xFFECEAE6),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  child: Text('$index', style: const TextStyle(color: Color(0xFFE8622A), fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              if (hints.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final ing in hints) _qtyBadge(ing),
              ],
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(step, style: TextStyle(color: dark ? const Color(0xFFCCCAC6) : const Color(0xFF444440), fontSize: 15, height: 1.55)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBadge(Ingredient ing) {
    final qty = multiplyQty(ing.quantity, multiplier);
    final label = [qty, ing.unit].where((s) => s.isNotEmpty).join(' ');
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE8622A).withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE8622A).withOpacity(0.35)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFE8622A))),
      ),
    );
  }
}
