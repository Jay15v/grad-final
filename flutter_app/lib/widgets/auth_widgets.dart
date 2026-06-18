import 'package:flutter/material.dart';
import 'app_colors.dart';

// ─── Auth Design Tokens ───────────────────────────────────────────────────────
// Brand / role colors — same in both modes.
const kAuthCyan   = Color(0xFF2196F3); // primary blue
const kAuthBlue   = Color(0xFF1565C0); // darker blue
const kAuthBorder = Color(0xFF1E3A5F); // kept for const gradient usage
const kAuthPurple = Color(0xFF7B1FA2);
const kAuthTeal   = Color(0xFF00897B);
// Structural constants below are legacy — new code uses AppTheme.of(context).
const kAuthBg     = Color(0xFF0A1628);
const kAuthCard   = Color(0xFF0F1F3D);
const kAuthField  = Color(0xFF0E2040);

// ─── Shield Logo (Custom Painter) ────────────────────────────────────────────

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
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ShieldPainter(),
          ),
          Icon(Icons.security, color: Colors.white, size: iconSize),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.22)
      ..lineTo(w, h * 0.58)
      ..cubicTo(w, h * 0.82, w * 0.76, h * 0.96, w * 0.5, h)
      ..cubicTo(w * 0.24, h * 0.96, 0, h * 0.82, 0, h * 0.58)
      ..lineTo(0, h * 0.22)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, fillPaint);

    // outer glow
    final glowPaint = Paint()
      ..color = const Color(0x552196F3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(_ShieldPainter oldDelegate) => false;
}

// ─── Gradient Button (with press-scale animation) ─────────────────────────────

class GradientButton extends StatefulWidget {
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
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.loading ? null : widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kAuthCyan, kAuthBlue],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: kAuthCyan.withValues(alpha: _pressed ? 0.2 : 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.loading
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
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
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
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
            ),
          ),
        ],
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
    final t = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(color: t.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(prefixIcon, color: t.textMuted, size: 18),
            hintText: hintText,
            hintStyle: TextStyle(color: t.textMuted.withValues(alpha: 0.6), fontSize: 14),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: t.authField,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.authBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.authBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kAuthCyan, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
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
