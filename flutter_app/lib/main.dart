import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/chat_screen.dart';
import 'screens/analyzer_screen.dart';
import 'widgets/app_colors.dart';

void main() {
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
      home: const HomeShell(),
    );
  }
}

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
