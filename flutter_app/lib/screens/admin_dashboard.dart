import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../widgets/app_colors.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _UsersTab(firestoreService: _firestoreService),
                  _CreateAccountTab(
                    key: const ValueKey('parent'),
                    role: 'parent',
                    authService: _authService,
                    firestoreService: _firestoreService,
                  ),
                  _CreateAccountTab(
                    key: const ValueKey('child'),
                    role: 'child',
                    authService: _authService,
                    firestoreService: _firestoreService,
                  ),
                  const _AlertsTab(),
                  const _AnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: AppColors.accent.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'AegisMind',
                style: TextStyle(
                  color: AppColors.accent.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.textMuted, size: 20),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.bgSurface,
      child: TabBar(
        controller: _tabs,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        indicatorWeight: 2,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'All Users'),
          Tab(text: 'Create Parent'),
          Tab(text: 'Create Child'),
          Tab(text: 'Alerts'),
          Tab(text: 'Analytics'),
        ],
      ),
    );
  }
}

// ─── Users Tab ───────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  final FirestoreService firestoreService;

  const _UsersTab({required this.firestoreService});

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.warning;
      case 'parent':
        return AppColors.accent;
      case 'child':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'parent':
        return Icons.person_outlined;
      case 'child':
        return Icons.child_care;
      default:
        return Icons.person_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: firestoreService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading users',
              style: TextStyle(color: AppColors.danger),
            ),
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(
              'No users yet',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final user = users[i];
            final color = _roleColor(user.role);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                border: Border.all(color: AppColors.border.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_roleIcon(user.role), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (user.parentId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Parent ID: ${user.parentId}',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Create Account Tab (shared by parent + child) ───────────────────────────

class _CreateAccountTab extends StatefulWidget {
  final String role; // 'parent' or 'child'
  final AuthService authService;
  final FirestoreService firestoreService;

  const _CreateAccountTab({
    super.key,
    required this.role,
    required this.authService,
    required this.firestoreService,
  });

  @override
  State<_CreateAccountTab> createState() => _CreateAccountTabState();
}

class _CreateAccountTabState extends State<_CreateAccountTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  // Only for child accounts
  UserModel? _selectedParent;
  List<UserModel> _parents = [];
  bool _loadingParents = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'child') _loadParents();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _loadParents() {
    setState(() => _loadingParents = true);
    widget.firestoreService.getParents().listen((parents) {
      if (mounted) setState(() {
        _parents = parents;
        _loadingParents = false;
      });
    });
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.role == 'child' && _selectedParent == null) {
      setState(() => _error = 'Please select a parent account.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final uid = await widget.authService.createUserWithoutSigningOut(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await widget.firestoreService.createUserRecord(
        UserModel(
          uid: uid,
          email: _emailCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          role: widget.role,
          parentId: widget.role == 'child' ? _selectedParent!.uid : null,
          createdAt: DateTime.now(),
        ),
      );
      setState(() {
        _success =
            '${widget.role == 'parent' ? 'Parent' : 'Child'} account created successfully.';
        _nameCtrl.clear();
        _emailCtrl.clear();
        _passwordCtrl.clear();
        _selectedParent = null;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return 'Failed to create account. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChild = widget.role == 'child';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              border: Border.all(color: AppColors.border.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isChild ? 'New Child Account' : 'New Parent Account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isChild
                        ? 'Child accounts are linked to a parent and go directly to the chat.'
                        : 'Parent accounts can have child accounts linked to them.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  _field('Full Name', _nameCtrl, validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null),
                  const SizedBox(height: 14),
                  _field(
                    'Email',
                    _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _field(
                    'Password',
                    _passwordCtrl,
                    obscureText: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  if (isChild) ...[
                    const SizedBox(height: 14),
                    _buildParentDropdown(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _banner(_error!, AppColors.danger),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 14),
                    _banner(_success!, AppColors.success),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 44,
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : ElevatedButton(
                            onPressed: _create,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isChild
                                  ? 'Create Child Account'
                                  : 'Create Parent Account',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
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

  Widget _buildParentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Link to Parent',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        _loadingParents
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _parents.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Text(
                      'No parent accounts exist yet. Create a parent first.',
                      style: TextStyle(
                          color: AppColors.warning, fontSize: 12),
                    ),
                  )
                : DropdownButtonFormField<UserModel>(
                    value: _selectedParent,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: AppColors.border.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: AppColors.border.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: AppColors.accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    hint: Text(
                      'Select parent',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    items: _parents
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.email})'),
                          ),
                        )
                        .toList(),
                    onChanged: (p) => setState(() => _selectedParent = p),
                  ),
      ],
    );
  }

  Widget _banner(String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 13),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: AppColors.border.withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: AppColors.border.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.danger, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ─── Alerts Tab ───────────────────────────────────────────────────────────────

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  Color _flagColor(String? type) {
    switch (type) {
      case 'HALLUCINATION_CONFIRMED': return AppColors.danger;
      case 'FALSE_CONSENSUS':         return AppColors.warning;
      case 'RAG_WEAK':                return AppColors.accent;
      case 'LLM_DEGRADED':           return AppColors.blue;
      default:                        return AppColors.textMuted;
    }
  }

  String _flagLabel(String? type) {
    switch (type) {
      case 'HALLUCINATION_CONFIRMED': return 'Hallucination';
      case 'FALSE_CONSENSUS':         return 'False Consensus';
      case 'RAG_WEAK':                return 'RAG Weak';
      case 'LLM_DEGRADED':           return 'LLM Degraded';
      default:                        return type ?? 'Unknown';
    }
  }

  String _timeAgo(num? epoch) {
    if (epoch == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch((epoch * 1000).toInt());
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0)    return '${d.inDays}d ago';
    if (d.inHours > 0)   return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'just now';
  }

  Future<void> _resolve(BuildContext ctx, String docId) async {
    await FirebaseFirestore.instance
        .collection('admin_flags')
        .doc(docId)
        .update({'resolved': true});
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: const Text('Flag marked as resolved.'),
        backgroundColor: AppColors.success.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _flagForRag(BuildContext ctx, String docId) async {
    await FirebaseFirestore.instance
        .collection('admin_flags')
        .doc(docId)
        .update({'rag_tuning_flagged': true, 'resolved': true});
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: const Text('Flagged for RAG tuning.'),
        backgroundColor: AppColors.accent.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_flags')
          .where('resolved', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading alerts',
                style: TextStyle(color: AppColors.danger)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No unresolved alerts',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('All flags have been addressed.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final color = _flagColor(data['flag_type'] as String?);
            return _AlertCard(
              data: data,
              flagColor: color,
              flagLabel: _flagLabel(data['flag_type'] as String?),
              timeAgo: _timeAgo(data['created_at'] as num?),
              onResolve:   () => _resolve(context, doc.id),
              onRagTuning: () => _flagForRag(context, doc.id),
            );
          },
        );
      },
    );
  }
}

