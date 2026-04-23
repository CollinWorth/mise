import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/pantry_service.dart';
import '../storage/storage.dart';

// Shows a two-step meal plan grocery sheet: (1) recipe selection, (2) ingredient selection
Future<void> showMealPlanGrocerySheet(
  BuildContext context, {
  required List<Recipe> recipes,
  required Map<String, dynamic> user,
  required String weekLabel,
  VoidCallback? onAdded,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MealPlanGrocerySheet(
      recipes: recipes,
      user: user,
      weekLabel: weekLabel,
      onAdded: onAdded,
    ),
  );
}

// ── Quantity combining helper ────────────────────────────────────────────────
List<Ingredient> _mergeIngredients(List<Recipe> recipes) {
  final result = <String, Ingredient>{};
  for (final recipe in recipes) {
    for (final ing in recipe.ingredients) {
      final key = ing.name.toLowerCase().trim();
      if (key.isEmpty) continue;
      if (result.containsKey(key)) {
        final existing = result[key]!;
        final existingQty = double.tryParse(existing.quantity) ?? 0;
        final newQty = double.tryParse(ing.quantity) ?? 0;
        if (existingQty > 0 && newQty > 0) {
          final combined = existingQty + newQty;
          final combinedStr = combined == combined.truncateToDouble()
              ? '${combined.truncate()}'
              : combined.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
          result[key] = Ingredient(name: existing.name, quantity: combinedStr, unit: existing.unit);
        }
      } else {
        result[key] = ing;
      }
    }
  }
  return result.values.toList();
}

// ── Two-step meal plan sheet ─────────────────────────────────────────────────
class _MealPlanGrocerySheet extends StatefulWidget {
  final List<Recipe> recipes; // may include duplicates (same recipe on multiple days)
  final Map<String, dynamic> user;
  final String weekLabel;
  final VoidCallback? onAdded;
  const _MealPlanGrocerySheet({required this.recipes, required this.user, required this.weekLabel, this.onAdded});

  @override
  State<_MealPlanGrocerySheet> createState() => _MealPlanGrocerySheetState();
}

class _MealPlanGrocerySheetState extends State<_MealPlanGrocerySheet> {
  // Step 0: recipe selection
  late final List<({Recipe recipe, int count})> _uniqueRecipes;
  late final Map<String, bool> _recipeSelected;

