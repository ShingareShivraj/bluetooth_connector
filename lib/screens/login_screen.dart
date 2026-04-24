import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'scan_screen.dart';
class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ─── Constants ────────────────────────────────────────────────────────────────

class AppColors {
  static const tealDark = Color(0xFF0AADA8);
  static const tealMid = Color(0xFF1DBFB8);
  static const tealLight = Color(0xFF2ED8CE);
  static const tealBg = Color(0xFF8FD8D5);
  static const white = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFFFFFFF);
  static const inputBg = Color(0xFFF5F7FA);
  static const textDark = Color(0xFF1A1F36);
  static const textMedium = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);
  static const tealAccent = Color(0xFF0AADA8);
  static const dividerColor = Color(0xFFE5E7EB);
  static const checkboxBorder = Color(0xFFD1D5DB);
  static const appleDark = Color(0xFF1C1C1E);
  static const googleBorder = Color(0xFFE2E8F0);
  static const shadowColor = Color(0x1A000000);
  static const overlayWhite = Color(0x1AFFFFFF);
  static const overlayWhiteMed = Color(0x26FFFFFF);
}

class AppTextStyles {
  static const headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const headingAccent = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.tealLight,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const cardTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: -0.5,
  );

  static const bodyRegular = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    letterSpacing: 0.1,
  );

  static const linkStyle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: AppColors.tealAccent,
    letterSpacing: 0.1,
  );

  static const inputText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
    letterSpacing: 0.1,
  );

  static const hintText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
  );

  static const buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: 0.3,
  );

  static const dividerText = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
    letterSpacing: 0.5,
  );

  static const socialText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    letterSpacing: 0.1,
  );

  static const socialTextLight = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0.1,
  );

  static const checkboxLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );

  static const forgotPassword = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.tealAccent,
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;
  final _usernameController = TextEditingController(text: '');
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDark,
      body: Stack(
        children: [
          // Gradient background
          const _GradientBackground(),
          // Abstract decorative shapes
          const _BackgroundShapes(),
          // Main content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top hero section
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 20, 24, 0),
                    child: _HeroSection(),
                  ),
                ),
                // Login card
                Expanded(
                  flex: 7,
                  child: _LoginCard(
                    rememberMe: _rememberMe,
                    onRememberMeChanged: (val) =>
                        setState(() => _rememberMe = val ?? false),
                    // usernameController: _usernameController,
                    passwordController: _passwordController,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient Background ──────────────────────────────────────────────────────

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07B5AF),
            Color(0xFF0AADA8),
            Color(0xFF13C4BC),
            Color(0xFF7DD8D6),
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        ),
      ),
    );
  }
}

// ─── Background Shapes ────────────────────────────────────────────────────────

