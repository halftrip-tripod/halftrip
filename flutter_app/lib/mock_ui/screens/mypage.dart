import 'dart:math';

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'community.dart';
import 'info_screens.dart';
import 'onboarding.dart';
import 'region_detail.dart';

/// S9-1 마이페이지.
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => setState(() {}));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('로그아웃하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    AppState.I.logout();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final mineCount = s.posts.where((p) => p.mine).length + 8;
    final savedCount = s.posts.where((p) => p.savedByMe).length;

    return DetailScaffold(
      title: '마이페이지',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        // 프로필
        AppCard(
          onTap: () => _push(const ProfileEditScreen()),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: s.avatarBg,
              child: Text(s.avatarEmoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.nickname}님',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                const SizedBox(height: 3),
                Text('${s.loginProvider} 계정으로 로그인됨',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5)),
              ]),
            ),
            const Text('편집',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
          ]),
        ),
        const _GroupLabel('커뮤니티'),
        MenuGroup(children: [
          MenuRow(icon: Icons.edit_outlined, label: '작성한 글', value: '$mineCount개',
              onTap: () => _push(const MyReviewsScreen())),
          MenuRow(icon: Icons.bookmark_outline_rounded, label: '저장한 글', value: '$savedCount개',
              onTap: () => _push(const SavedPostsScreen())),
        ]),
        const _GroupLabel('내 정보'),
        MenuGroup(children: [
          MenuRow(
            icon: Icons.place_outlined,
            label: '거주지',
            value: s.residence.split(' ').first,
            onTap: () => _push(const ResidenceScreen(editMode: true)),
          ),
          MenuRow(
            icon: Icons.star_outline_rounded,
            label: '관심 지역',
            value: '${s.regions.where((r) => r.favorite.value).length}개',
            onTap: () => _push(const FavoriteRegionsScreen()),
          ),
        ]),
        const _GroupLabel('알림 설정'),
        MenuGroup(children: [
          ToggleRow(
            icon: Icons.notifications_none_rounded,
            label: '관심 지역 오픈 · 마감 알림',
            value: s.alertRegionOpen,
            onChanged: (v) => setState(() => s.alertRegionOpen = v),
          ),
          ToggleRow(
            icon: Icons.schedule_rounded,
            label: '정산 D-day 알림',
            value: s.alertSettlementDday,
            onChanged: (v) => setState(() => s.alertSettlementDday = v),
          ),
        ]),
        const _GroupLabel('이용 안내'),
        MenuGroup(children: [
          MenuRow(icon: Icons.campaign_outlined, label: '공지사항',
              onTap: () => _push(const NoticeScreen())),
          MenuRow(icon: Icons.help_outline_rounded, label: '자주 묻는 질문',
              onTap: () => _push(const FaqScreen())),
          MenuRow(icon: Icons.description_outlined, label: '이용약관',
              onTap: () => _push(PolicyScreen.terms())),
          MenuRow(icon: Icons.shield_outlined, label: '개인정보 처리방침',
              onTap: () => _push(PolicyScreen.privacy())),
          const MenuRow(icon: Icons.info_outline_rounded, label: '버전 정보', value: '0.1.0 (목업)'),
        ]),
        const _GroupLabel('계정'),
        MenuGroup(children: [
          MenuRow(icon: Icons.logout_rounded, label: '로그아웃', onTap: _logout),
          MenuRow(
              icon: Icons.delete_outline_rounded,
              label: '회원 탈퇴',
              danger: true,
              onTap: () => showMock(context, '회원 탈퇴는 목업에서 생략했어요.')),
        ]),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
    );
  }
}

/// 프로필 편집 — 아바타 프리셋 + 반익명 닉네임.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late int _selected = avatarPresets
      .indexWhere((p) => p.$1 == AppState.I.avatarEmoji)
      .clamp(0, avatarPresets.length - 1);
  late final _nick = TextEditingController(text: AppState.I.nickname);

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '프로필 편집',
      cta: CtaBar(children: [
        PrimaryButton('저장하기', onTap: () {
          final s = AppState.I;
          s.avatarEmoji = avatarPresets[_selected].$1;
          s.avatarBg = avatarPresets[_selected].$2;
          if (_nick.text.trim().isNotEmpty) s.nickname = _nick.text.trim();
          s.update();
          Navigator.of(context).pop();
          showMock(context, '프로필을 저장했어요.');
        }),
      ]),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: avatarPresets[_selected].$2,
            child: Text(avatarPresets[_selected].$1, style: const TextStyle(fontSize: 42)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text('아바타 선택',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink9)),
        ),
        AppCard(
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < avatarPresets.length; i++)
              GestureDetector(
                onTap: () => setState(() => _selected = i),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == _selected ? AppColors.p500 : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: avatarPresets[i].$2,
                    child: Text(avatarPresets[i].$1, style: const TextStyle(fontSize: 23)),
                  ),
                ),
              ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text('닉네임',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink9)),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _nick,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(
                () => _nick.text = nicknamePool[Random().nextInt(nicknamePool.length)]),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
              child: const Icon(Icons.casino_outlined, size: 22, color: AppColors.p600),
            ),
          ),
        ]),
        const NoteRow('닉네임은 커뮤니티에서 표시되는 반익명 이름이에요. 실명은 정산 신청 때만 수집돼요.'),
      ],
    );
  }
}

/// 관심 지역 보기·해제.
class FavoriteRegionsScreen extends StatefulWidget {
  const FavoriteRegionsScreen({super.key});

  @override
  State<FavoriteRegionsScreen> createState() => _FavoriteRegionsScreenState();
}

class _FavoriteRegionsScreenState extends State<FavoriteRegionsScreen> {
  @override
  Widget build(BuildContext context) {
    final favs = AppState.I.regions.where((r) => r.favorite.value).toList();
    return DetailScaffold(
      title: '관심 지역',
      children: [
        const NoteRow('홈·지역 상세의 ★로 담은 지역이에요. 오픈·마감 소식을 알림으로 알려드려요.'),
        if (favs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: Text('아직 관심 지역이 없어요\n홈에서 ★을 눌러 담아보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink4, height: 1.6)),
            ),
          ),
        for (final r in favs)
          AppCard(
            padding: const EdgeInsets.all(15),
            radius: 18,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => RegionDetailScreen(region: r)))
                .then((_) => setState(() {})),
            child: Row(children: [
              EmojiBox(r.emoji, size: 46, fontSize: 23),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                  const SizedBox(height: 3),
                  Text(
                    r.openLabel != null ? '${r.province} · ${r.openLabel}' : '${r.province} · 마감 D-${r.dday}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: () {
                  AppState.I.toggleFavorite(r);
                  setState(() {});
                  showMock(context, '${r.name} 관심 등록을 해제했어요.');
                },
                child: const Icon(Icons.star_rounded, size: 24, color: AppColors.warning),
              ),
            ]),
          ),
      ],
    );
  }
}

