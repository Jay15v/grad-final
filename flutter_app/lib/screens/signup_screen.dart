import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../widgets/app_colors.dart';
import '../widgets/auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey         = GlobalKey<FormState>();
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  final _parentEmailCtrl  = TextEditingController();
  final _nationalIdCtrl   = TextEditingController();
  final _authService      = AuthService();
  final _firestoreService = FirestoreService();

  int? _idAge;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  String  _accountType    = 'parent';
  bool    _loading        = false;
  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  bool    _agreedToTerms  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _parentEmailCtrl.dispose();
    _nationalIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(() =>
          _error = 'Please agree to the Terms of Service and Privacy Policy.');
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      String? parentId;
      if (_accountType == 'child') {
        final parent = await _firestoreService
            .getUserByEmail(_parentEmailCtrl.text.trim());
        if (parent == null) {
          setState(() {
            _error =
                'No parent account found with that email. Ask your parent to register first.';
            _loading = false;
          });
          return;
        }
        parentId = parent.uid;
      }

      final credential = await _authService.signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      try {
        await _firestoreService.createUserRecord(
          UserModel(
            uid: credential.user!.uid,
            email: _emailCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            role: _accountType,
            parentId: parentId,
            createdAt: DateTime.now(),
          ),
        );
      } catch (firestoreError) {
        await credential.user?.delete();
        rethrow;
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _extractBirthDate(String id) {
    if (id.length != 14 || !RegExp(r'^\d{14}$').hasMatch(id)) return null;
    final century = id[0] == '2' ? 1900 : id[0] == '3' ? 2000 : null;
    if (century == null) return null;
    final year  = century + int.parse(id.substring(1, 3));
    final month = int.parse(id.substring(3, 5));
    final day   = int.parse(id.substring(5, 7));
    try { return DateTime(year, month, day); } catch (_) { return null; }
  }

  int? _calculateAge(String id) {
    final b = _extractBirthDate(id);
    if (b == null) return null;
    final t = DateTime.now();
    int age = t.year - b.year;
    if (t.month < b.month || (t.month == b.month && t.day < b.day)) age--;
    return age;
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
        return 'Sign up failed. Please try again.';
    }
  }

  void _goToLogin() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.authBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: _buildCard(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Nav bar ─────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    final t = AppTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            const ShieldLogo(),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AegisMind',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Where Defense Meets Reasoning',
                  style: TextStyle(color: kAuthCyan, fontSize: 9),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: _goToLogin,
              child: Text(
                'Login',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kAuthCyan, kAuthBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.person_outline, color: Colors.white54, size: 22),
          ],
        ),
      ),
    );
  }

  // ─── Glassmorphism card ──────────────────────────────────────────────────

  Widget _buildCard() {
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: t.authCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.authCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: ShieldLogo(size: 64, iconSize: 32, radius: 18)),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'AegisMind',
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Where Defense Meets Reasoning',
                style: TextStyle(color: kAuthCyan, fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Create Account',
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                "Join AegisMind's Defense System",
                style: TextStyle(color: t.textMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),

            // ── Account Type Selector ────────────────────────────────────
            Text(
              'Account Type',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AccountTypeCard(
                    label: 'Parent',
                    icon: Icons.people,
                    selected: _accountType == 'parent',
                    selectedColor: kAuthPurple,
                    onTap: () => setState(() => _accountType = 'parent'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AccountTypeCard(
                    label: 'Child',
                    icon: Icons.child_care,
                    selected: _accountType == 'child',
                    selectedColor: kAuthTeal,
                    onTap: () => setState(() => _accountType = 'child'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Fields ──────────────────────────────────────────────────
            AuthTextField(
              label: 'Full Name',
              controller: _nameCtrl,
              prefixIcon: Icons.person_outline,
              hintText: 'John Doe',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Email Address',
              controller: _emailCtrl,
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              hintText: 'your.email@example.com',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),

            if (_accountType == 'child') ...[
              const SizedBox(height: 14),
              AuthTextField(
                label: "Parent's Email Address",
                controller: _parentEmailCtrl,
                prefixIcon: Icons.family_restroom,
                keyboardType: TextInputType.emailAddress,
                hintText: 'parent.email@example.com',
                validator: (v) {
                  if (_accountType != 'child') return null;
                  if (v == null || v.isEmpty) {
                    return "Parent's email is required";
                  }
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // ── National ID field (child only) ────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الرقم القومي',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nationalIdCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      counterText: '',
                      prefixIcon: const Icon(Icons.badge_outlined,
                          color: Colors.white30, size: 18),
                      hintText: '12345678901234',
                      hintStyle: const TextStyle(
                          color: Colors.white24, fontSize: 14),
                      suffixIcon: _idAge != null && _idAge! < 18
                          ? const Icon(Icons.check_circle_outline,
                              color: Color(0xFF22C55E), size: 18)
                          : null,
                      filled: true,
                      fillColor: kAuthField,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kAuthBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kAuthBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: kAuthCyan, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFEF4444)),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFEF4444), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onChanged: (v) {
                      setState(() =>
                          _idAge = v.length == 14 ? _calculateAge(v) : null);
                    },
                    validator: (v) {
                      if (_accountType != 'child') return null;
                      if (v == null || v.isEmpty) return 'الرقم القومي مطلوب';
                      final age = _calculateAge(v);
                      if (age == null) return 'الرقم القومي غير صحيح';
                      if (age >= 18) {
                        return 'يجب أن يكون عمر الطفل أقل من 18 سنة';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Password',
              controller: _passwordCtrl,
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePass,
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: t.textMuted,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Confirm Password',
              controller: _confirmCtrl,
              prefixIcon: Icons.lock_outline,
              obscureText: _obscureConfirm,
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: t.textMuted,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm password';
                if (v != _passwordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Terms checkbox ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) =>
                        setState(() => _agreedToTerms = v ?? false),
                    activeColor: kAuthCyan,
                    checkColor: Colors.white,
                    side: const BorderSide(color: kAuthBorder, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      children: [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                              color: kAuthCyan, fontWeight: FontWeight.w500),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                              color: kAuthCyan, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              AuthErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),

            GradientButton(
              label: 'Create Account',
              icon: Icons.shield,
              onPressed: _signup,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Account Type Card ────────────────────────────────────────────────────────

class _AccountTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected ? selectedColor : kAuthBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? selectedColor : Colors.white30,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedColor : Colors.white30,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
