import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../storage/storage.dart';
import '../models/recipe.dart';
import '../services/planner_prefs.dart';

class PlannerScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PlannerScreen({super.key, required this.user});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _weekStart;
  List<Map<String, dynamic>> _dayMeals = [];
  Map<String, List<Map<String, dynamic>>> _weekMeals = {};
  List<Recipe> _allRecipes = [];
  bool _loadingMeals = false;
  bool _loadingRecipes = true;
  bool _weekView = false;
  int _weekStartDay = 0; // 0=Sun, 1=Mon
  String? _addingId;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _loadRecipes();
  }

  Future<void> _initPrefs() async {
    final weekView = await PlannerPrefs.isWeekView();
    final weekStart = await PlannerPrefs.weekStart();
    setState(() {
      _weekView = weekView;
      _weekStartDay = weekStart;
      _weekStart = _calcWeekStart(DateTime.now(), weekStart);
    });
    if (_weekView) {
      _loadWeekMeals();
    } else {
      _loadDayMeals();
    }
  }

  static DateTime _calcWeekStart(DateTime d, int startDay) {
    // startDay: 0=Sun, 1=Mon
    final dayOfWeek = startDay == 1
        ? (d.weekday % 7)   // Mon=0..Sun=6 from Monday
        : d.weekday % 7;    // Sun=0..Sat=6 from Sunday
    final start = d.subtract(Duration(days: dayOfWeek));
    return DateTime(start.year, start.month, start.day);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _uid => widget.user['id'] ?? widget.user['_id'];

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> _loadRecipes() async {
    try {
      final list = await Store.i.getRecipes(_uid);
      setState(() { _allRecipes = list.map((j) => Recipe.fromJson(j)).toList(); _loadingRecipes = false; });
    } catch (_) {
      setState(() => _loadingRecipes = false);
    }
  }

  Future<void> _loadDayMeals() async {
    setState(() => _loadingMeals = true);
    try {
      final meals = await Store.i.getDayMeals(_uid, _fmt(_selectedDate));
      setState(() => _dayMeals = meals);
    } catch (_) {
      setState(() => _dayMeals = []);
    }
    setState(() => _loadingMeals = false);
  }

  Future<void> _loadWeekMeals() async {
    setState(() => _loadingMeals = true);
    final results = <String, List<Map<String, dynamic>>>{};
    await Future.wait(List.generate(7, (i) async {
      final date = _fmt(_weekStart.add(Duration(days: i)));
      try {
        results[date] = await Store.i.getDayMeals(_uid, date);
      } catch (_) {
        results[date] = [];
      }
    }));
    setState(() { _weekMeals = results; _loadingMeals = false; });
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _addMeal(Recipe recipe, DateTime date, {int multiplier = 1}) async {
    setState(() => _addingId = recipe.id);
    try {
      final mealData = {
        '_id': recipe.id,
        'recipe_name': recipe.name,
        'cuisine': recipe.cuisine,
        'image_url': recipe.imageUrl,
        'cook_time': recipe.cookTime,
      };
      final result = await Store.i.addMealPlan(_uid, _fmt(date), recipe.id, mealData, multiplier: multiplier);
      setState(() {
        if (_weekView) {
          _weekMeals[_fmt(date)] ??= [];
          _weekMeals[_fmt(date)]!.add(result);
        } else {
          _dayMeals.add(result);
        }
      });
    } catch (_) {}
    setState(() => _addingId = null);
  }

  Future<void> _removeMeal(String mealPlanId, DateTime date) async {
    setState(() {
      if (_weekView) {
        _weekMeals[_fmt(date)]?.removeWhere((m) => m['mealPlanId'] == mealPlanId);
      } else {
        _dayMeals.removeWhere((m) => m['mealPlanId'] == mealPlanId);
      }
    });
    await Store.i.deleteMealPlan(mealPlanId);
  }

  void _shiftWeek(int dir) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * dir));
      _selectedDate = _weekStart;
    });
    if (_weekView) _loadWeekMeals(); else _loadDayMeals();
  }

  void _selectDate(DateTime d) {
    setState(() => _selectedDate = d);
    if (!_weekView) _loadDayMeals();
  }

  void _toggleView(bool week) {
    setState(() => _weekView = week);
    PlannerPrefs.setWeekView(week);
    if (week) _loadWeekMeals(); else _loadDayMeals();
  }

  // ── Labels ──────────────────────────────────────────────────────────────────

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    final sm = _months[_weekStart.month - 1];
    final em = _months[end.month - 1];
    return '$sm ${_weekStart.day} – ${sm != em ? '$em ' : ''}${end.day}';
  }

  String _dayLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final diff = sel.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${_days[sel.weekday % 7]}, ${_months[sel.month - 1]} ${sel.day}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (!_weekView) _buildWeekStrip(),
            Expanded(child: _weekView ? _buildWeekView() : _buildDayView()),
          ],
        ),
      ),
      floatingActionButton: _weekView ? null : FloatingActionButton.extended(
        onPressed: () => _showRecipePicker(_selectedDate),
        backgroundColor: const Color(0xFFE8622A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add meal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left, () => _shiftWeek(-1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_weekLabel(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF666360))),
          ),
          _navBtn(Icons.chevron_right, () => _shiftWeek(1)),
          const SizedBox(width: 10),
          // Day / Week toggle
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewToggleBtn('Day', !_weekView),
                _viewToggleBtn('Week', _weekView),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewToggleBtn(String label, bool active) {
    return GestureDetector(
      onTap: () => _toggleView(label == 'Week'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A1918) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? Colors.white : const Color(0xFF888480),
        )),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF666360)),
      ),
    );
  }

  // ── Week strip (day view only) ───────────────────────────────────────────────

  Widget _buildWeekStrip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final day = _weekStart.add(Duration(days: i));
          final isSelected = _fmt(day) == _fmt(_selectedDate);
          final isToday = _fmt(day) == _fmt(today);
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8622A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Text(_days[day.weekday % 7],
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                      color: isSelected ? Colors.white : const Color(0xFF888480))),
                  const SizedBox(height: 4),
                  Text('${day.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : isToday ? const Color(0xFFE8622A) : Theme.of(context).colorScheme.onSurface)),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Day view ─────────────────────────────────────────────────────────────────

  Widget _buildDayView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Expanded(child: Text(_dayLabel(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3))),
            if (_dayMeals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(99)),
                child: Text('${_dayMeals.length} planned', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888480))),
              ),
          ]),
        ),
        Expanded(
          child: _loadingMeals
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8622A)))
              : _dayMeals.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('📅', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      const Text('Nothing planned', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Tap + Add meal to plan something.', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _dayMeals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _MealCard(
                        meal: _dayMeals[i],
                        onRemove: () => _removeMeal(_dayMeals[i]['mealPlanId'], _selectedDate),
                      ),
                    ),
        ),
      ],
    );
  }

  // ── Week view ────────────────────────────────────────────────────────────────

  Widget _buildWeekView() {
    if (_loadingMeals) return const Center(child: CircularProgressIndicator(color: Color(0xFFE8622A)));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: 7,
            itemBuilder: (_, i) {
              final day = _weekStart.add(Duration(days: i));
              final isToday = _fmt(day) == _fmt(today);
              final meals = _weekMeals[_fmt(day)] ?? [];
              return DragTarget<Recipe>(
                builder: (ctx, candidateData, _) => _WeekDayCard(
                  day: day, isToday: isToday, meals: meals,
                  highlighted: candidateData.isNotEmpty,
                  onAddMeal: () => _showRecipePicker(day),
                  onRemoveMeal: (id) => _removeMeal(id, day),
                  months: _months, days: _days,
                ),
                onAcceptWithDetails: (details) => _addMeal(details.data, day),
              );
            },
          ),
        ),
        _buildRecipeTray(),
      ],
    );
  }

  Widget _buildRecipeTray() {
    final ts = Theme.of(context).colorScheme.onSurface.withOpacity(0.4);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              Icon(Icons.drag_indicator, size: 13, color: ts),
              const SizedBox(width: 5),
              Text('Hold & drag to a day',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ts)),
            ]),
          ),
          SizedBox(
            height: 96,
            child: _loadingRecipes
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8622A), strokeWidth: 2))
                : _allRecipes.isEmpty
                    ? Center(child: Text('Add recipes to your library first',
                        style: TextStyle(fontSize: 12, color: ts)))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _allRecipes.length,
                        itemBuilder: (_, i) {
                          final recipe = _allRecipes[i];
                          return LongPressDraggable<Recipe>(
                            data: recipe,
                            hapticFeedbackOnStart: true,
                            delay: const Duration(milliseconds: 250),
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 72,
                                child: _RecipeTrayItem(recipe: recipe, isDragging: true),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _RecipeTrayItem(recipe: recipe),
                            ),
                            child: _RecipeTrayItem(recipe: recipe),
                          );
                        },
                      ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // ── Recipe picker ────────────────────────────────────────────────────────────

  void _showRecipePicker(DateTime date) {
    final alreadyAdded = _weekView
        ? (_weekMeals[_fmt(date)] ?? []).map((m) => m['_id'] as String? ?? '').toSet()
        : _dayMeals.map((m) => m['_id'] as String? ?? '').toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipePicker(
        recipes: _allRecipes,
        addedIds: alreadyAdded,
        addingId: _addingId,
        onAdd: (recipe, mult) { _addMeal(recipe, date, multiplier: mult); Navigator.pop(context); },
        loading: _loadingRecipes,
      ),
    );
  }
}