class _BackgroundShapes extends StatelessWidget {
  const _BackgroundShapes();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: Stack(
        children: [
          // Large gear bottom-left
          Positioned(
            left: -30,
            bottom: size.height * 0.38,
            child: Opacity(
              opacity: 0.15,
              child: _GearIcon(size: 110, color: AppColors.white),
            ),
          ),
          // Small gear offset
          Positioned(
            left: 60,
            bottom: size.height * 0.44,
            child: Opacity(
              opacity: 0.10,
              child: _GearIcon(size: 60, color: AppColors.white),
            ),
          ),
          // Circle top right
          Positioned(
            right: -40,
            top: -40,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          // Small circle mid-right
          Positioned(
            right: 30,
            top: 80,
            child: Opacity(
              opacity: 0.10,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          // Decorative ring
          Positioned(
            right: 20,
            bottom: size.height * 0.52,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 8),
                ),
              ),
            ),
          ),
          // Mockup phone frame hint
          Positioned(
            right: -18,
            top: size.height * 0.04,
            child: Opacity(
              opacity: 0.22,
              child: _PhoneMockupHint(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GearIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _GearIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GearPainter(color: color),
    );
  }
}

class _GearPainter extends CustomPainter {
  final Color color;
  _GearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.45;
    final innerRadius = size.width * 0.28;
    final toothCount = 8;
    final toothDepth = size.width * 0.10;

    final path = Path();
    for (int i = 0; i < toothCount; i++) {
      final angle1 = (2 * math.pi * i / toothCount) - math.pi / toothCount * 0.6;
      final angle2 = (2 * math.pi * i / toothCount) + math.pi / toothCount * 0.6;
      final angle3 = angle2 + math.pi / toothCount * 0.2;
      final angle4 = (2 * math.pi * (i + 1) / toothCount) - math.pi / toothCount * 0.8;

      if (i == 0) {
        path.moveTo(
          center.dx + (outerRadius + toothDepth) * math.cos(angle1),
          center.dy + (outerRadius + toothDepth) * math.sin(angle1),
        );
      }
      path.lineTo(
        center.dx + (outerRadius + toothDepth) * math.cos(angle2),
        center.dy + (outerRadius + toothDepth) * math.sin(angle2),
      );
      path.lineTo(
        center.dx + outerRadius * math.cos(angle3),
        center.dy + outerRadius * math.sin(angle3),
      );
      path.lineTo(
        center.dx + outerRadius * math.cos(angle4),
        center.dy + outerRadius * math.sin(angle4),
      );
      path.lineTo(
        center.dx + (outerRadius + toothDepth) * math.cos(angle4 + math.pi / toothCount * 0.2),
        center.dy + (outerRadius + toothDepth) * math.sin(angle4 + math.pi / toothCount * 0.2),
      );
    }
    path.close();
    canvas.drawPath(path, paint);

    // Center hole
    canvas.drawCircle(center, innerRadius, Paint()..color = AppColors.tealDark.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(_GearPainter old) => false;
}

class _PhoneMockupHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 55,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Icon(Icons.task_alt_rounded, color: Colors.white.withOpacity(0.5), size: 28),
        ],
      ),
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App logo / brand mark
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.overlayWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.overlayWhiteMed, width: 1),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.white,
            size: 22,
          ),
        ),
        const SizedBox(height: 22),
        // Heading with teal accent
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Log in to stay on\n',
                style: AppTextStyles.headingLarge,
              ),
              TextSpan(
                text: 'top of ',
                style: AppTextStyles.headingAccent,
              ),
              TextSpan(
                text: 'your tasks\nand projects.',
                style: AppTextStyles.headingLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Login Card ───────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  final bool rememberMe;
  final ValueChanged<bool?> onRememberMeChanged;
  // final TextEditingController usernameController;
  final TextEditingController passwordController;

  const _LoginCard({
    required this.rememberMe,
    required this.onRememberMeChanged,
    // required this.usernameController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 40,
            spreadRadius: 0,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            const _CardHeader(),
            const SizedBox(height: 26),
            // Username field
            _InputField(
              // controller: usernameController,
              hint: 'Username',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            // Email field
            _InputField(
              //controller: emailController,
              hint: 'Enter your password',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Remember me + forgot password
            _OptionsRow(
              rememberMe: rememberMe,
              onChanged: onRememberMeChanged,
            ),
            const SizedBox(height: 22),
            // Login button
            const _LoginButton(),
            const SizedBox(height: 20),
            // Divider
            const _OrDivider(),
            const SizedBox(height: 18),
            // Social buttons
            //const _SocialButtons(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Card Header ──────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Login', style: AppTextStyles.cardTitle),
        const SizedBox(height: 6),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: "Don't Have An Account? ",
                style: AppTextStyles.bodyRegular,
              ),
              TextSpan(
                text: 'Sign Up',
                style: AppTextStyles.linkStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Input Field ──────────────────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  //final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isPassword;

  const _InputField({
   // required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F2F5), width: 1),
      ),
      child: TextField(
        //controller: widget.controller,
        keyboardType: widget.keyboardType,
        obscureText: widget.isPassword ? _obscureText : false,
        style: AppTextStyles.inputText,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTextStyles.hintText,

          // LEFT ICON
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              widget.icon,
              color: AppColors.textLight,
              size: 20,
            ),
          ),

          // RIGHT ICON (SHOW/HIDE PASSWORD)
          suffixIcon: widget.isPassword
              ? IconButton(
            icon: Icon(
              _obscureText
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: AppColors.textLight,
            ),
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
          )
              : null,

          prefixIconConstraints: const BoxConstraints(minWidth: 52),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          isDense: true,
        ),
      ),
    );
  }
}