  // Step 1: ingredient selection
  int _step = 0;
  List<String> _pantry = [];
  List<Ingredient> _ingredients = [];
  Map<int, bool> _ingSelected = {};
  bool _loading = false;
  bool _saving = false;
  bool _editingPantry = false;
  final _newPantryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Build unique recipes preserving order, tracking count
    final countMap = <String, int>{};
    final recipeMap = <String, Recipe>{};
    for (final r in widget.recipes) {
      if (!recipeMap.containsKey(r.id)) recipeMap[r.id] = r;
      countMap[r.id] = (countMap[r.id] ?? 0) + 1;
    }
    _uniqueRecipes = recipeMap.entries
        .map((e) => (recipe: e.value, count: countMap[e.key]!))
        .toList();
    _recipeSelected = {for (final e in _uniqueRecipes) e.recipe.id: true};
  }

  @override
  void dispose() {
    _newPantryCtrl.dispose();
    super.dispose();
  }

  int get _selectedRecipeCount => _recipeSelected.values.where((v) => v).length;

  Future<void> _toIngredients() async {
    setState(() => _loading = true);
    final selected = widget.recipes.where((r) => _recipeSelected[r.id] == true).toList();
    final merged = _mergeIngredients(selected);
    final pantry = await PantryService.get();
    final sel = <int, bool>{};
    for (var i = 0; i < merged.length; i++) {
      sel[i] = !PantryService.matches(merged[i].name, pantry);
    }
    setState(() {
      _step = 1;
      _pantry = pantry;
      _ingredients = merged;
      _ingSelected = sel;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = widget.user['id'] ?? widget.user['_id'];
    var list = await Store.i.getGroceryList(uid);
    list ??= await Store.i.createGroceryList({'name': 'My List', 'user_id': uid, 'items': []});
    final listId = list['_id'] as String;
    final toAdd = _ingredients.asMap().entries.where((e) => _ingSelected[e.key] == true).map((e) => e.value).toList();
    for (final ing in toAdd) {
      await Store.i.addGroceryItem(listId, {
        'name': ing.name, 'quantity': ing.quantity, 'unit': ing.unit,
        'category': _categorize(ing.name), 'checked': false,
      });
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onAdded?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added ${toAdd.length} item${toAdd.length == 1 ? '' : 's'} to grocery list'),
        backgroundColor: const Color(0xFF2D9D5C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _reapplyPantry() {
    for (var i = 0; i < _ingredients.length; i++) {
      if (PantryService.matches(_ingredients[i].name, _pantry)) _ingSelected[i] = false;
    }
    setState(() {});
  }

  int get _selectedIngCount => _ingSelected.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F6F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDDDAD5), borderRadius: BorderRadius.circular(99))),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                if (_step == 1)
                  GestureDetector(
                    onTap: () => setState(() => _step = 0),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF888480)),
                    ),
                  ),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_step == 0 ? 'Choose recipes' : 'Add to Grocery List',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(widget.weekLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF888480))),
                  ],
                )),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white, border: Border.all(color: const Color(0xFFE5E2DC)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF888480)),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE8622A))))
          else if (_step == 0)
            ..._buildRecipeStep()
          else
            ..._buildIngredientStep(),
        ],
      ),
    );
  }

  List<Widget> _buildRecipeStep() {
    return [
      Flexible(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          shrinkWrap: true,
          itemCount: _uniqueRecipes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final (:recipe, :count) = _uniqueRecipes[i];
            final selected = _recipeSelected[recipe.id] ?? true;
            return GestureDetector(
              onTap: () => setState(() => _recipeSelected[recipe.id] = !selected),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : const Color(0xFFF0EEE9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? const Color(0xFFE5E2DC) : const Color(0xFFDDDAD5)),
                ),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFE8622A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? const Color(0xFFE8622A) : const Color(0xFFCCC9C3), width: 2),
                    ),
                    child: selected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(recipe.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: selected ? const Color(0xFF1A1918) : const Color(0xFFBBB8B2),
                          decoration: selected ? null : TextDecoration.lineThrough,
                          decorationColor: const Color(0xFFBBB8B2))),
                      if (recipe.servings > 0)
                        Text('serves ${recipe.servings}',
                          style: TextStyle(fontSize: 11,
                            color: selected ? const Color(0xFF888480) : const Color(0xFFCCC9C3))),
                    ],
                  )),
                  if (count > 1)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8622A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('×$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE8622A))),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F6F3),
          border: Border(top: BorderSide(color: Color(0xFFE5E2DC))),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selectedRecipeCount == 0 ? null : _toIngredients,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8622A),
              disabledBackgroundColor: const Color(0xFFE5E2DC),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _selectedRecipeCount == 0
                  ? 'Select at least one recipe'
                  : 'Choose ingredients →  ($_selectedRecipeCount recipe${_selectedRecipeCount == 1 ? '' : 's'})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildIngredientStep() {
    return [
      Flexible(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          shrinkWrap: true,
          children: [
            Row(children: [
              const Expanded(child: Text('INGREDIENTS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888480), letterSpacing: 0.8))),
              TextButton(
                onPressed: () {
                  final allSel = _ingSelected.values.every((v) => v);
                  setState(() { for (final k in _ingSelected.keys) _ingSelected[k] = !allSel; });
                },
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFE8622A),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                child: Text(_ingSelected.values.every((v) => v) ? 'Deselect all' : 'Select all',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 8),
            ..._ingredients.asMap().entries.map((e) {
              final i = e.key; final ing = e.value;
              final checked = _ingSelected[i] ?? true;
              final inPantry = PantryService.matches(ing.name, _pantry);
              return GestureDetector(
                onTap: () => setState(() => _ingSelected[i] = !checked),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: checked ? Colors.white : const Color(0xFFF0EEE9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: checked ? const Color(0xFFE5E2DC) : const Color(0xFFDDDAD5)),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: checked ? const Color(0xFFE8622A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: checked ? const Color(0xFFE8622A) : const Color(0xFFCCC9C3), width: 2),
                      ),
                      child: checked ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(ing.name, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: checked ? const Color(0xFF1A1918) : const Color(0xFFBBB8B2),
                      decoration: checked ? null : TextDecoration.lineThrough,
                      decorationColor: const Color(0xFFBBB8B2)))),
                    if (inPantry && !checked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE5E2DC), borderRadius: BorderRadius.circular(99)),
                        child: const Text('in pantry', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF888480))),
                      )
                    else if (ing.quantity.isNotEmpty || ing.unit.isNotEmpty)
                      Text([ing.quantity, ing.unit].where((s) => s.isNotEmpty).join(' '),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                          color: checked ? const Color(0xFF888480) : const Color(0xFFCCC9C3))),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),
            // Pantry section
            Container(
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE5E2DC)), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: () => setState(() => _editingPantry = !_editingPantry),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(children: [
                      const Text('🏠', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('My Pantry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('Items auto-deselected above', style: TextStyle(fontSize: 12, color: Color(0xFF888480))),
                      ])),
                      Icon(_editingPantry ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF888480), size: 20),
                    ]),
                  ),
                ),
                if (_editingPantry) ...[
                  const Divider(height: 1, color: Color(0xFFE5E2DC)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      ..._pantry.map((item) => _PantryChip(label: item, onRemove: () async {
                        await PantryService.remove(item);
                        setState(() => _pantry.remove(item));
                        _reapplyPantry();
                      })),
                      SizedBox(width: 140, height: 32, child: TextField(
                        controller: _newPantryCtrl,
                        style: const TextStyle(fontSize: 12),
                        onSubmitted: (v) async {
                          if (v.trim().isEmpty) return;
                          await PantryService.add(v);
                          setState(() => _pantry.add(v.trim().toLowerCase()));
                          _newPantryCtrl.clear();
                          _reapplyPantry();
                        },
                        decoration: InputDecoration(
                          hintText: '+ Add item', hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF888480)),
                          filled: true, fillColor: const Color(0xFFF7F6F3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), isDense: true,
                        ),
                      )),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F6F3),
          border: Border(top: BorderSide(color: Color(0xFFE5E2DC))),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_selectedIngCount == 0 || _saving) ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8622A),
              disabledBackgroundColor: const Color(0xFFE5E2DC),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _selectedIngCount == 0 ? 'No items selected' : 'Add $_selectedIngCount item${_selectedIngCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    ];
  }
}

