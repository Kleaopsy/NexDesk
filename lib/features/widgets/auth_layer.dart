import 'dart:ui';
import 'package:flutter/material.dart';

class AuthLayer extends StatefulWidget {
  const AuthLayer({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "AuthLayer",
      barrierColor: Colors.black.withValues(alpha: 0.15),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const AuthLayer(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<AuthLayer> createState() => _AuthLayerState();
}

class _AuthLayerState extends State<AuthLayer> {
  // Controller to handle the sliding transition between Sign In and Sign Up
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        type: MaterialType.transparency,
        child: Container(
          width: 380,
          // Constrain height to wrap content naturally
          constraints: const BoxConstraints(maxHeight: 600),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceBright.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.15),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: PageView(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Disable manual swipe
                children: [
                  _buildSignInPage(cs, isDark),
                  _buildSignUpPage(cs, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI SCREENS ---

  Widget _buildSignInPage(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_person_rounded, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          Text("Welcome to NexDesk", style: _titleStyle(cs)),
          const SizedBox(height: 8),
          Text("Sign in to sync your projects.", style: _subStyle(cs)),
          const SizedBox(height: 32),
          _buildInput(
            label: "Email address",
            icon: Icons.mail_outline_rounded,
            cs: cs,
          ),
          const SizedBox(height: 12),
          _buildInput(
            label: "Password",
            icon: Icons.key_rounded,
            isPass: true,
            cs: cs,
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            "Sign In",
            cs,
            isDark,
            () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
          _buildToggleText("Don't have an account?", "Create one", cs, () {
            _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSignUpPage(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_rounded, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          Text("Join NexDesk", style: _titleStyle(cs)),
          const SizedBox(height: 8),
          Text("Start your journey with us today.", style: _subStyle(cs)),
          const SizedBox(height: 24),
          _buildInput(label: "Full Name", icon: Icons.face_rounded, cs: cs),
          const SizedBox(height: 12),
          _buildInput(
            label: "Email address",
            icon: Icons.mail_outline_rounded,
            cs: cs,
          ),
          const SizedBox(height: 12),
          _buildInput(
            label: "Password",
            icon: Icons.key_rounded,
            isPass: true,
            cs: cs,
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton("Create Account", cs, isDark, () {}),
          const SizedBox(height: 16),
          _buildToggleText("Already have an account?", "Sign In", cs, () {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  TextStyle _titleStyle(ColorScheme cs) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: cs.onSurface,
    letterSpacing: -0.5,
  );
  TextStyle _subStyle(ColorScheme cs) => TextStyle(
    fontSize: 13,
    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
  );

  Widget _buildInput({
    required String label,
    required IconData icon,
    bool isPass = false,
    required ColorScheme cs,
  }) {
    return TextField(
      obscureText: isPass,
      style: TextStyle(fontSize: 14, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, size: 18, color: cs.primary),
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
    String text,
    ColorScheme cs,
    bool isDark,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: isDark ? 0 : 4,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
        Text(
          info,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        TextButton(
          onPressed: onTap,
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
