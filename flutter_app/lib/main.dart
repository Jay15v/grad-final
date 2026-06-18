import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/chat_screen.dart';
import 'screens/analyzer_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/parent_home_screen.dart';
import 'widgets/app_colors.dart';
import 'widgets/auth_widgets.dart';
import 'services/location_service.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const ProviderScope(child: AegisMindApp()));
}

// ─── Root app ─────────────────────────────────────────────────────────────────

class AegisMindApp extends ConsumerWidget {
  const AegisMindApp({super.key});

  static ThemeData _buildTheme(AppTheme colors, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: colors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: brightness,
        surface: colors.bgSurface,
      ).copyWith(primary: AppColors.accent),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      dividerColor: colors.border.withValues(alpha: 0.4),
      extensions: [colors],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'AegisMind',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme:     _buildTheme(AppTheme.light, Brightness.light),
      darkTheme: _buildTheme(AppTheme.dark,  Brightness.dark),
      home: const AuthGate(),
    );
  }
}

// ─── Theme toggle button (reusable across all screens) ───────────────────────

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t      = AppTheme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).state =
          isDark ? ThemeMode.light : ThemeMode.dark,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.6),
          border: Border.all(color: t.border.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          size: 16,
          color: t.textMuted,
        ),
      ),
    );
  }
}

// ─── Auth Gate ───────────────────────────────────────────────────────────────

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return _RoleRouter(uid: snapshot.data!.uid);
        }
        return const LoginScreen();
      },
    );
  }
}

// ─── Role Router ─────────────────────────────────────────────────────────────

class _RoleRouter extends StatefulWidget {
  final String uid;
  const _RoleRouter({required this.uid});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<UserModel?> _future;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _future = _loadUser();
  }

  Future<UserModel?> _loadUser() async {
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get(const GetOptions(source: Source.cache));
    }
    if (!doc.exists) return null;
    final data = doc.data()!;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: (data['role'] as String? ?? 'child').toLowerCase(),
      parentId: data['parentId'] as String?,
      createdAt: (data['createdAt'] != null)
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  void _retry() => setState(() => _future = _loadUser());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snapshot.hasError) {
          return _ErrorScreen(
            message: 'Could not load profile:\n${snapshot.error}',
            onRetry: _retry,
            onSignOut: () => FirebaseAuth.instance.signOut(),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          if (!_signingOut) {
            _signingOut = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => FirebaseAuth.instance.signOut(),
            );
          }
          return const _SplashScreen();
        }
        switch (user.role) {
          case 'admin':  return const AdminDashboard();
          case 'parent': return const ParentHomeScreen();
          case 'child':
          default:       return const HomeShell();
        }
      },
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _ErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: onSignOut,
                child: Text('Sign out',
                    style: TextStyle(color: t.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Splash Screen ───────────────────────────────────────────────────────────

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ShieldLogo(size: 80, iconSize: 40, radius: 22),
                  const SizedBox(height: 20),
                  Text(
                    'AegisMind',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Where Defense Meets Reasoning',
                    style: TextStyle(color: AppColors.accent, fontSize: 11),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Home Shell (child / default users) ──────────────────────────────────────

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  final _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _locationService.start();
  }

  @override
  void dispose() {
    _locationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: Column(
          children: [
            _AppBar(
              selectedIndex: _selectedIndex,
              onTabChanged: (i) => setState(() => _selectedIndex = i),
            ),
            Expanded(
              child: _selectedIndex == 0
                  ? const ChatScreen()
                  : const AnalyzerScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabChanged;

  const _AppBar({
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: t.bgSurface.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(color: AppColors.accent.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text('A',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
            Text('AegisMind',
                style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
            // Safe Mode icon badge
            Tooltip(
              message: 'Safe Mode Active',
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.childAccent.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.childAccent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.verified_user_outlined, size: 14, color: AppColors.childAccent),
              ),
            ),
            const SizedBox(width: 6),
            // Tab switcher
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: t.surface.withValues(alpha: 0.6),
                border: Border.all(color: t.border.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TabButton(
                    label: 'Chat',
                    icon: Icons.chat_bubble_outline,
                    selected: selectedIndex == 0,
                    onTap: () => onTabChanged(0),
                  ),
                  const SizedBox(width: 2),
                  _TabButton(
                    label: 'Analyze',
                    icon: Icons.manage_search_outlined,
                    selected: selectedIndex == 1,
                    onTap: () => onTabChanged(1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const ThemeToggleButton(),
            const SizedBox(width: 6),
            // Logout button
            Tooltip(
              message: 'Sign out',
              child: GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: t.bgSurface,
                      title: Text('Sign out',
                          style: TextStyle(color: t.textPrimary, fontSize: 15)),
                      content: Text('Are you sure you want to sign out?',
                          style: TextStyle(color: t.textSecondary, fontSize: 13)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style: TextStyle(color: t.textMuted)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Sign out',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseAuth.instance.signOut();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.surface.withValues(alpha: 0.6),
                    border: Border.all(color: t.border.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.logout, size: 16, color: t.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Tooltip(
          message: label,
          child: Icon(icon,
              size: 16,
              color: selected ? Colors.white : t.textMuted),
        ),
      ),
    );
  }
}
