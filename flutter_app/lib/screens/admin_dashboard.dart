import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    _tabs = TabController(length: 3, vsync: this);
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