Future<void> showAddToGrocerySheet(
  BuildContext context, {
  required Recipe recipe,
  required Map<String, dynamic> user,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToGrocerySheet(recipe: recipe, user: user),
  );
}

class _AddToGrocerySheet extends StatefulWidget {
  final Recipe recipe;
  final Map<String, dynamic> user;
  final VoidCallback? onAdded;
  const _AddToGrocerySheet({required this.recipe, required this.user, this.onAdded});

  @override
  State<_AddToGrocerySheet> createState() => _AddToGrocerySheetState();
}

class _AddToGrocerySheetState extends State<_AddToGrocerySheet> {
  List<String> _pantry = [];
  late Map<int, bool> _selected; // index → selected
  bool _loading = true;
  bool _saving = false;
  bool _editingPantry = false;
  final _newPantryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pantry = await PantryService.get();
    final selected = <int, bool>{};
    for (var i = 0; i < widget.recipe.ingredients.length; i++) {
      final ing = widget.recipe.ingredients[i];
      // Pre-deselect if it matches a pantry item
      selected[i] = !PantryService.matches(ing.name, pantry);
    }
    setState(() { _pantry = pantry; _selected = selected; _loading = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = widget.user['id'] ?? widget.user['_id'];

    // Get or create grocery list
    var list = await Store.i.getGroceryList(uid);
    list ??= await Store.i.createGroceryList({'name': 'My List', 'user_id': uid, 'items': []});
    final listId = list['_id'] as String;

    // Add selected ingredients
    final toAdd = widget.recipe.ingredients
        .asMap()
        .entries
        .where((e) => _selected[e.key] == true)
        .map((e) => e.value)
        .toList();

    for (final ing in toAdd) {
      await Store.i.addGroceryItem(listId, {
        'name': ing.name,
        'quantity': ing.quantity,
        'unit': ing.unit,
        'category': _categorize(ing.name),
        'checked': false,
      });
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onAdded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${toAdd.length} item${toAdd.length == 1 ? '' : 's'} to grocery list'),
          backgroundColor: const Color(0xFF2D9D5C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _removePantryItem(String item) async {
    await PantryService.remove(item);
    setState(() => _pantry.remove(item));
    // Re-evaluate selections
    _reapplyPantry();
  }

  Future<void> _addPantryItem(String item) async {
    if (item.trim().isEmpty) return;
    await PantryService.add(item);
    setState(() => _pantry.add(item.trim().toLowerCase()));
    _newPantryCtrl.clear();
    _reapplyPantry();
  }

  void _reapplyPantry() {
    for (var i = 0; i < widget.recipe.ingredients.length; i++) {
      final ing = widget.recipe.ingredients[i];
      if (PantryService.matches(ing.name, _pantry)) {
        _selected[i] = false;
      }
    }
    setState(() {});
  }

  int get _selectedCount => _selected.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F6F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE8622A))))
          else
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                shrinkWrap: true,
                children: [
                  ..._buildIngredientList(),
                  const SizedBox(height: 12),
                  _buildPantrySection(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(color: const Color(0xFFDDDAD5), borderRadius: BorderRadius.circular(99)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add to Grocery List',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(widget.recipe.name,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888480))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E2DC)),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Icon(Icons.close, size: 16, color: Color(0xFF888480)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIngredientList() {
    return [
      Row(children: [
        const Expanded(
          child: Text('INGREDIENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888480), letterSpacing: 0.8)),
        ),
        TextButton(
          onPressed: () {
            final allSelected = _selected.values.every((v) => v);
            setState(() {
              for (final k in _selected.keys) {
                _selected[k] = !allSelected;
              }
            });
          },
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE8622A),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
          ),
          child: Text(
            _selected.values.every((v) => v) ? 'Deselect all' : 'Select all',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      ...widget.recipe.ingredients.asMap().entries.map((e) {
        final i = e.key;
        final ing = e.value;
        final checked = _selected[i] ?? true;
        final inPantry = PantryService.matches(ing.name, _pantry);
        return GestureDetector(
          onTap: () => setState(() => _selected[i] = !checked),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: checked ? Colors.white : const Color(0xFFF0EEE9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: checked ? const Color(0xFFE5E2DC) : const Color(0xFFDDDAD5),
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: checked ? const Color(0xFFE8622A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: checked ? const Color(0xFFE8622A) : const Color(0xFFCCC9C3),
                      width: 2,
                    ),
                  ),
                  child: checked ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ing.name,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: checked ? const Color(0xFF1A1918) : const Color(0xFFBBB8B2),
                      decoration: checked ? null : TextDecoration.lineThrough,
                      decorationColor: const Color(0xFFBBB8B2),
                    ),
                  ),
                ),
                if (inPantry && !checked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E2DC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('in pantry', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF888480))),
                  )
                else if (ing.quantity.isNotEmpty || ing.unit.isNotEmpty)
                  Text(
                    [ing.quantity, ing.unit].where((s) => s.isNotEmpty).join(' '),
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: checked ? const Color(0xFF888480) : const Color(0xFFCCC9C3),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  Widget _buildPantrySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E2DC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _editingPantry = !_editingPantry),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  const Text('🏠', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Pantry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('Items auto-deselected above', style: TextStyle(fontSize: 12, color: Color(0xFF888480))),
                      ],
                    ),
                  ),
                  Icon(
                    _editingPantry ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF888480), size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_editingPantry) ...[
            const Divider(height: 1, color: Color(0xFFE5E2DC)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._pantry.map((item) => _PantryChip(
                    label: item,
                    onRemove: () => _removePantryItem(item),
                  )),
                  // Add new item field
                  SizedBox(
                    width: 140,
                    height: 32,
                    child: TextField(
                      controller: _newPantryCtrl,
                      style: const TextStyle(fontSize: 12),
                      onSubmitted: _addPantryItem,
                      decoration: InputDecoration(
                        hintText: '+ Add item',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF888480)),
                        filled: true,
                        fillColor: const Color(0xFFF7F6F3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F6F3),
        border: Border(top: BorderSide(color: Color(0xFFE5E2DC))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: (_selectedCount == 0 || _saving) ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8622A),
            disabledBackgroundColor: const Color(0xFFE5E2DC),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  _selectedCount == 0
                      ? 'No items selected'
                      : 'Add $_selectedCount item${_selectedCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

class _PantryChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _PantryChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F3),
        border: Border.all(color: const Color(0xFFE5E2DC)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF555250))),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF888480)),
          ),
        ],
      ),
    );
  }
}

