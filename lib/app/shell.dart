import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/widgets/auth_layer.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/settings/settings_screen.dart';
import 'dart:io';

// Nav item data model
class _NavItem {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final Widget screen;
  const _NavItem(this.icon, this.iconActive, this.label, this.screen);
}

const _pages = [
  _NavItem(
    Icons.grid_view_outlined,
    Icons.grid_view_rounded,
    'Dashboard',
    DashboardScreen(),
  ),
  _NavItem(
    Icons.settings_outlined,
    Icons.settings_rounded,
    'Settings',
    SettingsScreen(),
  ),
];

// Tile height and spacing — used for indicator position math
const double _tileHeight = 36;
const double _tileSpacing = 2;
const double _sidebarPaddingV = 8;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Row(
        children: [
          _Sidebar(
            selected: _index,
            onSelect: (i) => setState(() => _index = i),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              // Slow down the animation for better visibility
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,

              transitionBuilder: (child, animation) {
                final slideAnimation = Tween<Offset>(
                  begin: const Offset(0.1, 0.0), // Çok hafif sağdan başla
                  end: Offset.zero,
                ).animate(animation);

                return SlideTransition(
                  position: slideAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },

              child: KeyedSubtree(
                key: ValueKey(_index),
                child: _pages[_index].screen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 180,
      margin: const EdgeInsets.fromLTRB(5, 5, 0, 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            SizedBox(height: Platform.isMacOS ? 40 : 10),
            const _SidebarHeader(),
            Expanded(
              child: _SidebarNav(selected: selected, onSelect: onSelect),
            ),
            const _SidebarFooter(),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final logo = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'N',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: cs.onPrimary,
          ),
        ),
      ),
    );

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'NexDesk',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav with sliding indicator ────────────────────────────────────────────────

class _SidebarNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _SidebarNav({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Indicator top offset: padding + (tileHeight + spacing) * index
    final indicatorTop =
        _sidebarPaddingV + selected * (_tileHeight + _tileSpacing);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            top: indicatorTop,
            left: 0,
            right: 0,
            height: _tileHeight,
            child: Container(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: _sidebarPaddingV),
            child: Column(
              children: List.generate(
                _pages.length,
                (i) => _NavTile(
                  item: _pages[i],
                  active: selected == i,
                  onTap: () => onSelect(i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual nav tile ───────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.active;

    return Padding(
      padding: const EdgeInsets.only(bottom: _tileSpacing),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          // Transparent background — indicator layer handles active color
          child: Container(
            height: _tileHeight,
            decoration: BoxDecoration(
              color: (!active && _hovered)
                  ? cs.surfaceContainerHigh.withValues(alpha: 0.65)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  active ? widget.item.iconActive : widget.item.icon,
                  size: 17,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? cs.primary : cs.onSurfaceVariant,
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

// ── Footer ────────────────────────────────────────────────────────────────────
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      // Listening to the global auth state
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final bool isLoggedIn = snapshot.hasData;

        // Dynamic Avatar Logic
        final Widget avatar = CircleAvatar(
          radius: 14,
          backgroundColor: cs.primaryContainer,
          backgroundImage: (isLoggedIn && user?.photoURL != null)
              ? NetworkImage(user!.photoURL!)
              : null,
          child: (!isLoggedIn || user?.photoURL == null)
              ? Icon(Icons.person, size: 16, color: cs.onPrimaryContainer)
              : null,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.25),
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLoggedIn
                          ? (user?.displayName ?? 'NexUser')
                          : 'Guest Mode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      isLoggedIn
                          ? (user?.email ?? 'Connected')
                          : 'Sign in to sync',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Action Button for Login/Logout
              IconButton(
                onPressed: () {
                  if (!isLoggedIn) {
                    // Calling our custom auth layer
                    AuthLayer.show(context);
                  } else {
                    // Show logout/profile menu
                    debugPrint("Profile menu open");
                  }
                },
                icon: Icon(
                  isLoggedIn ? Icons.more_vert : Icons.login_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
