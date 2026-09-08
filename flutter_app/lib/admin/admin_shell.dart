import 'package:flutter/material.dart';

import '../mock_ui/theme/app_colors.dart';
import 'admin_repository.dart';
import 'pages/dashboard_page.dart';
import 'pages/placeholder_page.dart';
import 'pages/regions_page.dart';
import 'pages/reports_page.dart';
import 'pages/users_page.dart';
import 'widgets/admin_ui.dart';

enum AdminMenu { dashboard, regions, reports, users, content, system }

extension AdminMenuInfo on AdminMenu {
  String get label => switch (this) {
        AdminMenu.dashboard => '대시보드',
        AdminMenu.regions => '지역 관리',
        AdminMenu.reports => '신고·차단',
        AdminMenu.users => '회원 관리',
        AdminMenu.content => '콘텐츠',
        AdminMenu.system => '시스템',
      };
  String get subtitle => switch (this) {
        AdminMenu.dashboard => '오늘 지표 · 상태 신호등 · 지역 현황',
        AdminMenu.regions => '상태·일정·조건을 여기서 바꾸면 앱에 바로 반영돼요',
        AdminMenu.reports => '대기 중인 신고를 처리하면 같은 대상 신고가 함께 닫혀요',
        AdminMenu.users => '검색 · 정지 · 닉네임 초기화 — 개인정보는 보이지 않아요',
        AdminMenu.content => '공지·FAQ·정책 문서 (S2에서 열려요)',
        AdminMenu.system => '배치·연동 상태·FCM 진단 (S3에서 열려요)',
      };
  IconData get icon => switch (this) {
        AdminMenu.dashboard => Icons.grid_view_rounded,
        AdminMenu.regions => Icons.location_on_outlined,
        AdminMenu.reports => Icons.flag_outlined,
        AdminMenu.users => Icons.people_outline_rounded,
        AdminMenu.content => Icons.article_outlined,
        AdminMenu.system => Icons.settings_outlined,
      };
  String? get soonTag => switch (this) { AdminMenu.content => 'S2', AdminMenu.system => 'S3', _ => null };
}

/// 좌측 사이드바 + 상단 바 + 페이지. 라우팅은 메뉴 enum 하나로 충분하다.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.repository, required this.onLogout});
  final AdminRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminMenu _menu = AdminMenu.dashboard;
  int _refreshTick = 0;
  int? _pendingReports;
  String? _userQuery;

  void _go(AdminMenu menu, {String? userQuery}) => setState(() {
        _menu = menu;
        _userQuery = userQuery;
        _refreshTick++;
      });

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(widget.repository.config.apiBaseUrl)?.host ?? '';
    final isProd = host.contains('onrender.com');
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(children: [
        _Sidebar(
          menu: _menu,
          pending: _pendingReports,
          loginId: widget.repository.session?.loginId ?? '',
          userId: widget.repository.session?.userId,
          onSelect: (m) => _go(m),
          onLogout: widget.onLogout,
        ),
        Expanded(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(32, 22, 32, 22),
              decoration: const BoxDecoration(color: AppColors.bg, border: Border(bottom: BorderSide(color: AppColors.line))),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_menu.label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.6, color: AppColors.ink9, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(_menu.subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink5)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: isProd ? AppColors.dangerTint : AppColors.mintTint, borderRadius: BorderRadius.circular(8)),
                  child: Text('${isProd ? '운영' : '로컬'} · $host', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isProd ? AppColors.danger : AppColors.mintDeep)),
                ),
                const SizedBox(width: 10),
                AdminButton('새로고침', small: true, variant: BtnVariant.ghost, icon: Icons.refresh_rounded, onTap: () => setState(() => _refreshTick++)),
              ]),
            ),
            Expanded(child: _page()),
          ]),
        ),
      ]),
    );
  }

  Widget _page() {
    final key = ValueKey('${_menu.name}-$_refreshTick');
    switch (_menu) {
      case AdminMenu.dashboard:
        return DashboardPage(
          key: key,
          repository: widget.repository,
          onLoaded: (d) => setState(() => _pendingReports = d.pendingReports),
          onOpenReports: () => _go(AdminMenu.reports),
          onOpenRegions: () => _go(AdminMenu.regions),
        );
      case AdminMenu.regions:
        return RegionsPage(key: key, repository: widget.repository);
      case AdminMenu.reports:
        return ReportsPage(
          key: key,
          repository: widget.repository,
          onPendingChanged: (n) => setState(() => _pendingReports = n),
          onOpenUser: (userId) => _go(AdminMenu.users, userQuery: '$userId'),
        );
      case AdminMenu.users:
        return UsersPage(key: key, repository: widget.repository, initialQuery: _userQuery, adminUserId: widget.repository.session?.userId);
      case AdminMenu.content:
        return const PlaceholderPage(key: ValueKey('content'), title: '콘텐츠는 S2에서 열려요', description: '공지사항·FAQ DB화 · 정책 문서 시행일 관리 · 커뮤니티 시드 글 표시');
      case AdminMenu.system:
        return const PlaceholderPage(key: ValueKey('system'), title: '시스템은 S3에서 열려요', description: '배치 즉시 실행·기록 · 외부 연동 상태 · FCM 진단 · 증빙 판정 일괄 재실행(집계)');
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.menu, required this.pending, required this.loginId, required this.userId, required this.onSelect, required this.onLogout});
  final AdminMenu menu;
  final int? pending;
  final String loginId;
  final int? userId;
  final ValueChanged<AdminMenu> onSelect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) => Container(
        width: 240,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: AppColors.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 22),
            child: Row(children: [
              Image.asset('assets/logo/app-icon-pin.png', width: 36, height: 36, filterQuality: FilterQuality.medium),
              const SizedBox(width: 8),
              const Text('하프트립', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.5, color: AppColors.ink9)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.p100)),
                child: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.p700)),
              ),
            ]),
          ),
          for (final m in AdminMenu.values) ...[
            if (m == AdminMenu.content)
              const Padding(padding: EdgeInsets.fromLTRB(12, 10, 12, 6), child: Text('다음 스프린트', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4))),
            _NavItem(menu: m, on: m == menu, badge: m == AdminMenu.reports ? pending : null, onTap: () => onSelect(m)),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.mintTint, borderRadius: BorderRadius.circular(11)), child: const Text('🧑‍💻', style: TextStyle(fontSize: 17))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loginId, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
                  Text('관리자 · userId ${userId ?? '-'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink5)),
                ]),
              ),
              Tooltip(message: '로그아웃', child: InkWell(onTap: onLogout, borderRadius: BorderRadius.circular(8), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.logout_rounded, size: 18, color: AppColors.ink5)))),
            ]),
          ),
        ]),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.menu, required this.on, required this.badge, required this.onTap});
  final AdminMenu menu;
  final bool on;
  final int? badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final soon = menu.soonTag;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: on ? AppColors.p500 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: on ? Colors.transparent : AppColors.surf,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: on ? BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x8C0EA5E9), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -6)]) : null,
            child: Opacity(
              opacity: soon != null && !on ? .6 : 1,
              child: Row(children: [
                Icon(menu.icon, size: 20, color: on ? Colors.white : AppColors.ink5),
                const SizedBox(width: 12),
                Text(menu.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2, color: on ? Colors.white : AppColors.ink7)),
                const Spacer(),
                if (badge != null && badge! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: .25) : AppColors.coralTint, borderRadius: BorderRadius.circular(99)),
                    child: Text('$badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.coralDeep)),
                  ),
                if (soon != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: .25) : AppColors.track, borderRadius: BorderRadius.circular(6)),
                    child: Text(soon, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.ink4)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
