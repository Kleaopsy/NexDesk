import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// Auth pages enum
enum _AuthPage { signIn, signUp, forgotPassword, verifyCode, resetPassword }

class AuthLayer extends StatefulWidget {
  const AuthLayer({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AuthLayer',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, anim1, anim2) => const AuthLayer(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<AuthLayer> createState() => _AuthLayerState();
}

class _AuthLayerState extends State<AuthLayer> {
  final PageController _pageController = PageController();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // Countdown timer for verification code
  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _resetEmailController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Navigate to a page with slide direction
  void _goTo(_AuthPage page) {
    setState(() {
      _errorMessage = null;
    });
    final index = _AuthPage.values.indexOf(page);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  // ── Password validation ────────────────────────────────────────────────────

  String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]')))
      // ignore: curly_braces_in_flow_control_structures
      return 'Must contain at least one lowercase letter.';
    if (!password.contains(RegExp(r'[0-9]')))
      // ignore: curly_braces_in_flow_control_structures
      return 'Must contain at least one number.';
    return null;
  }

  // ── Sign In ────────────────────────────────────────────────────────────────

  Future<void> _handleSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────────────────

  Future<void> _handleSignUp() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Full name is required.');
      return;
    }
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    final pwError = _validatePassword(_passwordController.text);
    if (pwError != null) {
      setState(() => _errorMessage = pwError);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 1. wait for user creation, then immediately update the display name
      await credential.user?.updateDisplayName(_nameController.text.trim());

      // 2. Critical step: reload the user to ensure the new display name is fetched
      await credential.user?.reload();

      // 3. user.reload() updates the currentUser in FirebaseAuth, so we can now pop the auth layer
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Forgot Password — send email ───────────────────────────────────────────

  Future<void> _handleSendResetEmail() async {
    if (_resetEmailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _resetEmailController.text.trim(),
      );
      _startCountdown();
      _goTo(_AuthPage.verifyCode);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Countdown timer ────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── Verify code & go to reset ──────────────────────────────────────────────
  // Firebase handles reset via email link — we just navigate forward
  void _handleVerifyCode() {
    if (_codeController.text.trim().isEmpty) {
      setState(
        () =>
            _errorMessage = 'Please check your email and click the reset link.',
      );
      return;
    }
    setState(() => _errorMessage = null);
    _goTo(_AuthPage.resetPassword);
  }

  // ── Reset Password ─────────────────────────────────────────────────────────

  Future<void> _handleResetPassword() async {
    final pwError = _validatePassword(_passwordController.text);
    if (pwError != null) {
      setState(() => _errorMessage = pwError);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(
        _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark
        ? cs.surfaceBright.withValues(alpha: 0.55)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : cs.outlineVariant.withValues(alpha: 0.4);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          constraints: const BoxConstraints(minHeight: 480, maxHeight: 700),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 48,
                spreadRadius: -4,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: isDark
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: _buildPageView(cs, isDark),
                  )
                : _buildPageView(cs, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildPageView(ColorScheme cs, bool isDark) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          // Şu anki sayfa indexine göre ilgili fonksiyonu çağırıyoruz
          final currentPage = _pageController.page?.round() ?? 0;

          if (_isLoading) return; // Yükleniyorsa işlem yapma

          switch (currentPage) {
            case 0:
              _handleSignIn();
              break;
            case 1:
              _handleSignUp();
              break;
            case 2:
              _handleSendResetEmail();
              break;
            case 3:
              _handleVerifyCode();
              break;
            case 4:
              _handleResetPassword();
              break;
          }
        },
      },
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildSignInPage(cs, isDark),
          _buildSignUpPage(cs, isDark),
          _buildForgotPasswordPage(cs, isDark),
          _buildVerifyCodePage(cs, isDark),
          _buildResetPasswordPage(cs, isDark),
        ],
      ),
    );
  }

  // ── Sign In Page ───────────────────────────────────────────────────────────

  Widget _buildSignInPage(ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _buildIconBadge(Icons.lock_person_rounded, cs),
          const SizedBox(height: 20),
          Text('Welcome to NexDesk', style: _titleStyle(cs)),
          const SizedBox(height: 6),
          Text('Sign in to sync your projects.', style: _subStyle(cs)),
          const SizedBox(height: 28),
          _buildInput(
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            controller: _emailController,
            cs: cs,
          ),
          const SizedBox(height: 10),
          _buildInput(
            label: 'Password',
            icon: Icons.key_rounded,
            controller: _passwordController,
            isPass: true,
            cs: cs,
          ),
          // Forgot password link
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _goTo(_AuthPage.forgotPassword),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot password?',
                style: TextStyle(fontSize: 12, color: cs.primary),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            _buildErrorBanner(cs),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 16),
          _buildPrimaryButton(
            _isLoading ? 'Signing in...' : 'Sign In',
            cs,
            () => _handleSignIn(),
          ),
          const SizedBox(height: 14),
          _buildToggleText(
            "Don't have an account?",
            'Create one',
            cs,
            () => _goTo(_AuthPage.signUp),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Sign Up Page ───────────────────────────────────────────────────────────

  Widget _buildSignUpPage(ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _buildIconBadge(Icons.person_add_rounded, cs),
          const SizedBox(height: 20),
          Text('Join NexDesk', style: _titleStyle(cs)),
          const SizedBox(height: 6),
          Text('Start your journey with us today.', style: _subStyle(cs)),
          const SizedBox(height: 24),
          _buildInput(
            label: 'Full Name *',
            icon: Icons.face_rounded,
            controller: _nameController,
            cs: cs,
          ),
          const SizedBox(height: 10),
          _buildInput(
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            controller: _emailController,
            cs: cs,
          ),
          const SizedBox(height: 10),
          _buildInput(
            label: 'Password',
            icon: Icons.key_rounded,
            controller: _passwordController,
            isPass: true,
            cs: cs,
          ),
          const SizedBox(height: 10),
          _buildInput(
            label: 'Confirm Password',
            icon: Icons.key_rounded,
            controller: _confirmPasswordController,
            isPass: true,
            cs: cs,
          ),
          // Password requirements hint
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Min. 8 chars · uppercase · lowercase · number',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            _buildErrorBanner(cs),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 20),
          _buildPrimaryButton(
            _isLoading ? 'Creating...' : 'Create Account',
            cs,
            () => _handleSignUp(),
          ),
          const SizedBox(height: 14),
          _buildToggleText(
            'Already have an account?',
            'Sign In',
            cs,
            () => _goTo(_AuthPage.signIn),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Forgot Password Page ───────────────────────────────────────────────────

  Widget _buildForgotPasswordPage(ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _buildIconBadge(Icons.lock_reset_rounded, cs),
          const SizedBox(height: 20),
          Text('Reset Password', style: _titleStyle(cs)),
          const SizedBox(height: 6),
          Text(
            "Enter your email and we'll send you a reset link.",
            style: _subStyle(cs),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _buildInput(
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            controller: _resetEmailController,
            cs: cs,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(cs),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 24),
          _buildPrimaryButton(
            _isLoading ? 'Sending...' : 'Send Reset Link',
            cs,
            () => _handleSendResetEmail(),
          ),
          const SizedBox(height: 14),
          _buildToggleText(
            'Remembered your password?',
            'Sign In',
            cs,
            () => _goTo(_AuthPage.signIn),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Verify Code Page ───────────────────────────────────────────────────────

  Widget _buildVerifyCodePage(ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _buildIconBadge(Icons.mark_email_read_rounded, cs),
          const SizedBox(height: 20),
          Text('Check Your Email', style: _titleStyle(cs)),
          const SizedBox(height: 6),
          Text(
            'We sent a reset link to\n${_resetEmailController.text.trim()}',
            style: _subStyle(cs),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Countdown badge
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _countdown > 0
                ? Container(
                    key: const ValueKey('countdown'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Resend available in ${_countdown}s',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : TextButton.icon(
                    key: const ValueKey('resend'),
                    onPressed: () => _handleSendResetEmail(),
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: cs.primary,
                    ),
                    label: Text(
                      'Resend email',
                      style: TextStyle(fontSize: 13, color: cs.primary),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          // Confirmation input — user confirms they received the email
          _buildInput(
            label: 'Type "confirmed" when done',
            icon: Icons.check_circle_outline_rounded,
            controller: _codeController,
            cs: cs,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(cs),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 24),
          _buildPrimaryButton('Continue', cs, () => _handleVerifyCode()),
          const SizedBox(height: 14),
          _buildToggleText(
            'Wrong email?',
            'Go back',
            cs,
            () => _goTo(_AuthPage.forgotPassword),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Reset Password Page ────────────────────────────────────────────────────

  Widget _buildResetPasswordPage(ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _buildIconBadge(Icons.lock_open_rounded, cs),
          const SizedBox(height: 20),
          Text('New Password', style: _titleStyle(cs)),
          const SizedBox(height: 6),
          Text(
            'Choose a strong password for your account.',
            style: _subStyle(cs),
          ),
          const SizedBox(height: 28),
          _buildInput(
            label: 'New Password',
            icon: Icons.key_rounded,
            controller: _passwordController,
            isPass: true,
            cs: cs,
          ),
          const SizedBox(height: 10),
          _buildInput(
            label: 'Confirm New Password',
            icon: Icons.key_rounded,
            controller: _confirmPasswordController,
            isPass: true,
            cs: cs,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Min. 8 chars · uppercase · lowercase · number',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            _buildErrorBanner(cs),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 20),
          _buildPrimaryButton(
            _isLoading ? 'Saving...' : 'Save Password',
            cs,
            () => _handleResetPassword(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildIconBadge(IconData icon, ColorScheme cs) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 26, color: cs.primary),
    );
  }

  TextStyle _titleStyle(ColorScheme cs) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: cs.onSurface,
    letterSpacing: -0.4,
  );

  TextStyle _subStyle(ColorScheme cs) =>
      TextStyle(fontSize: 13, color: cs.onSurfaceVariant);

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPass = false,
    required ColorScheme cs,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      style: TextStyle(fontSize: 14, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, size: 18, color: cs.primary),
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
    String text,
    ColorScheme cs,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildToggleText(
    String info,
    String action,
    ColorScheme cs,
    VoidCallback onTap,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(info, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ),
      ],
    );
  }
}
