import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AegisMindApp());
}

class AegisMindApp extends StatelessWidget {
  const AegisMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AegisMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.bgSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        dividerColor: AppColors.border.withOpacity(0.4),
      ),
      home: const AuthGate(),
    );
  }
}

// ─── Auth Gate ───────────────────────────────────────────────────────────────
// Listens to Firebase auth state and routes to Login or the role-based screen.

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
// Reads the user's Firestore role and navigates to the correct screen.

class _RoleRouter extends StatefulWidget {
  final String uid;
  const _RoleRouter({required this.uid});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<UserModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadUser();
  }

  Future<UserModel?> _loadUser() async {
    // Read raw Firestore doc without converter to avoid any serialization issues
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get()
        .timeout(const Duration(seconds: 15));
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
          // No Firestore record — sign out after frame
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => FirebaseAuth.instance.signOut(),
          );
          return const _SplashScreen();
        }

        switch (user.role) {
          case 'admin':
            return const AdminDashboard();
          case 'parent':
            return const ParentHomeScreen();
          case 'child':
          default:
            return const HomeShell();
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
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Splash Screen ───────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(strokeWidth: 2),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: AppColors.accent.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
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
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AegisMind',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text('When Defense Meets Reasoning',
                  style: TextStyle(
                      color: AppColors.accent.withOpacity(0.8),
                      fontSize: 10)),
            ],
          ),
          const Spacer(),
          // Mode toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.6),
              border:
                  Border.all(color: AppColors.border.withOpacity(0.4)),
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
                const SizedBox(width: 4),
                _TabButton(
                  label: 'Analyzer',
                  icon: Icons.manage_search_outlined,
                  selected: selectedIndex == 1,
                  onTap: () => onTabChanged(1),
                ),
              ],
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.accent.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        selected ? Colors.white : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