// Longest-match-wins categorization (kept in sync with grocery_screen.dart)
String _categorize(String name) {
  const kwMap = <String, List<String>>{
    'produce': ['strawberry','blueberry','raspberry','blackberry','bell pepper','red pepper','green pepper','cherry tomato','sweet potato','brussels sprout','fresh herb','fresh ginger','fresh garlic','button mushroom','shiitake','cremini','portobello','apple','banana','orange','lemon','lime','grape','mango','peach','pear','tomato','cucumber','zucchini','squash','lettuce','romaine','arugula','spinach','kale','chard','cabbage','broccoli','cauliflower','carrot','celery','fennel','leek','asparagus','eggplant','scallion','shallot','onion','garlic','ginger','potato','mushroom','corn','pea','edamame','beet','radish','cilantro','parsley','basil','thyme','rosemary','mint','dill','chive','sage','pepper','jalapeño','berry','herb'],
    'meat': ['ground beef','ground turkey','ground pork','ground chicken','chicken breast','chicken thigh','beef steak','pork belly','pork shoulder','italian sausage','breakfast sausage','smoked salmon','salmon fillet','mahi mahi','sea bass','chicken','beef','pork','lamb','turkey','duck','steak','brisket','bacon','prosciutto','salami','pepperoni','chorizo','ham','salmon','tuna','cod','tilapia','trout','anchovy','sardine','shrimp','crab','lobster','scallop','clam','mussel','oyster','fish','seafood','meat'],
    'dairy': ['heavy cream','heavy whipping cream','whipping cream','half and half','cream cheese','sour cream','cottage cheese','cheddar','mozzarella','parmesan','brie','feta','gouda','ricotta','gruyere','provolone','milk','cream','butter','ghee','cheese','yogurt','kefir','egg','ice cream'],
    'deli': ['sliced turkey','sliced ham','deli turkey','deli ham','roast beef','pastrami','prepared salad','coleslaw','hummus','tzatziki','rotisserie','deli'],
    'bakery': ['sourdough bread','whole wheat bread','white bread','hot dog bun','hamburger bun','pita bread','naan bread','english muffin','bread','loaf','baguette','roll','bun','bagel','croissant','muffin','pastry','tortilla','wrap','naan','sourdough','brioche','ciabatta'],
    'frozen': ['frozen pizza','frozen vegetable','frozen fruit','frozen meal','frozen waffle','frozen fries','frozen','popsicle','sorbet'],
    'canned': ['crushed tomatoes','diced tomatoes','whole tomatoes','tomato sauce','tomato paste','marinara sauce','pasta sauce','chicken broth','beef broth','vegetable broth','chicken stock','beef stock','coconut milk','coconut cream','black beans','kidney beans','white beans','chickpeas','garbanzo beans','pinto beans','artichoke hearts','canned tuna','canned salmon','pumpkin puree','peanut butter','almond butter','cashew butter','tahini','nut butter','pickles','relish','salsa','jam','jelly','preserves','olives','capers','anchovies','soup','broth','stock','canned','beans','lentils'],
    'dry': ['spaghetti','penne','rigatoni','fettuccine','linguine','farfalle','egg noodle','ramen noodle','rice noodle','all purpose flour','bread flour','whole wheat flour','almond flour','brown rice','white rice','jasmine rice','basmati rice','arborio rice','rolled oats','steel cut oats','instant oatmeal','pasta','noodle','rice','quinoa','couscous','farro','barley','bulgur','flour','cornstarch','cornmeal','oat','oatmeal','cereal','granola','crackers','breadcrumbs','panko','yeast'],
    'breakfast': ['maple syrup','pancake syrup','waffle mix','pancake mix','granola bar','syrup','honey'],
    'condiments': ['apple cider vinegar','balsamic vinegar','red wine vinegar','white wine vinegar','extra virgin olive oil','olive oil','vegetable oil','canola oil','sesame oil','coconut oil','avocado oil','soy sauce','tamari','worcestershire sauce','fish sauce','oyster sauce','hoisin sauce','teriyaki sauce','hot sauce','sriracha','tabasco','bbq sauce','barbecue sauce','ketchup','mustard','dijon mustard','mayonnaise','aioli','ranch dressing','caesar dressing','vinaigrette','balsamic glaze','gochujang','miso paste','curry paste','vanilla extract','vinegar','oil','sauce','dressing','mayo','miso'],
    'spices': ['red pepper flakes','crushed red pepper','smoked paprika','sweet paprika','garlic powder','onion powder','black pepper','white pepper','chili powder','curry powder','garam masala','ground cinnamon','ground cumin','ground coriander','ground cardamom','ground nutmeg','ground cloves','ground turmeric','dried oregano','dried thyme','dried rosemary','dried basil','dried sage','dried dill','bay leaf','bay leaves','fennel seed','sesame seed','baking powder','baking soda','cream of tartar','powdered sugar','brown sugar','granulated sugar','cocoa powder','dark chocolate','chocolate chip','kosher salt','sea salt','salt','pepper','paprika','cumin','coriander','turmeric','cinnamon','nutmeg','cloves','allspice','cardamom','cayenne','oregano','sugar','vanilla','cocoa','chocolate'],
    'beverages': ['sparkling water','mineral water','orange juice','apple juice','almond milk','oat milk','soy milk','coconut water','cold brew','white wine','red wine','prosecco','champagne','kombucha','lemonade','water','juice','coffee','tea','soda','beer','wine'],
    'household': ['paper towel','toilet paper','ziplock bag','aluminum foil','parchment paper','plastic wrap','trash bag','dish soap','dishwasher detergent','laundry detergent','foil','parchment','sponge','bleach','toothpaste','shampoo','conditioner','lotion','soap'],
  };
  final lower = name.toLowerCase().trim();
  String bestKey = 'other';
  int bestLen = 0;
  for (final entry in kwMap.entries) {
    for (final kw in entry.value) {
      if (kw.length > bestLen && lower.contains(kw)) {
        bestKey = entry.key;
        bestLen = kw.length;
      }
    }
  }
  return bestKey;
}