// ─── Alert Card ───────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color flagColor;
  final String flagLabel;
  final String timeAgo;
  final VoidCallback onResolve;
  final VoidCallback onRagTuning;

  const _AlertCard({
    required this.data,
    required this.flagColor,
    required this.flagLabel,
    required this.timeAgo,
    required this.onResolve,
    required this.onRagTuning,
  });

  @override
  Widget build(BuildContext context) {
    final verdict       = data['verdict'] as String?;
    final ragHitRate    = data['rag_hit_rate'] != null
        ? (data['rag_hit_rate'] as num).toDouble()
        : null;
    final promptSnippet = data['prompt_snippet'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: flagColor.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: badge + time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: flagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: flagColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  flagLabel.toUpperCase(),
                  style: TextStyle(
                    color: flagColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(timeAgo,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),

          // Prompt snippet
          if (promptSnippet != null && promptSnippet.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"$promptSnippet"',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),

          // Meta: verdict + RAG hit rate
          Row(
            children: [
              if (verdict != null) ...[
                _metaChip(
                  icon: Icons.model_training_outlined,
                  label: verdict,
                  color: verdict == 'DISAGREEMENT'
                      ? AppColors.danger
                      : verdict == 'PARTIAL'
                          ? AppColors.warning
                          : AppColors.success,
                ),
                const SizedBox(width: 8),
              ],
              if (ragHitRate != null)
                _metaChip(
                  icon: Icons.search_outlined,
                  label:
                      'RAG ${(ragHitRate * 100).toStringAsFixed(0)}%',
                  color: ragHitRate >= 0.5
                      ? AppColors.success
                      : AppColors.warning,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              _actionButton(
                icon: Icons.check_circle_outline,
                label: 'Mark Resolved',
                color: AppColors.success,
                onTap: onResolve,
              ),
              const SizedBox(width: 8),
              _actionButton(
                icon: Icons.tune_outlined,
                label: 'Flag for RAG Tuning',
                color: AppColors.accent,
                onTap: onRagTuning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  bool    _loading = true;
  String? _error;

  int    _totalFlags         = 0;
  int    _hallucinationCount = 0;
  int    _falseConsensusCount = 0;
  int    _ragWeakCount       = 0;
  int    _llmDegradedCount   = 0;
  double _avgRagHitRate      = 0.0;

  double _threshold = 0.60;
  bool   _saving    = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final flagsSnap = await FirebaseFirestore.instance
          .collection('admin_flags')
          .get();

      int total = 0, halluc = 0, falseCons = 0, ragWeak = 0, llmDeg = 0;
      double ragSum = 0.0;
      int    ragCount = 0;

      for (final doc in flagsSnap.docs) {
        final d = doc.data();
        total++;
        switch (d['flag_type'] as String?) {
          case 'HALLUCINATION_CONFIRMED': halluc++;    break;
          case 'FALSE_CONSENSUS':         falseCons++; break;
          case 'RAG_WEAK':                ragWeak++;   break;
          case 'LLM_DEGRADED':            llmDeg++;    break;
        }
        if (d['rag_hit_rate'] != null) {
          ragSum += (d['rag_hit_rate'] as num).toDouble();
          ragCount++;
        }
      }

      final configDoc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('thresholds')
          .get();
      double threshold = 0.60;
      if (configDoc.exists) {
        threshold = (configDoc.data()?['consensus_threshold'] as num?)
                ?.toDouble() ??
            0.60;
      }

      setState(() {
        _loading             = false;
        _totalFlags          = total;
        _hallucinationCount  = halluc;
        _falseConsensusCount = falseCons;
        _ragWeakCount        = ragWeak;
        _llmDegradedCount    = llmDeg;
        _avgRagHitRate       = ragCount > 0 ? ragSum / ragCount : 0.0;
        _threshold           = threshold.clamp(0.50, 0.95);
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _saveThreshold() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('system_config')
          .doc('thresholds')
          .set({'consensus_threshold': _threshold}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Threshold saved: ${_threshold.toStringAsFixed(2)}'),
          backgroundColor: AppColors.success.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.danger.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text('Error: $_error',
            style: TextStyle(color: AppColors.danger)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Summary'),
          const SizedBox(height: 10),
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _sectionLabel('Flag Breakdown'),
          const SizedBox(height: 10),
          _buildBarChart(),
          const SizedBox(height: 20),
          _sectionLabel('Consensus Threshold'),
          const SizedBox(height: 10),
          _buildThresholdControl(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

  // ── Summary cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _summaryCard('Total Flags',     '$_totalFlags',
            Icons.flag_outlined,           AppColors.accent),
        _summaryCard('Hallucinations',  '$_hallucinationCount',
            Icons.warning_amber_outlined,  AppColors.danger),
        _summaryCard('False Consensus', '$_falseConsensusCount',
            Icons.people_outline,          AppColors.warning),
        _summaryCard('Avg RAG Hit Rate',
            '${(_avgRagHitRate * 100).toStringAsFixed(1)}%',
            Icons.search_outlined,         AppColors.success),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )),
                Text(label,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bar chart ──────────────────────────────────────────────────────────────

  Widget _buildBarChart() {
    final items = [
      _BarItem('Hallucin-\nation', _hallucinationCount,  AppColors.danger),
      _BarItem('False\nConsensus', _falseConsensusCount, AppColors.warning),
      _BarItem('RAG\nWeak',        _ragWeakCount,        AppColors.accent),
      _BarItem('LLM\nDegraded',    _llmDegradedCount,    AppColors.blue),
    ];

    int maxCount = 1;
    for (final item in items) {
      if (item.count > maxCount) maxCount = item.count;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _totalFlags == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No flag data yet.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ),
            )
          : SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.map((item) {
                  final barH =
                      (item.count / maxCount) * 90.0;
                  return Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item.count > 0)
                            Text('${item.count}',
                                style: TextStyle(
                                  color: item.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                )),
                          const SizedBox(height: 4),
                          Container(
                            height: barH > 0 ? barH : 4,
                            decoration: BoxDecoration(
                              color: item.count > 0
                                  ? item.color.withValues(alpha: 0.75)
                                  : AppColors.border
                                      .withValues(alpha: 0.3),
                              borderRadius:
                                  const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(item.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ── Threshold control ──────────────────────────────────────────────────────

  Widget _buildThresholdControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Similarity Threshold',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _threshold.toStringAsFixed(2),
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Controls when cross-model responses count as agreement. '
            'Raise it if models agree on wrong answers too easily '
            '(reduces FALSE_CONSENSUS flags). Lower it if models '
            'disagree too often despite similar responses. Default: 0.60.',
            style:
                TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   AppColors.accent,
              inactiveTrackColor: AppColors.border,
              thumbColor:         AppColors.accent,
              overlayColor:
                  AppColors.accent.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _threshold,
              min: 0.50,
              max: 0.95,
              divisions: 45,
              onChanged: (v) => setState(() => _threshold = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0.50  Lenient',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
                Text('0.95  Strict',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: _saving
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton(
                    onPressed: _saveThreshold,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save Threshold',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Bar Item ─────────────────────────────────────────────────────────────────

class _BarItem {
  final String label;
  final int    count;
  final Color  color;
  const _BarItem(this.label, this.count, this.color);
}
