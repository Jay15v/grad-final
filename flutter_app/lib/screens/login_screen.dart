import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(
          () => _error = 'Enter your email above first, then tap "Forgot password?"');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset email sent! Check your inbox.')),
        );
      }
    } catch (_) {
      setState(() => _error = 'Failed to send reset email. Check the address.');
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  void _goToSignup() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignupScreen()),
      );

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
            // "Login" — active page, plain text
            const Text(
              'Login',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            // "Sign Up" — gradient pill
            GestureDetector(
              onTap: _goToSignup,
              child: Container(
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
                'Welcome Back',
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
                'Login to access AegisMind',
                style: TextStyle(color: kAuthCyan, fontSize: 13),
              ),
            ),
            const SizedBox(height: 28),

            // Email
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
            const SizedBox(height: 16),

            // Password
            AuthTextField(
              label: 'Password',
              controller: _passwordCtrl,
              prefixIcon: Icons.lock_outline,
              obscureText: _obscure,
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white30,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required' : null,
            ),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(color: kAuthCyan, fontSize: 12),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 4),
              AuthErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 8),

            // Login button
            GradientButton(
              label: 'Login',
              icon: Icons.login,
              onPressed: _login,
              loading: _loading,
            ),
            const SizedBox(height: 20),

            // Sign up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                GestureDetector(
                  onTap: _goToSignup,
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: kAuthCyan,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
