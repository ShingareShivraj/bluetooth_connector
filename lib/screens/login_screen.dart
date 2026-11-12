
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'scan_screen.dart';
import '../services/auth_service.dart';
import 'login_viewmodel.dart';

// --------------------------------------------------
// COMPATIBILITY ENTRY POINT
// MaterialApp remains in main.dart.
// --------------------------------------------------

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}

// --------------------------------------------------
// APP COLORS
// --------------------------------------------------

class AppColors {
  static const background = Color(0xFF080808);
  static const backgroundLight = Color(0xFF11100F);

  static const cardBg = Color(0xFF151412);
  static const inputBg = Color(0xFF201E1A);

  static const gold = Color(0xFFFFA21A);
  static const goldLight = Color(0xFFFFC46B);
  static const goldDark = Color(0xFFD97808);

  static const white = Color(0xFFFFFFFF);
  static const textMedium = Color(0xFFAAA39A);
  static const textLight = Color(0xFF77716A);

  static const border = Color(0xFF37332C);
  static const error = Color(0xFFFF7777);
}

// --------------------------------------------------
// LOGIN SCREEN
// --------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = true;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late final LoginViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = LoginViewModel(context.read<AuthService>());
  }

  // ------------------------------------------------
  // EXISTING LOGIN LOGIC - UNCHANGED
  // ------------------------------------------------

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    final success = await _vm.signIn(
      _usernameController.text,
      _passwordController.text,
      _rememberMe,
    );

    if (!mounted || !success) return;

    _passwordController.clear();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ScanScreen(),
      ),
          (_) => false,
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------
  // MAIN UI
  // ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Background
              const _PremiumBackground(),

              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 430,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 22,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // BRAND
                                  const _BrandSection(),

                                  const SizedBox(height: 36),

                                  // LOGIN FORM
                                  _LoginCard(
                                    rememberMe: _rememberMe,
                                    onRememberMeChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    usernameController:
                                    _usernameController,
                                    passwordController:
                                    _passwordController,
                                    busy: _vm.busy,
                                    error: _vm.error,
                                    onSubmit: _signIn,
                                  ),

                                  const SizedBox(height: 24),

                                  // MUG ILLUSTRATION
                                  const _MugFooter(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------
// PREMIUM BACKGROUND
// --------------------------------------------------

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF15110B),
            Color(0xFF0B0A09),
            Color(0xFF080808),
          ],
          stops: [0.0, 0.38, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Subtle top golden glow
          Positioned(
            top: -160,
            left: -80,
            right: -80,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withOpacity(0.10),
                    AppColors.gold.withOpacity(0.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Subtle bottom glow
          Positioned(
            bottom: -180,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withOpacity(0.055),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// BRAND SECTION
// --------------------------------------------------

class _BrandSection extends StatelessWidget {
  const _BrandSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Flame Logo
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.gold.withOpacity(0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.13),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: ClipRect(
              child: Transform.scale(
                scale: 2.0,
                child: Image.asset(
                  'assets/images/flames.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 17),

        // Brand name
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Gram ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 35,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.3,
                ),
              ),
              TextSpan(
                text: 'Mug',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 35,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.3,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 7),

        // Tagline
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 25,
              height: 1,
              color: AppColors.gold.withOpacity(0.65),
            ),
            const SizedBox(width: 10),
            const Text(
              'Keep Your Drink Hot, For Longer',
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 25,
              height: 1,
              color: AppColors.gold.withOpacity(0.65),
            ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------
// LOGIN CARD
// --------------------------------------------------

class _LoginCard extends StatelessWidget {
  final bool rememberMe;
  final ValueChanged<bool?> onRememberMeChanged;

  final TextEditingController usernameController;
  final TextEditingController passwordController;

  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  const _LoginCard({
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.usernameController,
    required this.passwordController,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(23, 26, 23, 25),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 35,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.gold.withOpacity(0.025),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            const Text(
              'Welcome Back',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Sign in with your account to continue.',
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 12,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 27),

            // USERNAME LABEL
            const _FieldLabel(
              text: 'EMAIL OR USERNAME',
            ),

            const SizedBox(height: 10),

            // USERNAME FIELD
            _InputField(
              controller: usernameController,
              hint: 'Enter your email or username',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 21),

            // PASSWORD LABEL
            const _FieldLabel(
              text: 'PASSWORD',
            ),

            const SizedBox(height: 10),

            // PASSWORD FIELD
            _InputField(
              controller: passwordController,
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
            ),

            const SizedBox(height: 16),

            // REMEMBER ME
            Row(
              children: [
                SizedBox(
                  width: 21,
                  height: 21,
                  child: Checkbox(
                    value: rememberMe,
                    onChanged: busy ? null : onRememberMeChanged,
                    activeColor: AppColors.gold,
                    checkColor: Colors.black,
                    side: const BorderSide(
                      color: AppColors.textLight,
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                  ),
                ),

                const SizedBox(width: 9),

                const Text(
                  'Keep me signed in',
                  style: TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // BACKEND ERROR
            if (error != null) ...[
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 26),

            // SIGN IN BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFFC15C),
                      Color(0xFFFFA21A),
                      Color(0xFFE9890A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.19),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: busy ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.black54,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// FIELD LABEL
// --------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD2C9BB),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
      ),
    );
  }
}

// --------------------------------------------------
// INPUT FIELD
// --------------------------------------------------

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isPassword;

  const _InputField({
    required this.controller,
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
      height: 55,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        obscureText: widget.isPassword ? _obscureText : false,
        autofillHints: widget.isPassword
            ? const [AutofillHints.password]
            : const [AutofillHints.username],
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: AppColors.gold,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),

          // LEFT ICON
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: 15,
              right: 11,
            ),
            child: Icon(
              widget.icon,
              color: AppColors.goldDark,
              size: 19,
            ),
          ),

          // PASSWORD VISIBILITY
          suffixIcon: widget.isPassword
              ? IconButton(
            onPressed: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
            icon: Icon(
              _obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textMedium,
              size: 19,
            ),
          )
              : null,

          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
          ),

          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,

          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 4,
          ),

          isDense: true,
        ),
      ),
    );
  }
}

// --------------------------------------------------
// BOTTOM MUG ILLUSTRATION
// --------------------------------------------------

class _MugFooter extends StatelessWidget {
  const _MugFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/mug_outline.png',
          width: 92,
          height: 85,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),

        const SizedBox(height: 7),

        const Text(
          'CRAFTED FOR EVERY PERFECT SIP',
          style: TextStyle(
            color: Color(0xFF71665A),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
