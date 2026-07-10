import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../screens/mypage_screen.dart';
import '../../screens/notification_center_screen.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'community.dart';
import 'home_tab.dart';
import 'mall_tab.dart';
import 'my_trips_tab.dart';

/// 메인 셸 — 상단바(로고·알림·마이페이지) + 하단 4탭.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _tabs = [
    (Icons.home_outlined, '홈'),
    (Icons.work_outline_rounded, '내 여행'),
    (Icons.shopping_bag_outlined, '온라인몰'),
    (Icons.chat_bubble_outline_rounded, '커뮤니티'),
  ];

  @override
  void initState() {
    super.initState();
    AppState.I.tabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    AppState.I.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final t = AppState.I.tabRequest.value;
    if (t == null || !mounted) return;
    setState(() => _tab = t);
    AppState.I.tabRequest.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            _TopBar(),
            Expanded(
              child: IndexedStack(index: _tab, children: const [
                HomeTab(),
                MyTripsTab(),
                MallTab(),
                CommunityTab(),
              ]),
            ),
          ]),
        ),
        // 디자인 .bnav — 흰 배경, 상단 라운드 28, 아이콘+라벨 색만 전환.
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Color(0x0D0F172A), blurRadius: 18, offset: Offset(0, -4))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _tab = i),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_tabs[i].$1,
                            size: 24,
                            color: _tab == i ? AppColors.p600 : AppColors.ink4),
                        const SizedBox(height: 5),
                        Text(_tabs[i].$2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _tab == i ? AppColors.p600 : AppColors.ink4,
                            )),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnread());
  }

  Future<void> _loadUnread() async {
    try {
      final notifications =
          await AppScope.of(context).repository.getNotifications();
      if (!mounted) return;
      setState(() => _unread = notifications.where((n) => !n.read).length);
    } catch (_) {
      // 배지는 부가 정보 — 실패해도 조용히 넘어간다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 18, 6),
      child: Row(children: [
        Image.asset('assets/brand/logo.png', height: 27),
        const Spacer(),
        _IconButton(
          icon: Icons.notifications_none_rounded,
          badge: _unread > 0,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (_) => const NotificationCenterScreen()))
              .then((_) => _loadUnread()),
        ),
        const SizedBox(width: 10),
        _IconButton(
          icon: Icons.person_outline_rounded,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MyPageScreen())),
        ),
      ]),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap, this.badge = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.soft,
        ),
        child: Stack(alignment: Alignment.center, children: [
          Icon(icon, size: 22, color: AppColors.ink7),
          if (badge)
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
