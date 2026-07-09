import 'package:flutter/material.dart';

import '../screens/main_navigation_screen.dart';
import '../screens/mypage_screen.dart';
import '../screens/notification_center_screen.dart';
import '../theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.modeName,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.currentTabIndex,
    this.onTabSelected,
    this.showBackButton,
    this.onBackPressed,
    this.showBottomNavigation = true,
  });

  final String title;
  final String modeName;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final int? currentTabIndex;
  final ValueChanged<int>? onTabSelected;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;
  final bool showBottomNavigation;

  int _fallbackTabIndex() {
    final normalized = title.toLowerCase();
    if (normalized.contains('커뮤니티')) {
      return 3;
    }
    if (normalized.contains('몰')) {
      return 2;
    }
    if (normalized.contains('홈')) {
      return 0;
    }
    return 1;
  }

  void _handleFallbackTabSelected(BuildContext context, int index) {
    if (index == _fallbackTabIndex()) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(initialIndex: index),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final shouldShowBackButton = showBackButton ?? canPop;
    final selectedIndex = currentTabIndex ?? _fallbackTabIndex();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: shouldShowBackButton
            ? IconButton(
                onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              )
            : null,
        leadingWidth: shouldShowBackButton ? 56 : null,
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 90,
        titleSpacing: 0,
        title: _TopBar(
          actions: actions,
          showBackButton: shouldShowBackButton,
          showUtilityActions: showBottomNavigation,
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: child,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showBottomNavigation
          ? SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 18,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onTabSelected ??
                          (index) => _handleFallbackTabSelected(context, index),
                      height: 84,
                      backgroundColor: Colors.white,
                      indicatorColor: AppColors.p100,
                      shadowColor: Colors.transparent,
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: '홈',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.luggage_outlined),
                          selectedIcon: Icon(Icons.luggage_rounded),
                          label: '내 여행',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.storefront_outlined),
                          selectedIcon: Icon(Icons.storefront_rounded),
                          label: '온라인몰',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.forum_outlined),
                          selectedIcon: Icon(Icons.forum_rounded),
                          label: '커뮤니티',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    this.actions,
    required this.showBackButton,
    this.showUtilityActions = false,
  });

  final List<Widget>? actions;
  final bool showBackButton;
  final bool showUtilityActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: showBackButton ? 4 : 20, right: 8),
      child: Row(
        children: [
          const _BrandLogo(),
          const Spacer(),
          if (actions != null) ...actions!,
          if (showUtilityActions) ...[
            _TopIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: '알림',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const NotificationCenterScreen()),
              ),
            ),
            _TopIconButton(
              icon: Icons.person_outline_rounded,
              tooltip: '마이페이지',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MyPageScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: AppColors.ink7, size: 24),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/logo.png',
      height: 27,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink5,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
