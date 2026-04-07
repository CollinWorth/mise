import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models/recipe.dart';
import '../storage/storage.dart';
import '../services/pantry_service.dart';
import 'add_to_grocery_sheet.dart';

// Store sections in aisle order
const _sections = [
  _Section('produce', 'Produce', '🥦', ['apple', 'banana', 'orange', 'lemon', 'lime', 'berry', 'berries', 'grape', 'melon', 'mango', 'peach', 'pear', 'plum', 'cherry', 'avocado', 'tomato', 'tomatoes', 'cucumber', 'lettuce', 'spinach', 'kale', 'arugula', 'cabbage', 'broccoli', 'cauliflower', 'carrot', 'carrots', 'celery', 'onion', 'onions', 'shallot', 'shallots', 'garlic', 'ginger', 'potato', 'potatoes', 'sweet potato', 'yam', 'zucchini', 'squash', 'pepper', 'peppers', 'jalapeño', 'mushroom', 'mushrooms', 'herb', 'herbs', 'cilantro', 'parsley', 'basil', 'thyme', 'rosemary', 'mint', 'dill', 'scallion', 'scallions', 'leek', 'asparagus', 'corn', 'pea', 'peas', 'bean', 'beans', 'edamame', 'beet', 'radish', 'fennel', 'artichoke', 'eggplant', 'fresh fruit', 'fresh vegetable']),
  _Section('meat', 'Meat & Seafood', '🥩', ['chicken', 'beef', 'pork', 'lamb', 'turkey', 'duck', 'steak', 'ground beef', 'ground turkey', 'ground pork', 'bacon', 'sausage', 'ham', 'prosciutto', 'salami', 'pepperoni', 'chorizo', 'brisket', 'ribs', 'chops', 'breast', 'thigh', 'drumstick', 'wing', 'loin', 'tenderloin', 'roast', 'salmon', 'tuna', 'shrimp', 'crab', 'lobster', 'scallop', 'clam', 'mussel', 'oyster', 'cod', 'tilapia', 'halibut', 'mahi', 'sea bass', 'snapper', 'trout', 'anchovy', 'sardine', 'fish', 'seafood', 'meat']),
  _Section('dairy', 'Dairy & Eggs', '🥛', ['milk', 'cream', 'heavy cream', 'half and half', 'butter', 'ghee', 'cheese', 'cheddar', 'mozzarella', 'parmesan', 'brie', 'feta', 'gouda', 'ricotta', 'cream cheese', 'cottage cheese', 'sour cream', 'yogurt', 'kefir', 'egg', 'eggs', 'egg whites', 'whipping cream', 'ice cream', 'gelato', 'pudding', 'custard']),
  _Section('deli', 'Deli', '🥪', ['deli', 'sliced turkey', 'sliced ham', 'sliced chicken', 'roast beef', 'pastrami', 'liverwurst', 'hummus', 'pesto', 'prepared salad', 'coleslaw', 'rotisserie']),
  _Section('bakery', 'Bakery & Bread', '🍞', ['bread', 'loaf', 'baguette', 'roll', 'rolls', 'bun', 'buns', 'bagel', 'bagels', 'croissant', 'muffin', 'muffins', 'cake', 'pie', 'pastry', 'donut', 'danish', 'pita', 'tortilla', 'wrap', 'naan', 'sourdough', 'rye', 'brioche', 'ciabatta', 'focaccia']),
  _Section('frozen', 'Frozen', '🧊', ['frozen', 'ice cream', 'frozen pizza', 'frozen vegetable', 'frozen fruit', 'frozen meal', 'frozen dinner', 'popsicle', 'sorbet', 'frozen waffle', 'frozen fries']),
  _Section('canned', 'Canned & Jarred', '🥫', ['canned', 'can of', 'tomato sauce', 'tomato paste', 'crushed tomatoes', 'diced tomatoes', 'whole tomatoes', 'coconut milk', 'chicken broth', 'beef broth', 'vegetable broth', 'stock', 'soup', 'beans', 'chickpeas', 'lentils', 'corn', 'pumpkin puree', 'artichoke hearts', 'roasted peppers', 'olives', 'capers', 'anchovies', 'tuna', 'sardines', 'pickles', 'relish', 'salsa', 'jam', 'jelly', 'preserves', 'marmalade', 'nut butter', 'peanut butter', 'almond butter', 'tahini']),
  _Section('dry', 'Dry Goods & Pasta', '🍝', ['pasta', 'spaghetti', 'penne', 'rigatoni', 'fettuccine', 'linguine', 'farfalle', 'orzo', 'lasagna', 'noodle', 'noodles', 'ramen', 'rice', 'quinoa', 'couscous', 'farro', 'barley', 'lentil', 'lentils', 'split peas', 'dried beans', 'flour', 'bread flour', 'all purpose flour', 'whole wheat flour', 'almond flour', 'cornstarch', 'cornmeal', 'oat', 'oats', 'oatmeal', 'granola', 'cereal', 'crackers', 'breadcrumbs', 'panko', 'nutritional yeast']),
  _Section('breakfast', 'Breakfast', '🥞', ['waffle mix', 'pancake mix', 'syrup', 'maple syrup', 'honey', 'jam', 'breakfast cereal', 'granola bar', 'pop tart', 'instant oatmeal']),
  _Section('condiments', 'Condiments & Sauces', '🫙', ['ketchup', 'mustard', 'mayonnaise', 'mayo', 'hot sauce', 'sriracha', 'tabasco', 'soy sauce', 'tamari', 'worcestershire', 'fish sauce', 'oyster sauce', 'hoisin', 'teriyaki', 'barbecue', 'bbq sauce', 'ranch', 'caesar', 'vinaigrette', 'dressing', 'aioli', 'chimichurri', 'tahini', 'miso', 'vinegar', 'apple cider vinegar', 'balsamic', 'rice vinegar', 'white wine vinegar', 'red wine vinegar', 'oil', 'olive oil', 'vegetable oil', 'canola oil', 'sesame oil', 'coconut oil']),
  _Section('spices', 'Spices & Baking', '🧂', ['salt', 'pepper', 'black pepper', 'white pepper', 'cumin', 'coriander', 'paprika', 'smoked paprika', 'chili powder', 'cayenne', 'turmeric', 'curry powder', 'garam masala', 'cinnamon', 'nutmeg', 'cloves', 'allspice', 'cardamom', 'star anise', 'bay leaf', 'bay leaves', 'oregano', 'thyme', 'rosemary', 'sage', 'marjoram', 'tarragon', 'dill', 'fennel seed', 'caraway', 'celery seed', 'mustard seed', 'poppy seed', 'sesame seed', 'red pepper flakes', 'garlic powder', 'onion powder', 'sugar', 'brown sugar', 'powdered sugar', 'baking powder', 'baking soda', 'yeast', 'vanilla', 'cocoa', 'chocolate', 'sprinkles']),
  _Section('beverages', 'Beverages', '🥤', ['water', 'sparkling water', 'soda', 'juice', 'coffee', 'tea', 'milk', 'almond milk', 'oat milk', 'soy milk', 'coconut water', 'sports drink', 'energy drink', 'beer', 'wine', 'champagne', 'cider', 'kombucha', 'lemonade']),
  _Section('household', 'Household', '🧻', ['paper towel', 'toilet paper', 'tissue', 'napkin', 'plastic bag', 'ziplock', 'foil', 'aluminum foil', 'parchment', 'wax paper', 'plastic wrap', 'trash bag', 'dish soap', 'dishwasher', 'laundry', 'detergent', 'bleach', 'cleaner', 'sponge', 'scrubber', 'toothpaste', 'shampoo', 'conditioner', 'soap', 'lotion']),
];

