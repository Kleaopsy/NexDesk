import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexdesk/features/widgets/auth_layer.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/myprojects/my_projects_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/archive/archive_screen.dart';
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
    Icons.rocket_launch_outlined,
    Icons.rocket_launch_rounded,
    'My Projects',
    ProjectsScreen(), // Firebase'den projeleri çekeceğimiz ana yer
  ),
  _NavItem(
    Icons.checklist_rtl_rounded,
    Icons.checklist_rounded,
    'Tasks',
    TasksScreen(), // Kanban veya liste görünümü
  ),
  _NavItem(
    Icons.sticky_note_2_outlined,
    Icons.sticky_note_2_rounded,
    'Quick Notes',
    NotesScreen(), // Kod parçacıkları veya fikirler için
  ),
  _NavItem(
    Icons.archive_outlined,
    Icons.archive_rounded,
    'Archive',
    ArchiveScreen(),
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
const double _sideBarWidth = 180;

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
              // Smooth transition between screens
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,

              transitionBuilder: (child, animation) {
                final slideAnimation = Tween<Offset>(
                  begin: const Offset(
                    0.1,
                    0.0,
                  ), // Start slightly from the right
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
      width: _sideBarWidth,
      margin: const EdgeInsets.fromLTRB(5, 5, 0, 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
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
            // Safe area adjustment for macOS title bar
            SizedBox(height: Platform.isMacOS ? 40 : 10),
            const _SidebarHeader(),
            Expanded(
              child: _SidebarNav(selected: selected, onSelect: onSelect),
            ),
            const _SidebarFooter(collapsed: false),
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
          // Background selection indicator
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
  final bool collapsed;

  const _SidebarFooter({required this.collapsed});

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Listen to authentication state changes in real-time
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final bool isLoggedIn = user != null;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 10 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
          ),
          child: isLoggedIn
              ? _buildUserView(
                  context,
                  cs,
                  user,
                ) // Show user profile if logged in
              : _buildLoginButton(context, cs), // Show sign-in button if not
        );
      },
    );
  }

  // UI shown when a user is authenticated
  Widget _buildUserView(BuildContext context, ColorScheme cs, User user) {
    final avatar = GestureDetector(
      onTap: () => _showMenu(context, cs),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: CircleAvatar(
          radius: 14,
          backgroundColor: cs.primaryContainer,
          child: Text(
            _initials(user.displayName ?? user.email ?? 'U'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );

    if (collapsed) return Center(child: avatar);

    return Row(
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _showMenu(context, cs),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.displayName ?? 'User',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email ?? '',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _showMenu(context, cs),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // UI shown when no user is authenticated
  Widget _buildLoginButton(BuildContext context, ColorScheme cs) {
    return InkWell(
      onTap: () {
        try {
          // Trigger the authentication layer
          AuthLayer.show(context);
        } catch (e) {
          // ignore: avoid_print
          print("Error opening AuthLayer: $e");
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(Icons.login_rounded, size: 18, color: cs.primary),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Text(
                "Sign In",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Extract initials from user name or email
  String _initials(String value) {
    final parts = value.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return value.isNotEmpty ? value[0].toUpperCase() : 'U';
  }

  // Show user settings/logout menu
  void _showMenu(BuildContext context, ColorScheme cs) {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    // showMenu yerine showGeneralDialog kullanarak animasyonu kendimiz yazıyoruz
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "UserMenu",
      barrierColor:
          Colors.transparent, // Arka planı karartma, sadece menü gözüksün
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        // Hafifçe yukarı kayma ve büyüme efekti (Scale & Slide)
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
        );

        return Stack(
          children: [
            Positioned(
              left: offset.dx,
              width: box
                  .size
                  .width, // Menu size for simple positioning, can be adjusted for better alignment
              bottom: (MediaQuery.of(context).size.height - offset.dy),
              child: FadeTransition(
                opacity: anim1,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
                  alignment:
                      Alignment.bottomLeft, // Menü alttan yukarı doğru büyür
                  child: Material(
                    color: cs.surface.withValues(
                      alpha: 0.95,
                    ), // Arka plan rengi
                    elevation: 12,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(14),
                    // Material içinde border: ... tanımlanamaz, o yüzden sildik.
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        // KENARLIĞI BURADA TANIMLIYORUZ
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuAction(
                            icon: Icons.logout_rounded,
                            label: 'Log out',
                            color: cs.error,
                            onTap: () {
                              Navigator.pop(context);
                              _handleLogout(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Menü öğeleri için yardımcı widget
  Widget _buildMenuAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
