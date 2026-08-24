import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'community.dart';
import 'home_tab.dart';
import 'mall_tab.dart';
import 'my_trips_tab.dart';

/// 메인 셸 — 하단 4탭. (상단바는 홈 탭 전용으로 이동, 8/6)
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
    // 커뮤니티 내 글·반응 로컬 복원 (서버 J 전까지 기기 유지).
    AppState.I.restoreCommunity();
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
        // 상단바(로고·알림·마이페이지)는 홈 탭 전용으로 이동(8/6) —
        // 다른 탭은 자체 타이틀이 있어 헤더 없이 콘텐츠부터 시작한다.
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _tab, children: const [
            HomeTab(),
            MyTripsTab(),
            MallTab(),
            CommunityTab(),
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