const _quickItems = [
  'Milk', 'Eggs', 'Butter', 'Bread', 'Bananas', 'Onions', 'Garlic',
  'Olive Oil', 'Salt', 'Pepper', 'Chicken', 'Rice', 'Pasta', 'Tomatoes', 'Cheese', 'Coffee',
];

class _Section {
  final String key;
  final String label;
  final String icon;
  final List<String> keywords;
  const _Section(this.key, this.label, this.icon, this.keywords);
}

String _categorize(String name) {
  final lower = name.toLowerCase();
  for (final s in _sections) {
    for (final kw in s.keywords) {
      if (lower.contains(kw)) return s.key;
    }
  }
  return 'other';
}

// Simple input parser: "350g flour" / "2 cups milk" / "1/2 tsp salt"
const _units = ['cup', 'cups', 'tbsp', 'tsp', 'oz', 'lb', 'lbs', 'g', 'kg', 'ml', 'l', 'liter', 'liters', 'pinch', 'dash', 'bunch', 'clove', 'cloves', 'slice', 'slices', 'piece', 'pieces', 'can', 'jar', 'bottle', 'bag', 'box', 'head', 'stalk', 'stalks'];

Map<String, String> _parseInput(String raw) {
  // Match leading number (fraction or decimal) optionally attached to a unit
  final attachedRe = RegExp(r'^([\d\/\.\s]+)\s*(' + _units.join('|') + r')s?\s+(.+)$', caseSensitive: false);
  final match = attachedRe.firstMatch(raw.trim());
  if (match != null) {
    return {'name': match.group(3)!.trim(), 'quantity': match.group(1)!.trim(), 'unit': match.group(2)!.trim()};
  }
  // Match leading number only
  final numRe = RegExp(r'^([\d\/\.]+)\s+(.+)$');
  final m2 = numRe.firstMatch(raw.trim());
  if (m2 != null) {
    return {'name': m2.group(2)!.trim(), 'quantity': m2.group(1)!.trim(), 'unit': ''};
  }
  return {'name': raw.trim(), 'quantity': '', 'unit': ''};
}

class GroceryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const GroceryScreen({super.key, required this.user});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  Map<String, dynamic>? _list;
  bool _loading = true;
  final _inputCtrl = TextEditingController();
  bool _adding = false;
  int _nextIdx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.user['id'] ?? widget.user['_id'];
    var list = await Store.i.getGroceryList(uid);
    if (list == null) {
      list = await Store.i.createGroceryList({'name': 'My List', 'user_id': uid, 'items': []});
    }
    setState(() {
      _list = list;
      _loading = false;
      for (final item in (_list?['items'] as List? ?? [])) {
        final m = item as Map;
        m['_idx'] ??= _nextIdx++;
      }
    });
  }

  List<Map<String, dynamic>> get _items =>
      (_list?['items'] as List? ?? []).cast<Map<String, dynamic>>();

  Future<void> _addItem([String? nameOverride]) async {
    if (_list == null || _adding) return;
    final String name;
    final String quantity;
    final String unit;
    if (nameOverride != null) {
      name = nameOverride;
      quantity = '';
      unit = '';
    } else {
      final raw = _inputCtrl.text.trim();
      if (raw.isEmpty) return;
      final parsed = _parseInput(raw);
      name = parsed['name']!;
      quantity = parsed['quantity']!;
      unit = parsed['unit']!;
    }
    setState(() => _adding = true);
    final category = _categorize(name);
    await Store.i.addGroceryItem(_list!['_id'], {
      'name': name, 'quantity': quantity, 'unit': unit, 'category': category, 'checked': false,
    });
    setState(() {
      (_list!['items'] as List).add({'name': name, 'quantity': quantity, 'unit': unit, 'category': category, 'checked': false, '_idx': _nextIdx++});
      if (nameOverride == null) _inputCtrl.clear();
      _adding = false;
    });
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    final name = item['name'] as String;
    setState(() => item['checked'] = !(item['checked'] as bool? ?? false));
    await Store.i.toggleGroceryItem(_list!['_id'], name);
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final name = item['name'] as String;
    final idx = item['_idx'];
    setState(() => (_list!['items'] as List).removeWhere((e) => (e as Map)['_idx'] == idx));
    await Store.i.removeGroceryItem(_list!['_id'], name);
  }

  Future<void> _clearChecked() async {
    final checked = _items.where((i) => i['checked'] == true).toList();
    setState(() => (_list!['items'] as List).removeWhere((i) => i['checked'] == true));
    for (final item in checked) {
      await Store.i.removeGroceryItem(_list!['_id'], item['name'] as String);
    }
  }

  Future<void> _generateFromMealPlan() async {
    final uid = widget.user['id'] ?? widget.user['_id'];
    // Build this week's date range (Sun–Sat)
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

    // Collect recipes from all planned days this week
    final recipes = <Recipe>[];
    for (var i = 0; i < 7; i++) {
      final date = fmt(weekStart.add(Duration(days: i)));
      final meals = await Store.i.getDayMeals(uid, date);
      for (final meal in meals) {
        // getDayMeals returns merged map with recipe fields
        try { recipes.add(Recipe.fromJson(meal)); } catch (_) {}
      }
    }

    if (recipes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No meals planned this week'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // Deduplicate ingredients across all recipes, then show picker
    if (!mounted) return;
    await showMealPlanGrocerySheet(
      context,
      recipes: recipes,
      user: widget.user,
      weekLabel: '${_monthName(weekStart.month)} ${weekStart.day}–${weekEnd.day}',
      onAdded: _load,
    );
  }

  String _monthName(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

  List<String> get _quickSuggestions {
    final existing = _items.map((i) => (i['name'] as String).toLowerCase()).toSet();
    return _quickItems.where((q) => !existing.contains(q.toLowerCase())).take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    final checked = _items.where((i) => i['checked'] == true).toList();
    final unchecked = _items.where((i) => i['checked'] != true).toList();

    // Group unchecked items by section
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in unchecked) {
      final cat = item['category'] as String? ?? _categorize(item['name'] as String);
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    // Build section list in aisle order
    final orderedSections = <({_Section section, List<Map<String, dynamic>> items})>[];
    for (final s in _sections) {
      if (grouped.containsKey(s.key)) {
        orderedSections.add((section: s, items: grouped[s.key]!));
      }
    }
    if (grouped.containsKey('other') && grouped['other']!.isNotEmpty) {
      orderedSections.add((
        section: const _Section('other', 'Other', '🛒', []),
        items: grouped['other']!,
      ));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(checked),
            _buildAddBar(),
            if (!_loading && _quickSuggestions.isNotEmpty) _buildQuickAdd(),
            const SizedBox(height: 4),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFE8622A))))
            else if (_items.isEmpty)
              _buildEmpty()
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    ...orderedSections.map((e) => _buildSection(e.section, e.items)),
                    if (checked.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildCheckedSection(checked),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<Map<String, dynamic>> checked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text('Grocery List', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          GestureDetector(
            onTap: _generateFromMealPlan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E2DC)),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF888480)),
                  SizedBox(width: 5),
                  Text('This week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888480))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E2DC)),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('${checked.length}/${_items.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888480))),
            ),
          if (checked.isNotEmpty) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: _clearChecked,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE8622A), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              child: Text('Clear ${checked.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              onSubmitted: (_) => _addItem(),
              decoration: InputDecoration(
                hintText: 'Add item — try "2 cups flour"',
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _adding ? null : () => _addItem(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8622A),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _adding
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAdd() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final name = _quickSuggestions[i];
          return GestureDetector(
            onTap: () => _addItem(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E2DC), width: 1.5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+ ', style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w700)),
                  Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666360))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(_Section section, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(children: [
          Text(section.icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(section.label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888480), letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: const Color(0xFFE5E2DC))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6F3),
              border: Border.all(color: const Color(0xFFE5E2DC)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('${items.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF888480))),
          ),
        ]),
        const SizedBox(height: 6),
        ...items.map((item) => _GroceryItemTile(item: item, onToggle: () => _toggle(item), onRemove: () => _remove(item))),
      ],
    );
  }

  Widget _buildCheckedSection(List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('IN CART', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2D9D5C), letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: const Color(0xFFE5E2DC))),
        ]),
        const SizedBox(height: 6),
        ...items.map((item) => _GroceryItemTile(item: item, onToggle: () => _toggle(item), onRemove: () => _remove(item))),
      ],
    );
  }

  Widget _buildEmpty() {
    return Expanded(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('Your list is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Add items above to get started.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ]),
      ),
    );
  }
}

class _GroceryItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _GroceryItemTile({required this.item, required this.onToggle, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final checked = item['checked'] == true;
    final qty = item['quantity'] as String? ?? '';
    final unit = item['unit'] as String? ?? '';
    final qtyLabel = [qty, unit].where((s) => s.isNotEmpty).join(' ');

    return Dismissible(
      key: ValueKey(item['_idx'] ?? item['name']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E2DC)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: checked ? const Color(0xFF2D9D5C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: checked ? const Color(0xFF2D9D5C) : const Color(0xFFCCC9C3), width: 2),
                ),
                child: checked ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['name'] as String,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: checked ? const Color(0xFF888480) : const Color(0xFF1A1918),
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: const Color(0xFF888480),
                  ),
                ),
              ),
              if (qtyLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F6F3),
                    border: Border.all(color: const Color(0xFFE5E2DC)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(qtyLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF888480))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
