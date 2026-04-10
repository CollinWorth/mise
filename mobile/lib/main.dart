import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api.dart';
import 'storage/storage.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/add_recipe_screen.dart';
import 'screens/storage_setup_screen.dart';
import 'screens/grocery_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/social_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('mise_recipes');
  await Hive.openBox('mise_grocery');
  await Hive.openBox('mise_mealplans');
  await Store.init();
  await ThemeService.init();
  runApp(const MiseApp());
}

class MiseApp extends StatelessWidget {
  const MiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.notifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'mise',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8622A), brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xFFF7F6F3),
          cardColor: Colors.white,
          dividerColor: const Color(0xFFE5E2DC),
          fontFamily: 'SF Pro Display',
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8622A), brightness: Brightness.dark).copyWith(
            surface: const Color(0xFF242422),
            onSurface: const Color(0xFFECEAE6),
          ),
          scaffoldBackgroundColor: const Color(0xFF1A1918),
          cardColor: const Color(0xFF242422),
          dividerColor: const Color(0xFF333330),
          fontFamily: 'SF Pro Display',
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Map<String, dynamic>? _user;
  bool _checking = true;
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Check if storage mode has been configured
    final savedMode = await Store.getSavedMode();
    if (savedMode == null) {
      setState(() { _needsSetup = true; _checking = false; });
      return;
    }

    if (savedMode == StorageMode.local) {
      // Local mode — skip login, use guest user
      setState(() {
        _user = {'id': 'local', '_id': 'local', 'name': 'You', 'email': ''};
        _checking = false;
      });
      return;
    }

    // Server mode — check existing session
    final user = await Api.getStoredUser();
    setState(() { _user = user; _checking = false; });
  }

  void _onSetupComplete() async {
    setState(() { _needsSetup = false; _checking = true; });
    await _checkAuth();
  }

  void _onLogin() async {
    final user = await Api.getStoredUser();
    setState(() => _user = user);
  }

  void _onLogout() async {
    await Api.clearSession();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F6F3),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE8622A))),
      );
    }
    if (_needsSetup) {
      return StorageSetupScreen(onComplete: _onSetupComplete);
    }
    if (_user == null) {
      return LoginScreen(onLogin: _onLogin);
    }
    return HomeShell(user: _user!, onLogout: _onLogout);
  }
}

class HomeShell extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const HomeShell({super.key, required this.user, required this.onLogout});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _recipesKey = GlobalKey<RecipesScreenState>();

  @override
  void initState() {
    super.initState();
  }

  void _openAddRecipe(String? initialUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddRecipeScreen(user: widget.user, initialUrl: initialUrl),
        fullscreenDialog: true,
      ),
    ).then((saved) {
      if (saved == true) _recipesKey.currentState?.reload();
    });
  }

  void _resetToSetup() {
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      SocialScreen(user: widget.user),
      RecipesScreen(key: _recipesKey, user: widget.user),
      PlannerScreen(user: widget.user),
      GroceryScreen(user: widget.user),
      ProfileScreen(
        user: widget.user,
        onLogout: widget.onLogout,
        onStorageChange: _resetToSetup,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      floatingActionButton: _tab == 1
          ? FloatingActionButton(
              onPressed: () => _openAddRecipe(null),
              backgroundColor: const Color(0xFFE8622A),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: _MiseNavBar(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ── Custom nav bar (no sliding indicator animation) ───────────────────────────
class _MiseNavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _MiseNavBar({required this.current, required this.onTap});

  static const _items = [
    (icon: Icons.explore_outlined,        activeIcon: Icons.explore,         label: 'Discover'),
    (icon: Icons.menu_book_outlined,      activeIcon: Icons.menu_book,       label: 'Recipes'),
    (icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today,  label: 'Planner'),
    (icon: Icons.shopping_cart_outlined,  activeIcon: Icons.shopping_cart,   label: 'Grocery'),
    (icon: Icons.person_outline,          activeIcon: Icons.person,          label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF1A1918),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 60,
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final active = i == current;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? item.activeIcon : item.icon,
                      color: active ? const Color(0xFFE8622A) : Colors.white38,
                      size: 24,
                    ),
                    if (active) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE8622A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