// ── Pastel helper ────────────────────────────────────────────────────────────
Color _mealPastel(String? cuisine) {
  const _p = {
    'italian': Color(0xFFF5EDE8), 'mexican': Color(0xFFE9F2E9),
    'japanese': Color(0xFFF2EDF4), 'chinese': Color(0xFFF5EDEC),
    'indian': Color(0xFFF5F0E8), 'american': Color(0xFFEBF0F5),
    'french': Color(0xFFEEF0F8), 'thai': Color(0xFFF3F2E7),
    'mediterranean': Color(0xFFE8F2EF), 'greek': Color(0xFFEDF0F8),
    'korean': Color(0xFFF4EDF2),
  };
  return _p[(cuisine ?? '').toLowerCase()] ?? const Color(0xFFF2F0EB);
}

// ── Week day card ─────────────────────────────────────────────────────────────

class _WeekDayCard extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool highlighted;
  final List<Map<String, dynamic>> meals;
  final VoidCallback onAddMeal;
  final void Function(String id) onRemoveMeal;
  final List<String> months;
  final List<String> days;

  const _WeekDayCard({
    required this.day, required this.isToday, this.highlighted = false,
    required this.meals, required this.onAddMeal, required this.onRemoveMeal,
    required this.months, required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted || isToday ? const Color(0xFFE8622A) : Theme.of(context).dividerColor,
          width: highlighted || isToday ? 2 : 1.5,
        ),
        boxShadow: highlighted ? [
          BoxShadow(color: const Color(0xFFE8622A).withOpacity(0.18), blurRadius: 10, spreadRadius: 1),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Text(
                  '${days[day.weekday % 7].toUpperCase()}  ${day.day} ${months[day.month - 1]}',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                    color: isToday ? const Color(0xFFE8622A) : const Color(0xFF888480),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8622A).withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                    child: const Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFE8622A))),
                  ),
                ],
                const Spacer(),
                if (meals.isNotEmpty)
                  Text('${meals.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888480))),
              ],
            ),
          ),
          if (meals.isNotEmpty) ...[
            const Divider(height: 1),
            ...meals.map((meal) => _WeekMealRow(meal: meal, onRemove: () => onRemoveMeal(meal['mealPlanId']))),
          ],
          // Add button
          InkWell(
            onTap: onAddMeal,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.add, size: 14, color: Color(0xFFE8622A)),
                const SizedBox(width: 6),
                const Text('Add meal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE8622A))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekMealRow extends StatelessWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onRemove;
  const _WeekMealRow({required this.meal, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final imageUrl = meal['image_url'] as String?;
    return Dismissible(
      key: Key(meal['mealPlanId'] as String? ?? meal['recipe_name'] as String),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.withOpacity(0.1),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36, height: 36,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(meal['recipe_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if ((meal['multiplier'] as int? ?? 1) > 1)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFE8622A), borderRadius: BorderRadius.circular(99)),
              child: Text('×${meal['multiplier']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          if ((meal['cook_time'] as int? ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('${meal['cook_time']}m', style: const TextStyle(fontSize: 11, color: Color(0xFF888480))),
            ),
        ]),
      ),
    );
  }

  Widget _placeholder() {
    final name = meal['recipe_name'] as String? ?? '';
    return Container(
      color: _mealPastel(meal['cuisine'] as String?),
      child: Center(child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0x881A1918)),
      )),
    );
  }
}

