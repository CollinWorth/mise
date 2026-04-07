import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/pantry_service.dart';
import '../storage/storage.dart';

// Shows a multi-recipe ingredient picker for meal plan week generation
Future<void> showMealPlanGrocerySheet(
  BuildContext context, {
  required List<Recipe> recipes,
  required Map<String, dynamic> user,
  required String weekLabel,
  VoidCallback? onAdded,
}) async {
  // Merge ingredients across recipes, deduplicate by name
  final seen = <String>{};
  final merged = <Ingredient>[];
  for (final r in recipes) {
    for (final ing in r.ingredients) {
      final key = ing.name.toLowerCase().trim();
      if (seen.add(key)) merged.add(ing);
    }
  }

  // Build a synthetic recipe to reuse the sheet
  final syntheticRecipe = Recipe(
    id: 'meal_plan',
    name: '$weekLabel · ${recipes.length} recipe${recipes.length == 1 ? '' : 's'}',
    cuisine: '',
    prepTime: 0, cookTime: 0, servings: 0,
    instructions: '',
    ingredients: merged,
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToGrocerySheet(recipe: syntheticRecipe, user: user, onAdded: onAdded),
  );
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

// Re-use categorize from grocery_screen — copied here to avoid import cycle
String _categorize(String name) {
  const sections = {
    'produce': ['apple','banana','orange','lemon','lime','berry','berries','grape','melon','mango','peach','pear','tomato','tomatoes','cucumber','lettuce','spinach','kale','arugula','cabbage','broccoli','cauliflower','carrot','carrots','celery','onion','onions','garlic','ginger','potato','potatoes','sweet potato','zucchini','squash','pepper','peppers','mushroom','mushrooms','herb','cilantro','parsley','basil','thyme','rosemary','mint','dill','scallion','corn','peas','edamame','avocado'],
    'meat': ['chicken','beef','pork','lamb','turkey','duck','steak','ground beef','ground turkey','bacon','sausage','ham','salmon','tuna','shrimp','crab','lobster','scallop','fish','seafood'],
    'dairy': ['milk','cream','heavy cream','butter','ghee','cheese','cheddar','mozzarella','parmesan','feta','ricotta','cream cheese','sour cream','yogurt','egg','eggs'],
    'bakery': ['bread','loaf','baguette','roll','bun','bagel','tortilla','pita','naan','sourdough'],
    'frozen': ['frozen'],
    'canned': ['canned','tomato sauce','tomato paste','crushed tomatoes','coconut milk','broth','stock','soup','chickpeas','beans','lentils','olives','capers','anchovies','pickles','jam','nut butter','peanut butter','tahini'],
    'dry': ['pasta','spaghetti','penne','rice','quinoa','couscous','farro','flour','cornstarch','oat','oats','cereal','crackers','breadcrumbs','panko'],
    'condiments': ['ketchup','mustard','mayo','hot sauce','soy sauce','fish sauce','oyster sauce','vinegar','oil','olive oil'],
    'spices': ['salt','pepper','cumin','coriander','paprika','chili','cayenne','turmeric','curry','cinnamon','nutmeg','vanilla','sugar','brown sugar','baking powder','baking soda','yeast','cocoa','chocolate'],
    'beverages': ['water','juice','coffee','tea','wine','beer'],
  };
  final lower = name.toLowerCase();
  for (final entry in sections.entries) {
    if (entry.value.any((kw) => lower.contains(kw))) return entry.key;
  }
  return 'other';
}
