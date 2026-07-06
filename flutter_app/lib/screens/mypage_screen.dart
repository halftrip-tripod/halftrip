import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../data/residence_options.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';

/// 마이페이지 (프로필·커뮤니티·내 정보·알림 설정·이용 안내·계정).
/// 디자인: halftrip-design/mypage.html
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  late NotificationSettings _settings;
  bool _marketing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = AppScope.of(context).currentUser!.notificationSettings;
  }

  Future<void> _save(NotificationSettings next) async {
    setState(() => _settings = next);
    await AppScope.of(context).updateSettings(next);
  }

  void _todo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).currentUser!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('마이페이지')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _ProfileCard(user: user, onEdit: () => _todo('프로필 편집은 준비 중이에요.')),
            const _GroupLabel('커뮤니티'),
            _MenuGroup(rows: [
              _MenuRow(
                icon: Icons.edit_outlined,
                label: '작성한 글',
                onTap: () => _todo('커뮤니티 연동 준비 중이에요.'),
              ),
              _MenuRow(
                icon: Icons.bookmark_outline_rounded,
                label: '저장한 글',
                onTap: () => _todo('커뮤니티 연동 준비 중이에요.'),
              ),
            ]),
            const _GroupLabel('내 정보'),
            _MenuGroup(rows: [
              _MenuRow(
                icon: Icons.place_outlined,
                label: '거주지',
                value: _shortResidence(user.residence),
                onTap: _changeResidence,
              ),
            ]),
            const _GroupLabel('알림 설정'),
            _MenuGroup(rows: [
              _ToggleRow(
                icon: Icons.notifications_none_rounded,
                label: '오픈 · 마감 알림',
                value: _settings.favoriteRegionPreopenAlert,
                onChanged: (v) => _save(
                    _settings.copyWith(favoriteRegionPreopenAlert: v)),
              ),
              _ToggleRow(
                icon: Icons.schedule_outlined,
                label: '정산 D-day 알림',
                value: _settings.tripEndSettlementAlert,
                onChanged: (v) =>
                    _save(_settings.copyWith(tripEndSettlementAlert: v)),
              ),
              _ToggleRow(
                icon: Icons.campaign_outlined,
                label: '혜택 · 마케팅 알림',
                value: _marketing,
                onChanged: (v) => setState(() => _marketing = v),
              ),
            ]),
            const _GroupLabel('이용 안내'),
            _MenuGroup(rows: [
              _MenuRow(
                  icon: Icons.campaign_outlined,
                  label: '공지사항',
                  onTap: () => _todo('준비 중이에요.')),
              _MenuRow(
                  icon: Icons.help_outline_rounded,
                  label: '자주 묻는 질문',
                  onTap: () => _todo('준비 중이에요.')),
              _MenuRow(
                  icon: Icons.description_outlined,
                  label: '이용약관',
                  onTap: () => _todo('준비 중이에요.')),
              _MenuRow(
                  icon: Icons.shield_outlined,
                  label: '개인정보 처리방침',
                  onTap: () => _todo('준비 중이에요.')),
              const _MenuRow(
                icon: Icons.info_outline_rounded,
                label: '버전 정보',
                value: '1.0.0',
              ),
            ]),
            const _GroupLabel('계정'),
            _MenuGroup(rows: [
              _MenuRow(
                icon: Icons.logout_rounded,
                label: '로그아웃',
                onTap: _confirmLogout,
              ),
              _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: '회원 탈퇴',
                danger: true,
                onTap: () => _todo('회원 탈퇴는 준비 중이에요.'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // 로그아웃 시 루트가 로그인 화면으로 전환되므로 마이페이지 스택을 닫는다.
    Navigator.of(context).pop();
    AppScope.of(context).logout();
  }

  /// 거주지 변경 — 시/도 → 시/군/구 순으로 고른 뒤 현재 사용자 거주지를 갱신한다.
  Future<void> _changeResidence() async {
    final province = await _pickOption(
      title: '시 / 도',
      options: residenceOptions.keys.toList(),
    );
    if (province == null || !mounted) return;

    final cities = residenceOptions[province] ?? const <String>[];
    final city = await _pickOption(title: '시 / 군 / 구', options: cities);
    if (city == null || !mounted) return;

    AppScope.of(context).updateResidence('$province $city');
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('거주지를 $province $city(으)로 바꿨어요.')));
  }

  Future<String?> _pickOption({
    required String title,
    required List<String> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ),
            ),
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                itemCount: options.length,
                itemBuilder: (_, index) {
                  final option = options[index];
                  return ListTile(
                    title: Text(option,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink9,
                        )),
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortResidence(String residence) {
  final first = residence.trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? '미설정' : first;
}

String _providerLabel(String authProvider) => switch (authProvider.toUpperCase()) {
      'KAKAO' => '카카오 계정으로 로그인됨',
      'NAVER' => '네이버 계정으로 로그인됨',
      'GOOGLE' => '구글 계정으로 로그인됨',
      _ => '로컬 계정으로 로그인됨',
    };

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isEmpty ? '나' : user.name.trim()[0];
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.p100,
              shape: BoxShape.circle,
            ),
            child: Text(initial,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.p700,
                )),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${user.name}님',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(_providerLabel(user.authProvider),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: AppColors.ink5,
                    )),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: const Row(
              children: [
                Text('편집',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink5,
                    )),
                Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Text(text,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink5,
          )),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: rows),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.ink9;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.ink5),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                )),
            const Spacer(),
            if (value != null)
              Text(value!,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5,
                  )),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.ink5),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink9,
                )),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.p500,
          ),
        ],
      ),
    );
  }
}
