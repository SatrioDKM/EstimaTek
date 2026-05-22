import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate blue background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // EstimaTek Logo Placeholder or Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assessment_outlined,
                    size: 60,
                    color: Color(0xFFFF6D00),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // App Title & Tagline
              const Text(
                'EstimaTek V2',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistem Estimasi Kontraktor Pintar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              
              // Auth State Listener and Builder
              BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is AuthLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6D00)),
                      ),
                    );
                  }
                  
                  return _GoogleSignInButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(SignInWithGoogleRequested());
                    },
                  );
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// Google Branding Guideline Compliant Button
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google Icon (Custom Canvas drawing or generic vector shape)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(
                    painter: _GoogleIconPainter(),
                  ),
                ),
                const SizedBox(width: 24),
                const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Draw the standard Google G Logo programmatically to avoid dependency on assets/images
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = w / 2;

    // Paint for Red
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    // Paint for Yellow
    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    // Paint for Green
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    // Paint for Blue
    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    // Outer Circle bounds
    final Rect rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Blue Path (Right side and bar)
    final Path bluePath = Path()
      ..moveTo(cx, cy)
      ..lineTo(w, cy)
      ..arcTo(rect, 0, 43 * 3.14159 / 180, false)
      ..lineTo(cx + r * 0.70, cy + r * 0.70)
      ..close();

    // Green Path (Bottom)
    final Path greenPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + r * 0.70, cy + r * 0.70)
      ..arcTo(rect, 43 * 3.14159 / 180, 117 * 3.14159 / 180, false)
      ..lineTo(cx, cy)
      ..close();

    // Yellow Path (Left)
    final Path yellowPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - r * 0.70, cy + r * 0.70)
      ..arcTo(rect, 160 * 3.14159 / 180, 80 * 3.14159 / 180, false)
      ..lineTo(cx, cy)
      ..close();

    // Red Path (Top)
    final Path redPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - r * 0.70, cy - r * 0.70)
      ..arcTo(rect, 240 * 3.14159 / 180, 120 * 3.14159 / 180, false)
      ..lineTo(cx, cy)
      ..close();

    // We can use a simpler drawing of the actual G logo that standard Google guidelines use.
    // Let's paint the arcs accurately.
    // A standard G logo consists of a cut circle with the right horizontal bar.
    
    // Draw using precise arc segments:
    // Red: top arc
    canvas.drawArc(rect, -3.14159 * 0.8, 3.14159 * 0.6, true, redPaint);
    // Yellow: left arc
    canvas.drawArc(rect, -3.14159 * 1.25, 3.14159 * 0.45, true, yellowPaint);
    // Green: bottom arc
    canvas.drawArc(rect, 3.14159 * 0.1, 3.14159 * 0.65, true, greenPaint);
    // Blue: right side and inner horizontal line
    canvas.drawArc(rect, -3.14159 * 0.2, 3.14159 * 0.3, true, bluePaint);
    
    final Path horizontalBar = Path()
      ..moveTo(cx, cy - r * 0.15)
      ..lineTo(w - r * 0.05, cy - r * 0.15)
      ..lineTo(w - r * 0.05, cy + r * 0.15)
      ..lineTo(cx, cy + r * 0.15)
      ..close();
    canvas.drawPath(horizontalBar, bluePaint);

    // Inner cutout to make it a 'G' instead of a full circle
    final Paint cutoutPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(cx, cy), r * 0.55, cutoutPaint);
    
    // Clear out the top right quadrant between bar and top arc
    final Path gapPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + r * 0.6, cy - r * 0.6)
      ..lineTo(cx + r * 0.8, cy - r * 0.1)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(gapPath, cutoutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
