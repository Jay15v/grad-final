import 'package:flutter/material.dart';

// ─── Auth Design Tokens ───────────────────────────────────────────────────────
const kAuthBg     = Color(0xFF060D1F);
const kAuthCard   = Color(0xFF0C1A2E);
const kAuthField  = Color(0xFF0E2040);
const kAuthCyan   = Color(0xFF00C2FF);
const kAuthBlue   = Color(0xFF1A6EFF);
const kAuthBorder = Color(0xFF1C3352);
const kAuthPurple = Color(0xFF7C3AED);

// ─── Shield Logo ─────────────────────────────────────────────────────────────

class ShieldLogo extends StatelessWidget {
  final double size;
  final double iconSize;
  final double radius;

  const ShieldLogo({
    super.key,
    this.size = 36,
    this.iconSize = 18,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kAuthCyan, kAuthBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: kAuthCyan.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.shield, color: Colors.white, size: iconSize),
    );
  }
}

// ─── Gradient Button ─────────────────────────────────────────────────────────

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kAuthCyan, kAuthBlue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Auth Error Banner ────────────────────────────────────────────────────────

class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        border:
            Border.all(color: const Color(0xFFEF4444).withOpacity(0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
      ),
    );
  }
}

// ─── Auth Text Field ──────────────────────────────────────────────────────────

class AuthTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? hintText;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.hintText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
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
            prefixIcon: Icon(prefixIcon, color: Colors.white30, size: 18),
            hintText: hintText,
            hintStyle:
                const TextStyle(color: Colors.white24, fontSize: 14),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: kAuthField,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kAuthBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kAuthBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: kAuthCyan, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFEF4444), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
