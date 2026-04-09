import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../widgets/auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _parentEmailCtrl = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  String _accountType = 'parent'; // 'parent' | 'child'
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _parentEmailCtrl.dispose();
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
      _error = null;
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
        // Write Firestore record BEFORE AuthGate reacts to authStateChanges
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
        // Firestore write failed — delete the auth account so we don't leave
        // a half-created user with no Firestore record
        await credential.user?.delete();
        rethrow;
      }

      // Pop entire navigator stack so AuthGate (the root) takes over cleanly
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
    return Scaffold(
      backgroundColor: kAuthBg,
      body: Column(
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
    );
  }

  // ─── Nav bar ───────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            const ShieldLogo(),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AegisMind',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'When Defense Meets Reasoning',
                  style: TextStyle(color: kAuthCyan, fontSize: 9),
                ),
              ],
            ),
            const Spacer(),
            // "Login" — navigate back
            GestureDetector(
              onTap: _goToLogin,
              child: const Text(
                'Login',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // "Sign Up" — active page, gradient pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  // ─── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: kAuthCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAuthBorder),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            const Center(
              child: ShieldLogo(size: 64, iconSize: 32, radius: 18),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                "Join AegisMind's Defense System",
                style: TextStyle(color: kAuthCyan, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),

            // ── Account Type Selector ──────────────────────────────────────
            const Text(
              'Account Type',
              style: TextStyle(
                color: Colors.white70,
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
                    onTap: () => setState(() => _accountType = 'parent'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AccountTypeCard(
                    label: 'Child',
                    icon: Icons.child_care,
                    selected: _accountType == 'child',
                    onTap: () => setState(() => _accountType = 'child'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Fields ────────────────────────────────────────────────────
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

            // Parent's email — shown only when Child is selected
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
                  if (v == null || v.isEmpty)
                    return "Parent's email is required";
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
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
                  color: Colors.white30,
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
                  color: Colors.white30,
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

            // ── Terms checkbox ────────────────────────────────────────────
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

            // Create Account button
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
  final VoidCallback onTap;

  const _AccountTypeCard({
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? kAuthPurple.withOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected ? kAuthPurple : kAuthBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? kAuthPurple : Colors.white30,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? kAuthPurple : Colors.white30,
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
