import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../storage/storage.dart';
import '../services/pantry_service.dart';
import 'add_to_grocery_sheet.dart';

// ── Ingredient key normalization ─────────────────────────────────────────────
final _prepPrefixRe = RegExp(
  r'^(fresh(ly)?\s+|fine(ly)?\s+|thin(ly)?\s+|coarse(ly)?\s+|rough(ly)?\s+|light(ly)?\s+)',
  caseSensitive: false,
);

String _normalizeIngKey(String raw) {
  var s = raw.toLowerCase().trim();
  final commaIdx = s.indexOf(',');
  if (commaIdx > 0) s = s.substring(0, commaIdx).trim();
  s = s.replaceFirst(_prepPrefixRe, '').trim();
  if (s.endsWith('ies') && s.length > 4) {
    s = '${s.substring(0, s.length - 3)}y';
  } else if (s.endsWith('oes') && s.length > 4) {
    s = s.substring(0, s.length - 2);
  } else if (s.endsWith('s') && !s.endsWith('ss') && s.length > 3) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

// ── Store sections in aisle order ────────────────────────────────────────────
const _sections = [
  _Section('produce', 'Produce', '🥦', [
    'strawberry', 'blueberry', 'raspberry', 'blackberry', 'cranberry',
    'bell pepper', 'red pepper', 'green pepper', 'yellow pepper', 'orange pepper',
    'jalapeño pepper', 'cherry tomato', 'grape tomato', 'roma tomato',
    'butternut squash', 'acorn squash', 'brussels sprout', 'sweet potato',
    'green onion', 'red onion', 'sweet onion', 'fresh ginger', 'fresh garlic',
    'button mushroom', 'shiitake', 'cremini', 'portobello', 'oyster mushroom',
    'fresh herb', 'fresh thyme', 'fresh rosemary', 'fresh basil', 'fresh parsley',
    'fresh cilantro', 'fresh mint', 'fresh dill',
    'apple', 'banana', 'orange', 'lemon', 'lime', 'grapefruit',
    'grape', 'mango', 'peach', 'pear', 'plum', 'cherry', 'avocado', 'kiwi', 'fig',
    'melon', 'watermelon', 'cantaloupe', 'pomegranate', 'papaya', 'plantain',
    'cucumber', 'zucchini', 'squash', 'tomato', 'lettuce', 'romaine', 'arugula',
    'spinach', 'kale', 'chard', 'cabbage', 'bok choy', 'broccoli', 'cauliflower',
    'carrot', 'celery', 'fennel', 'leek', 'asparagus', 'artichoke', 'eggplant',
    'scallion', 'shallot', 'onion', 'garlic', 'ginger', 'potato',
    'mushroom', 'corn', 'pea', 'edamame', 'beet', 'radish', 'turnip', 'parsnip',
    'cilantro', 'parsley', 'basil', 'thyme', 'rosemary', 'mint', 'dill', 'chive', 'sage',
    'pepper', 'jalapeño', 'serrano', 'habanero',
    'berry', 'berries', 'herb', 'fresh fruit', 'fresh vegetable',
  ]),
  _Section('meat', 'Meat & Seafood', '🥩', [
    'ground beef', 'ground turkey', 'ground pork', 'ground chicken', 'ground lamb',
    'chicken breast', 'chicken thigh', 'chicken drumstick', 'chicken wing', 'whole chicken',
    'beef steak', 'ribeye', 'sirloin', 'filet mignon', 'flank steak', 'skirt steak',
    'pork belly', 'pork shoulder', 'pork loin', 'pork chop', 'baby back ribs', 'short rib',
    'italian sausage', 'breakfast sausage', 'andouille', 'kielbasa', 'bratwurst',
    'smoked salmon', 'salmon fillet', 'mahi mahi', 'sea bass', 'halibut fillet',
    'shrimp', 'prawn', 'crab', 'lobster', 'scallop', 'clam', 'mussel', 'oyster', 'calamari',
    'chicken', 'beef', 'pork', 'lamb', 'turkey', 'duck', 'steak', 'brisket',
    'bacon', 'pancetta', 'prosciutto', 'salami', 'pepperoni', 'chorizo', 'ham',
    'salmon', 'tuna', 'cod', 'tilapia', 'trout', 'anchovy', 'sardine', 'fish', 'seafood', 'meat',
    'veal', 'venison', 'bison', 'roast',
  ]),
  _Section('dairy', 'Dairy & Eggs', '🥛', [
    'heavy cream', 'heavy whipping cream', 'whipping cream', 'half and half',
    'cream cheese', 'sour cream', 'cottage cheese',
    'cheddar', 'mozzarella', 'parmesan', 'brie', 'feta', 'gouda', 'ricotta',
    'gruyere', 'provolone', 'swiss cheese',
    'milk', 'cream', 'butter', 'ghee', 'cheese', 'yogurt', 'kefir',
    'egg', 'ice cream', 'gelato',
  ]),
  _Section('deli', 'Deli', '🥪', [
    'sliced turkey', 'sliced ham', 'sliced chicken', 'deli turkey', 'deli ham',
    'roast beef', 'pastrami', 'prepared salad', 'coleslaw',
    'hummus', 'tzatziki', 'baba ganoush', 'rotisserie', 'deli',
  ]),
  _Section('bakery', 'Bakery & Bread', '🍞', [
    'sourdough bread', 'whole wheat bread', 'white bread', 'rye bread',
    'hot dog bun', 'hamburger bun', 'pita bread', 'naan bread', 'english muffin',
    'bread', 'loaf', 'baguette', 'roll', 'bun', 'bagel', 'croissant', 'muffin',
    'cake', 'pastry', 'donut', 'danish', 'pita', 'tortilla', 'wrap',
    'naan', 'sourdough', 'rye', 'brioche', 'ciabatta', 'focaccia',
  ]),
  _Section('frozen', 'Frozen', '🧊', [
    'frozen pizza', 'frozen vegetable', 'frozen fruit', 'frozen meal',
    'frozen waffle', 'frozen fries', 'frozen edamame', 'frozen corn', 'frozen peas',
    'frozen', 'popsicle', 'sorbet',
  ]),
  _Section('canned', 'Canned & Jarred', '🥫', [
    'crushed tomatoes', 'diced tomatoes', 'whole tomatoes', 'fire roasted tomatoes',
    'tomato sauce', 'tomato paste', 'marinara sauce', 'pasta sauce',
    'chicken broth', 'beef broth', 'vegetable broth', 'chicken stock', 'beef stock',
    'coconut milk', 'coconut cream',
    'black beans', 'kidney beans', 'white beans', 'chickpeas', 'garbanzo beans', 'pinto beans',
    'artichoke hearts', 'roasted red peppers', 'sun-dried tomatoes',
    'canned tuna', 'canned salmon', 'pumpkin puree',
    'peanut butter', 'almond butter', 'cashew butter', 'tahini', 'nut butter',
    'pickles', 'relish', 'salsa', 'jam', 'jelly', 'preserves', 'marmalade',
    'olives', 'capers', 'anchovies', 'soup', 'broth', 'stock',
    'canned', 'can of', 'lentils', 'beans',
  ]),
  _Section('dry', 'Dry Goods & Pasta', '🍝', [
    'spaghetti', 'penne', 'rigatoni', 'fettuccine', 'linguine', 'farfalle', 'fusilli', 'rotini',
    'orzo', 'lasagna noodle', 'egg noodle', 'ramen noodle', 'udon noodle', 'rice noodle',
    'all purpose flour', 'bread flour', 'whole wheat flour', 'almond flour', 'coconut flour',
    'brown rice', 'white rice', 'jasmine rice', 'basmati rice', 'arborio rice', 'wild rice',
    'rolled oats', 'steel cut oats', 'instant oatmeal',
    'pasta', 'noodle', 'rice', 'quinoa', 'couscous', 'farro', 'barley', 'bulgur',
    'flour', 'cornstarch', 'cornmeal', 'oat', 'oatmeal', 'cereal', 'granola',
    'crackers', 'breadcrumbs', 'panko', 'nutritional yeast', 'yeast',
    'dried lentil', 'split peas',
  ]),
  _Section('breakfast', 'Breakfast', '🥞', [
    'maple syrup', 'pancake syrup', 'waffle mix', 'pancake mix',
    'granola bar', 'pop tart', 'syrup', 'honey',
  ]),
  _Section('condiments', 'Condiments & Sauces', '🫙', [
    'apple cider vinegar', 'balsamic vinegar', 'red wine vinegar', 'white wine vinegar', 'rice wine vinegar',
    'extra virgin olive oil', 'olive oil', 'vegetable oil', 'canola oil', 'sesame oil',
    'coconut oil', 'avocado oil',
    'soy sauce', 'tamari', 'coconut aminos',
    'worcestershire sauce', 'fish sauce', 'oyster sauce', 'hoisin sauce', 'teriyaki sauce',
    'hot sauce', 'sriracha', 'tabasco',
    'bbq sauce', 'barbecue sauce', 'ketchup', 'mustard', 'dijon mustard',
    'mayonnaise', 'aioli', 'ranch dressing', 'caesar dressing', 'vinaigrette', 'salad dressing',
    'balsamic glaze', 'gochujang', 'miso paste', 'curry paste',
    'vanilla extract', 'almond extract',
    'vinegar', 'oil', 'sauce', 'dressing', 'ketchup', 'mayo', 'miso',
  ]),
  _Section('spices', 'Spices & Baking', '🧂', [
    'red pepper flakes', 'crushed red pepper',
    'smoked paprika', 'sweet paprika', 'garlic powder', 'onion powder',
    'black pepper', 'white pepper', 'chili powder', 'chipotle powder',
    'curry powder', 'garam masala', 'chinese five spice',
    'ground cinnamon', 'ground cumin', 'ground coriander', 'ground cardamom', 'ground ginger',
    'ground nutmeg', 'ground cloves', 'ground turmeric',
    'dried oregano', 'dried thyme', 'dried rosemary', 'dried basil', 'dried sage', 'dried dill',
    'bay leaf', 'bay leaves', 'fennel seed', 'celery seed', 'mustard seed', 'sesame seed',
    'star anise', 'baking powder', 'baking soda', 'cream of tartar',
    'powdered sugar', 'confectioners sugar', 'brown sugar', 'granulated sugar', 'cane sugar',
    'cocoa powder', 'dark chocolate', 'chocolate chip', 'white chocolate',
    'kosher salt', 'sea salt', 'fleur de sel',
    'salt', 'pepper', 'paprika', 'cumin', 'coriander', 'turmeric', 'cinnamon',
    'nutmeg', 'cloves', 'allspice', 'cardamom', 'cayenne', 'oregano',
    'sugar', 'vanilla', 'cocoa', 'chocolate', 'sprinkles',
  ]),
  _Section('beverages', 'Beverages', '🥤', [
    'sparkling water', 'mineral water', 'tonic water', 'club soda', 'seltzer',
    'orange juice', 'apple juice', 'cranberry juice',
    'almond milk', 'oat milk', 'soy milk', 'coconut water', 'rice milk',
    'cold brew', 'iced coffee', 'iced tea',
    'white wine', 'red wine', 'prosecco', 'champagne', 'hard cider',
    'kombucha', 'lemonade', 'sports drink', 'energy drink',
    'water', 'juice', 'coffee', 'tea', 'soda', 'beer', 'wine',
  ]),
  _Section('household', 'Household', '🧻', [
    'paper towel', 'toilet paper', 'facial tissue',
    'ziplock bag', 'freezer bag', 'storage bag',
    'aluminum foil', 'parchment paper', 'plastic wrap',
    'trash bag', 'garbage bag', 'dish soap', 'dish detergent', 'dishwasher detergent',
    'laundry detergent', 'fabric softener',
    'foil', 'parchment', 'sponge', 'bleach', 'cleaner',
    'toothpaste', 'shampoo', 'conditioner', 'body wash', 'lotion', 'soap',
  ]),
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

// Longest-match-wins categorization
String _categorize(String name) {
  final lower = name.toLowerCase().trim();
  String bestKey = 'other';
  int bestLen = 0;
  for (final s in _sections) {
    for (final kw in s.keywords) {
      if (kw.length > bestLen && lower.contains(kw)) {
        bestKey = s.key;
        bestLen = kw.length;
      }
    }
  }
  return bestKey;
}

// Simple input parser: "350g flour" / "2 cups milk" / "1/2 tsp salt"
const _units = ['cup', 'cups', 'tbsp', 'tsp', 'oz', 'lb', 'lbs', 'g', 'kg', 'ml', 'l', 'liter', 'liters', 'pinch', 'dash', 'bunch', 'clove', 'cloves', 'slice', 'slices', 'piece', 'pieces', 'can', 'jar', 'bottle', 'bag', 'box', 'head', 'stalk', 'stalks'];

Map<String, String> _parseInput(String raw) {
  final attachedRe = RegExp(r'^([\d\/\.\s]+)\s*(' + _units.join('|') + r')s?\s+(.+)$', caseSensitive: false);
  final match = attachedRe.firstMatch(raw.trim());
  if (match != null) {
    return {'name': match.group(3)!.trim(), 'quantity': match.group(1)!.trim(), 'unit': match.group(2)!.trim()};
  }
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
  final _focusNode = FocusNode();
  bool _adding = false;
  int _nextIdx = 0;
  Map<String, String> _catOverrides = {}; // normalizeIngKey(name) → category key

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _catOverridesKey() {
    final uid = widget.user['id'] ?? widget.user['_id'] ?? '';
    return 'mise_cat_overrides_$uid';
  }

  Future<void> _load() async {
    final uid = widget.user['id'] ?? widget.user['_id'];
    var list = await Store.i.getGroceryList(uid);
    if (list == null) {
      list = await Store.i.createGroceryList({'name': 'My List', 'user_id': uid, 'items': []});
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catOverridesKey()) ?? '{}';
    Map<String, String> overrides = {};
    try {
      overrides = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    } catch (_) {}

    setState(() {
      _list = list;
      _loading = false;
      _catOverrides = overrides;
      for (final item in (_list?['items'] as List? ?? [])) {
        final m = item as Map;
        m['_idx'] ??= _nextIdx++;
      }
    });
  }

  Future<void> _saveCatOverride(String itemName, String category) async {
    final key = _normalizeIngKey(itemName);
    setState(() => _catOverrides[key] = category);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_catOverridesKey(), jsonEncode(_catOverrides));
  }

  String _effectiveCategory(String itemName, String? storedCat) {
    final key = _normalizeIngKey(itemName);
    return _catOverrides[key] ?? storedCat ?? _categorize(itemName);
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
    final category = _effectiveCategory(name, null);
    await Store.i.addGroceryItem(_list!['_id'], {
      'name': name, 'quantity': quantity, 'unit': unit, 'category': category, 'checked': false,
    });
    setState(() {
      (_list!['items'] as List).add({
        'name': name, 'quantity': quantity, 'unit': unit,
        'category': category, 'checked': false, '_idx': _nextIdx++,
      });
      if (nameOverride == null) _inputCtrl.clear();
      _adding = false;
    });
    // Keep keyboard open after submission
    if (nameOverride == null) {
      Future.microtask(() => _focusNode.requestFocus());
    }
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    final name = item['name'] as String;
    final prev = item['checked'] as bool? ?? false;
    setState(() => item['checked'] = !prev);
    try {
      await Store.i.toggleGroceryItem(_list!['_id'], name);
    } catch (_) {
      if (mounted) setState(() => item['checked'] = prev);
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final name = item['name'] as String;
    final idx = item['_idx'];
    setState(() => (_list!['items'] as List).removeWhere((e) => (e as Map)['_idx'] == idx));
    try {
      await Store.i.removeGroceryItem(_list!['_id'], name);
    } catch (_) {
      _load();
    }
  }

  Future<void> _clearChecked() async {
    if (_items.where((i) => i['checked'] == true).isEmpty) return;
    setState(() => (_list!['items'] as List).removeWhere((i) => (i as Map)['checked'] == true));
    try {
      await Store.i.clearGroceryItems(_list!['_id'], checkedOnly: true);
    } catch (_) {
      _load();
    }
  }

  Future<void> _clearAll() async {
    if (_items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all items?'),
        content: const Text('This will remove everything from your grocery list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => (_list!['items'] as List).clear());
    try {
      await Store.i.clearGroceryItems(_list!['_id']);
    } catch (_) {
      _load();
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final nameCtrl = TextEditingController(text: item['name'] as String? ?? '');
    final qtyCtrl = TextEditingController(text: item['quantity'] as String? ?? '');
    final unitCtrl = TextEditingController(text: item['unit'] as String? ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit item', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
            )),
          ]),
          const SizedBox(height: 8),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE8622A)),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newName = nameCtrl.text.trim();
    if (newName.isEmpty) return;
    final oldName = item['name'] as String;
    final newQty = qtyCtrl.text.trim();
    final newUnit = unitCtrl.text.trim();

    setState(() {
      item['name'] = newName;
      item['quantity'] = newQty;
      item['unit'] = newUnit;
    });
    if (newName != oldName) {
      await Store.i.removeGroceryItem(_list!['_id'], oldName);
    }
    await Store.i.addGroceryItem(_list!['_id'], {
      'name': newName, 'quantity': newQty, 'unit': newUnit,
      'category': _effectiveCategory(newName, item['category'] as String?),
      'checked': item['checked'] ?? false,
    });
  }

  void _showItemOptions(Map<String, dynamic> item) {
    final effectiveCat = _effectiveCategory(item['name'] as String, item['category'] as String?);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemOptionsSheet(
        item: item,
        effectiveCategory: effectiveCat,
        onEdit: () => _editItem(item),
        onCategoryChange: (cat) => _saveCatOverride(item['name'] as String, cat),
        onRemove: () => _remove(item),
      ),
    );
  }

  Future<void> _generateFromMealPlan() async {
    final uid = widget.user['id'] ?? widget.user['_id'];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final recipes = <Recipe>[];
    for (var i = 0; i < 7; i++) {
      final date = fmt(weekStart.add(Duration(days: i)));
      final meals = await Store.i.getDayMeals(uid, date);
      for (final meal in meals) {
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

    if (!mounted) return;
    await showMealPlanGrocerySheet(
      context,
      recipes: recipes,
      user: widget.user,
      weekLabel: '${_monthName(weekStart.month)} ${weekStart.day}–${weekEnd.day}',
      onAdded: _load,
    );
  }

  String _monthName(int m) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  List<String> get _quickSuggestions {
    final existingKeys = _items.map((i) => _normalizeIngKey(i['name'] as String)).toSet();
    return _quickItems.where((q) => !existingKeys.contains(_normalizeIngKey(q))).take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    final checked = _items.where((i) => i['checked'] == true).toList();
    final unchecked = _items.where((i) => i['checked'] != true).toList();

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in unchecked) {
      final cat = _effectiveCategory(item['name'] as String, item['category'] as String?);
      grouped.putIfAbsent(cat, () => []).add(item);
    }

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
            const SizedBox(width: 8),
            TextButton(
              onPressed: _clearChecked,
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE8622A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              child: Text('Clear ${checked.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
          if (_items.isNotEmpty) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Color(0xFF888480), size: 20),
              padding: EdgeInsets.zero,
              onSelected: (v) {
                if (v == 'clear_all') _clearAll();
                if (v == 'clear_checked' && checked.isNotEmpty) _clearChecked();
              },
              itemBuilder: (_) => [
                if (checked.isNotEmpty)
                  const PopupMenuItem(value: 'clear_checked', child: Text('Clear checked')),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all', style: TextStyle(color: Colors.red)),
                ),
              ],
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
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addItem(),
              textCapitalization: TextCapitalization.sentences,
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
        ...items.map((item) => _GroceryItemTile(
          item: item,
          onToggle: () => _toggle(item),
          onRemove: () => _remove(item),
          onLongPress: () => _showItemOptions(item),
        )),
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
        ...items.map((item) => _GroceryItemTile(
          item: item,
          onToggle: () => _toggle(item),
          onRemove: () => _remove(item),
          onLongPress: () => _showItemOptions(item),
        )),
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

// ── Grocery item tile ─────────────────────────────────────────────────────────
class _GroceryItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onLongPress;

  const _GroceryItemTile({
    required this.item,
    required this.onToggle,
    required this.onRemove,
    required this.onLongPress,
  });

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
        onLongPress: onLongPress,
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

// ── Item options bottom sheet ─────────────────────────────────────────────────
class _ItemOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final String effectiveCategory;
  final VoidCallback onEdit;
  final void Function(String) onCategoryChange;
  final VoidCallback onRemove;

  const _ItemOptionsSheet({
    required this.item,
    required this.effectiveCategory,
    required this.onEdit,
    required this.onCategoryChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final allCategories = [
      ..._sections,
      const _Section('other', 'Other', '🛒', []),
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
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
            child: Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDDDAD5), borderRadius: BorderRadius.circular(99)),
            )),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name
                  Text(item['name'] as String,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 16),

                  // Edit button
                  GestureDetector(
                    onTap: () { Navigator.pop(context); onEdit(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E2DC)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(children: [
                        Icon(Icons.edit_outlined, size: 16, color: Color(0xFF888480)),
                        SizedBox(width: 10),
                        Text('Edit item', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Move to category
                  const Text('MOVE TO', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Color(0xFF888480), letterSpacing: 0.8,
                  )),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allCategories.map((s) {
                      final isCurrent = effectiveCategory == s.key;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onCategoryChange(s.key);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFFE8622A).withOpacity(0.1)
                                : Colors.white,
                            border: Border.all(
                              color: isCurrent ? const Color(0xFFE8622A) : const Color(0xFFE5E2DC),
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(s.icon, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(s.label,
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: isCurrent ? const Color(0xFFE8622A) : const Color(0xFF555250),
                              )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Delete
                  GestureDetector(
                    onTap: () { Navigator.pop(context); onRemove(); },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Delete item', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