// ── Meal card (day view) ──────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onRemove;
  const _MealCard({required this.meal, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final imageUrl = meal['image_url'] as String?;
    final cookTime = meal['cook_time'];
    return Dismissible(
      key: Key(meal['mealPlanId'] as String),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60, height: 60,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: _mealPastel(meal['cuisine'] as String?),
                      child: Center(child: Text(
                        (meal['recipe_name'] as String? ?? '').isNotEmpty ? (meal['recipe_name'] as String)[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0x881A1918)),
                      )),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meal['recipe_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              if ((meal['cuisine'] as String? ?? '').isNotEmpty) _chip(meal['cuisine'], context),
              if (cookTime != null && cookTime > 0) _chip('${cookTime}m cook', context),
              if ((meal['multiplier'] as int? ?? 1) > 1) _multChip('×${meal['multiplier']}'),
            ]),
          ])),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: Color(0xFFBBB8B3)),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text, BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(99), border: Border.all(color: Theme.of(context).dividerColor)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF888480), fontWeight: FontWeight.w500)),
  );

  Widget _multChip(String text) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFFE8622A), borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800)),
  );
}

// ── Recipe picker ─────────────────────────────────────────────────────────────

class _RecipePicker extends StatefulWidget {
  final List<Recipe> recipes;
  final Set<String> addedIds;
  final String? addingId;
  final Function(Recipe, int) onAdd;
  final bool loading;
  const _RecipePicker({required this.recipes, required this.addedIds, required this.addingId, required this.onAdd, required this.loading});

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  String _search = '';
  int _multiplier = 1;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.recipes.where((r) => r.name.toLowerCase().contains(_search.toLowerCase())).toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDAD5), borderRadius: BorderRadius.circular(99))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            const Expanded(child: Text('Add to plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            // Multiplier stepper
            _MultStepper(value: _multiplier, onChanged: (v) => setState(() => _multiplier = v)),
            const SizedBox(width: 8),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Color(0xFF888480)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search recipes…',
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF888480)),
              filled: true, fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8622A)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final recipe = filtered[i];
                    final added = widget.addedIds.contains(recipe.id);
                    final adding = widget.addingId == recipe.id;
                    return GestureDetector(
                      onTap: added ? null : () => widget.onAdd(recipe, _multiplier),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: added ? const Color(0xFFEDF7F1) : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: added ? const Color(0xFF2D9D5C) : Theme.of(context).dividerColor, width: added ? 1.5 : 1),
                        ),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 50, height: 50,
                              child: recipe.imageUrl != null
                                  ? CachedNetworkImage(imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                                  : Container(
                                  color: _mealPastel(recipe.cuisine.isNotEmpty ? recipe.cuisine : null),
                                  child: Center(child: Text(
                                    recipe.name.isNotEmpty ? recipe.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0x881A1918)),
                                  )),
                                ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(recipe.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            if (recipe.cuisine.isNotEmpty || recipe.totalTime > 0)
                              Text([recipe.cuisine, if (recipe.totalTime > 0) '${recipe.totalTime}m'].join(' · '), style: const TextStyle(fontSize: 12, color: Color(0xFF888480))),
                          ])),
                          if (adding) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8622A)))
                          else if (added) const Icon(Icons.check_circle, color: Color(0xFF2D9D5C), size: 20)
                          else const Icon(Icons.add_circle_outline, color: Color(0xFFE8622A), size: 20),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── Multiplier stepper ────────────────────────────────────────────────────────

