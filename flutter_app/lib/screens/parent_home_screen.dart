import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../widgets/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../main.dart' show HomeShell, ThemeToggleButton;
import '../config/api_config.dart';
import 'child_location_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _pendingCases = [];
  bool _loadingPending = false;
  final Set<String> _favoritedCaseIds = {};
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    fetchPendingCases();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> fetchPendingCases() async {
    setState(() => _loadingPending = true);
    try {
      final token = await ApiService.getIdToken();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/pending'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          if (uid.isNotEmpty) 'X-Firebase-UID': uid,
          'X-Firebase-Role': 'parent',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _pendingCases = List<Map<String, dynamic>>.from(data['cases']);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pending error ${response.statusCode}: ${response.body}'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load pending reviews: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> submitFeedback(int caseId, int label) async {
    try {
      final token = await ApiService.getIdToken();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/feedback/$caseId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          if (uid.isNotEmpty) 'X-Firebase-UID': uid,
          'X-Firebase-Role': 'parent',
        },
        body: jsonEncode({'label': label}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _pendingCases.removeWhere((c) => c['case_id'] == caseId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                label == 1 ? 'Marked as dangerous' : 'Marked as safe',
              ),
              backgroundColor: label == 1 ? Colors.red : Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    }
  }

  Widget _buildBlockedAlertCard(Map<String, dynamic> alert) {
    final docId = alert['id'] as String;
    final prompt = alert['prompt'] as String? ?? '';
    final riskScore = (alert['risk_score'] as num?)?.toDouble() ?? 0.0;
    final category = (alert['semantic_category'] as String? ?? '').replaceAll('_', ' ');
    final ts = (alert['timestamp'] as num?) ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    final dateStr =
        '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
        color: Colors.red.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Blocked & Handled Safely',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'AegisMind detected a sensitive message and responded safely. No action required — you may want to check in with your child.',
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              prompt,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (category.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                'Risk ${(riskScore * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _firestoreService.acknowledgeBlockedAlert(docId),
              icon: const Icon(Icons.check, size: 15),
              label: const Text('Acknowledge & Dismiss'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedAlertsSection(String parentId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getBlockedAlerts(parentId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final alerts = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Safety Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${alerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map(_buildBlockedAlertCard),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildPendingSection(String parentId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getPendingReviews(parentId),
      builder: (context, snap) {
        final cases = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Pending Reviews',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withValues(
                          alpha: 0.4 + (_pulseController.value * 0.6)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (cases.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('${cases.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!snap.hasData)
              const Center(child: CircularProgressIndicator()),
            if (snap.hasData && cases.isEmpty)
              const Text('No pending reviews',
                  style: TextStyle(color: Colors.grey)),
            if (snap.hasData && cases.isNotEmpty)
              ...cases.map((c) {
                final docId = c['id'] as String;
                final riskScore = (c['risk_score'] as num? ?? 0).toDouble();
                final riskPercent =
                    '${(riskScore * 100).toStringAsFixed(0)}%';
                final ts = (c['timestamp'] as num?) ?? 0;
                final createdAt =
                    DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
                final dateStr =
                    '${createdAt.day}/${createdAt.month}/${createdAt.year} '
                    '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
                final isFavorited = _favoritedCaseIds.contains(docId);

                return Dismissible(
                  key: ValueKey(docId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 26),
                        SizedBox(height: 4),
                        Text('Dismiss',
                            style:
                                TextStyle(color: Colors.red, fontSize: 11)),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    _firestoreService.acknowledgePendingReview(docId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Case dismissed'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final borderColor = Color.lerp(
                        Colors.orange,
                        Colors.orange.withValues(alpha: 0.3),
                        _pulseController.value,
                      )!;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 2),
                          color: Colors.orange.withValues(alpha: 0.05),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Review Required — Uncertain Content Detected',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    if (isFavorited) {
                                      _favoritedCaseIds.remove(docId);
                                    } else {
                                      _favoritedCaseIds.add(docId);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      isFavorited
                                          ? Icons.star
                                          : Icons.star_outline,
                                      color: isFavorited
                                          ? Colors.amber
                                          : AppTheme.of(context).textMuted,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c['prompt'] as String? ?? '',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Risk Score: $riskPercent',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: riskScore,
                              backgroundColor:
                                  Colors.grey.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                riskScore > 0.7
                                    ? Colors.red
                                    : riskScore > 0.4
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Submitted: $dateStr',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _firestoreService
                                        .acknowledgePendingReview(docId),
                                    icon: const Icon(
                                        Icons.dangerous_outlined,
                                        size: 16),
                                    label: const Text('Confirm Dangerous'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _firestoreService
                                        .acknowledgePendingReview(docId),
                                    icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16),
                                    label: const Text('Mark as Safe'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final t = AppTheme.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        decoration: BoxDecoration(gradient: t.bgGradient),
        child: FutureBuilder<UserModel?>(
          future: _firestoreService.getUser(uid),
          builder: (context, parentSnap) {
            final parent = parentSnap.data;
            return Column(
              children: [
                _buildHeader(parent),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBlockedAlertsSection(uid),
                        _buildPendingSection(uid),
                        const SizedBox(height: 24),
                        _buildWelcomeCard(parent),
                        const SizedBox(height: 20),
                        _buildChatCard(context),
                        const SizedBox(height: 20),
                        _buildChildrenSection(uid),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel? parent) {
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      decoration: BoxDecoration(
        gradient: t.headerGradient,
        border: Border(
          bottom: BorderSide(
              color: AppColors.parentAccent.withValues(alpha: 0.25), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.parentAccent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const ShieldLogo(size: 40, iconSize: 20, radius: 10),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AegisMind',
                style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Parent Portal',
                style: TextStyle(color: t.textMuted, fontSize: 10),
              ),
            ],
          ),
          const Spacer(),
          // Parent badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.parentAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.parentAccent.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'PARENT',
              style: TextStyle(
                color: AppColors.parentAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const ThemeToggleButton(),
          IconButton(
            icon: Icon(Icons.refresh, color: t.textMuted, size: 20),
            tooltip: 'Refresh pending reviews',
            onPressed: fetchPendingCases,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: t.textMuted, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.of(context).bgSurface,
                  title: Text('Sign out',
                      style: TextStyle(color: t.textPrimary, fontSize: 15)),
                  content: Text('Are you sure you want to sign out?',
                      style: TextStyle(
                          color: AppTheme.of(context).textSecondary, fontSize: 13)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel',
                          style: TextStyle(color: AppTheme.of(context).textMuted)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(UserModel? parent) {
    final since = parent?.createdAt != null
        ? '${parent!.createdAt.day}/${parent.createdAt.month}/${parent.createdAt.year}'
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.parentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.parentAccent.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar circle with initials
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Text(
                parent != null && parent.name.isNotEmpty
                    ? parent.name[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back${parent != null ? ', ${parent.name}' : ''}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  since != null
                      ? 'Protecting your children since $since'
                      : 'Protecting your children with AegisMind',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_outlined, color: Colors.white38, size: 32),
        ],
      ),
    );
  }

  Widget _buildChatCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.of(context).bgSurface,
          border: Border.all(color: AppTheme.of(context).border.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Access AegisMind\'s safe chat and analyzer',
                    style:
                        TextStyle(color: AppTheme.of(context).textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.of(context).textMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildrenSection(String parentId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.child_care,
                color: AppColors.childAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              'Child Accounts',
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<UserModel>>(
          stream: _firestoreService.getChildrenOfParent(parentId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final children = snapshot.data ?? [];

            // ── Empty state ─────────────────────────────────────────────
            if (children.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).bgSurface,
                  border: Border.all(
                      color: AppTheme.of(context).border.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.childAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.child_care,
                          color: AppColors.childAccent, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No children linked yet',
                      style: TextStyle(
                        color: AppTheme.of(context).textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ask your admin to create a child account\nlinked to your email.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.of(context).textMuted, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            // ── Child cards ──────────────────────────────────────────────
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: children.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final child = children[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.of(context).bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.of(context).border.withValues(alpha: 0.3)),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Teal left accent strip
                          Container(width: 3, color: AppColors.childAccent),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 14, 14, 12),
                              child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Avatar circle with initials
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppColors.childGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  child.name.isNotEmpty
                                      ? child.name[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        child.name,
                                        style: TextStyle(
                                          color: AppTheme.of(context).textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Online status dot
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.success
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    child.email,
                                    style: TextStyle(
                                        color: AppTheme.of(context).textMuted,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // CHILD pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.childAccent
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.childAccent
                                        .withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'CHILD',
                                style: TextStyle(
                                  color: AppColors.childAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChildLocationScreen(
                                  childId: child.uid,
                                  childName: child.name,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.location_on_outlined,
                                size: 15),
                            label: const Text('View Activity'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.childAccent,
                              side: BorderSide(
                                  color: AppColors.childAccent
                                      .withValues(alpha: 0.4)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),         // Column
                  ),           // Padding
                ),             // Expanded
              ],               // Row children
            ),                 // Row
          ),                   // IntrinsicHeight
        ),                     // ClipRRect
      );                       // Container
    },                         // itemBuilder
  );                           // ListView.separated
},                             // StreamBuilder builder
        ),
      ],
    );
  }
}
