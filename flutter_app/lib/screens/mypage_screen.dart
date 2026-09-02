import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../mock_ui/screens/community.dart' show MyReviewsScreen, SavedPostsScreen;
import '../data/residence_options.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../utils/profile_presets.dart';
import '../widgets/ui/app_card.dart';
import 'info_screens.dart';
import 'profile_edit_screen.dart';

/// 마이페이지 (프로필·커뮤니티·내 정보·알림 설정·이용 안내·계정).
/// 디자인: halftrip-design/mypage.html
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  late NotificationSettings _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그아웃 직후에는 currentUser가 null인 채로 이 화면의 팝 전환이 끝나기를
    // 기다리는 프레임이 있다(로그아웃이 팝 뒤 320ms에 실행되는데 전환이 그보다
    // 길 수 있다). 여기서 !로 터뜨리면 그 프레임의 빌드 예외가 로그에 남고
    // 전환이 지저분해진다 — null이면 그리지 않는 게 맞다.
    final user = AppScope.of(context).currentUser;
    if (user != null) {
      _settings = user.notificationSettings;
    }
  }

  Future<void> _save(NotificationSettings next) async {
    setState(() => _settings = next);
    await AppScope.of(context).updateSettings(next);
  }


  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).currentUser;
    // 로그아웃 팝 전환 중 마지막 프레임 — 그리지 말고 조용히 사라진다.
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('마이페이지')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _ProfileCard(user: user, onEdit: _editProfile),
            const _GroupLabel('커뮤니티'),
            _MenuGroup(rows: [
              _MenuRow(
                icon: Icons.edit_outlined,
                label: '작성한 글',
                onTap: () => _push(const MyReviewsScreen()),
              ),
              _MenuRow(
                icon: Icons.bookmark_outline_rounded,
                label: '저장한 글',
                onTap: () => _push(const SavedPostsScreen()),
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
                icon: Icons.place_outlined,
                label: '관심 지역 오픈 · 마감 알림',
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
            ]),
            const _GroupLabel('이용 안내'),
            _MenuGroup(rows: [
              _MenuRow(
                  icon: Icons.campaign_outlined,
                  label: '공지사항',
                  onTap: () => _push(const NoticeScreen())),
              _MenuRow(
                  icon: Icons.help_outline_rounded,
                  label: '자주 묻는 질문',
                  onTap: () => _push(const FaqScreen())),
              _MenuRow(
                  icon: Icons.description_outlined,
                  label: '이용약관',
                  onTap: () => _push(PolicyScreen.terms())),
              _MenuRow(
                  icon: Icons.shield_outlined,
                  label: '개인정보 처리방침',
                  onTap: () => _push(PolicyScreen.privacy())),
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
                onTap: _confirmDeleteAccount,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('정말 탈퇴하시겠어요?',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -0.3)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.coralTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '아래 데이터가 삭제되며 복구할 수 없어요.\n\n'
                  '· 계정 정보 (로그인 연동·거주지·프로필)\n'
                  '· 여행 기록과 인증사진·영수증·숙박확인서\n'
                  '· 저장한 코스와 관심 지역\n\n'
                  '커뮤니티 글은 작성자만 «탈퇴한 사용자»로 바뀌고 남아요.\n'
                  '글까지 지우려면 탈퇴 전에 직접 삭제해 주세요.\n\n'
                  '정산을 신청한 여행이 있어도 탈퇴할 수 있지만,\n'
                  '앱에 올린 증빙 자료는 사라져요.',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coralDeep,
                      height: 1.55),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(c, false),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.line, width: 1.5),
                        foregroundColor: AppColors.ink7,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    child: const Text('취소',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.coralDeep,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    child: const Text('탈퇴하기',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final controller = AppScope.of(context);
    try {
      await controller.deleteAccount();
      if (!mounted) return;
      // 세션이 끝나면 루트가 로그인 화면으로 전환되므로 스택을 닫는다.
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('탈퇴가 완료됐어요. 이용해 주셔서 감사했습니다.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('탈퇴 처리에 실패했어요. 잠시 후 다시 시도하거나 jhm0350@gmail.com으로 요청해 주세요.')));
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('로그아웃 하시겠어요?',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -0.3)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(c, false),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.line, width: 1.5),
                        foregroundColor: AppColors.ink7,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    child: const Text('취소',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    child: const Text('로그아웃',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    // 팝 이후 context는 비활성화되므로 컨트롤러를 미리 캡처한다.
    final controller = AppScope.of(context);
    // 마이페이지 라우트를 먼저 닫고, 팝 전환이 끝난 뒤 로그아웃한다.
    // (팝 전환 도중 홈을 교체하면 전환/딤 배리어가 멈춰 화면이 밀린 채 남는 버그가 생김)
    Navigator.of(context).pop();
    Future.delayed(const Duration(milliseconds: 320), controller.logout);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// 프로필 편집 — 아바타·닉네임 편집 화면으로 이동.
  Future<void> _editProfile() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
    if (mounted) setState(() {});
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

    // await 없이 부르면 서버 PATCH가 끝나기 전에 홈이 사용자 정보를 다시 읽어
    // 옛 거주지가 그대로 보인다(낙관 갱신은 이 화면에만 반영됨).
    await AppScope.of(context).updateResidence('$province $city');
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
    final avatar = decodeAvatar(
        user.avatarPreset.isNotEmpty ? user.avatarPreset : defaultAvatarPreset);
    final nickname = user.nickname.trim().isEmpty ? '여행자' : user.nickname.trim();
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatar.color,
              shape: BoxShape.circle,
            ),
            child: Text(avatar.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$nickname님',
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
    // InkWell 사각 호버가 라운드 카드와 어긋나 보여 목업 UI 관례대로 효과 없이 탭만.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