// ─── Options Row (Remember Me + Forgot Password) ──────────────────────────────

class _OptionsRow extends StatelessWidget {
  final bool rememberMe;
  final ValueChanged<bool?> onChanged;

  const _OptionsRow({required this.rememberMe, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Custom checkbox
        GestureDetector(
          onTap: () => onChanged(!rememberMe),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: rememberMe ? AppColors.tealAccent : AppColors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: rememberMe
                        ? AppColors.tealAccent
                        : AppColors.checkboxBorder,
                    width: 1.5,
                  ),
                ),
                child: rememberMe
                    ? const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: AppColors.white,
                )
                    : null,
              ),
              const SizedBox(width: 8),
              const Text('Remember Me', style: AppTextStyles.checkboxLabel),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: const Text('Forgot Password?', style: AppTextStyles.forgotPassword),
        ),
      ],
    );
  }
}

// ─── Login Button ─────────────────────────────────────────────────────────────

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanScreen(),
          ),
        );
      },
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0DC4BD), Color(0xFF08A09A)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Login', style: AppTextStyles.buttonText),
        ),
      ),
    );
  }
}

// ─── Or Divider ───────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.dividerColor,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text('Or Continue With', style: AppTextStyles.dividerText),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.dividerColor,
          ),
        ),
      ],
    );
  }
}

// ─── Social Buttons ───────────────────────────────────────────────────────────

class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Apple button
        Expanded(
          child: _SocialButton(
            label: 'Apple',
            icon: _AppleIcon(),
            backgroundColor: AppColors.appleDark,
            textStyle: AppTextStyles.socialTextLight,
            borderColor: AppColors.appleDark,
          ),
        ),
        const SizedBox(width: 14),
        // Google button
        Expanded(
          child: _SocialButton(
            label: 'Google',
            icon: _GoogleIcon(),
            backgroundColor: AppColors.white,
            textStyle: AppTextStyles.socialText,
            borderColor: AppColors.googleBorder,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color backgroundColor;
  final TextStyle textStyle;
  final Color borderColor;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textStyle,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

// ─── Apple Icon ───────────────────────────────────────────────────────────────

class _AppleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.apple_rounded,
      color: AppColors.white,
      size: 20,
    );
  }
}

// ─── Google Icon ──────────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Draw G shape using arcs and rects
    final red = Paint()..color = const Color(0xFFEA4335);
    final blue = Paint()..color = const Color(0xFF4285F4);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final green = Paint()..color = const Color(0xFF34A853);

    // Background circle
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.85);

    // Blue arc (right side)
    canvas.drawArc(rect, -0.35, 1.45, false, Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = r * 0.28
      ..style = PaintingStyle.stroke);

    // Green arc (bottom right)
    canvas.drawArc(rect, 1.1, 1.1, false, Paint()
      ..color = const Color(0xFF34A853)
      ..strokeWidth = r * 0.28
      ..style = PaintingStyle.stroke);

    // Yellow arc (bottom left)
    canvas.drawArc(rect, 2.2, 0.9, false, Paint()
      ..color = const Color(0xFFFBBC05)
      ..strokeWidth = r * 0.28
      ..style = PaintingStyle.stroke);

    // Red arc (top)
    canvas.drawArc(rect, 3.1, 1.1, false, Paint()
      ..color = const Color(0xFFEA4335)
      ..strokeWidth = r * 0.28
      ..style = PaintingStyle.stroke);

    // White horizontal bar for the G
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.78, r * 0.26),
      Paint()..color = Colors.white,
    );

    // White center
    canvas.drawCircle(Offset(cx, cy), r * 0.52, Paint()..color = Colors.white);

    // Blue right notch indicator
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.78, r * 0.26),
      blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}