class _MultStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _MultStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final card = Theme.of(context).cardColor;
    btn(IconData icon, bool enabled, VoidCallback onTap) => GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: card, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 13, color: enabled ? const Color(0xFF444140) : const Color(0xFFCCCAC5)),
      ),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove, value > 1, () => onChanged(value - 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('×$value', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1918))),
      ),
      btn(Icons.add, value < 8, () => onChanged(value + 1)),
    ]);
  }
}

// ── Recipe tray item ──────────────────────────────────────────────────────────

class _RecipeTrayItem extends StatelessWidget {
  final Recipe recipe;
  final bool isDragging;
  const _RecipeTrayItem({required this.recipe, this.isDragging = false});

  static const _pastels = {
    'italian': Color(0xFFF5EDE8), 'mexican': Color(0xFFE9F2E9),
    'japanese': Color(0xFFF2EDF4), 'chinese': Color(0xFFF5EDEC),
    'indian': Color(0xFFF5F0E8), 'american': Color(0xFFEBF0F5),
    'french': Color(0xFFEEF0F8), 'thai': Color(0xFFF3F2E7),
    'mediterranean': Color(0xFFE8F2EF), 'greek': Color(0xFFEDF0F8),
    'korean': Color(0xFFF4EDF2),
  };

  @override
  Widget build(BuildContext context) {
    final pastel = _pastels[recipe.cuisine.toLowerCase()] ?? const Color(0xFFF2F0EB);
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;

    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 8, top: 2),
      decoration: BoxDecoration(
        color: isDragging ? pastel : surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDragging ? const Color(0xFFE8622A) : border,
          width: isDragging ? 2 : 1.5,
        ),
        boxShadow: isDragging ? [
          BoxShadow(color: const Color(0xFFE8622A).withOpacity(0.25),
            blurRadius: 14, offset: const Offset(0, 5)),
        ] : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 46, width: double.infinity,
            child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                ? CachedNetworkImage(imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                : Container(
                    color: pastel,
                    child: Center(child: Text(
                      recipe.name.isNotEmpty ? recipe.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1918)),
                    )),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
            child: Text(recipe.name,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, height: 1.3,
                color: Theme.of(context).colorScheme.onSurface),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
