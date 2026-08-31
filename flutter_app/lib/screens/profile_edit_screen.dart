import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../theme/app_colors.dart';
import '../utils/profile_presets.dart';

/// 프로필 편집 — 아바타 프리셋 선택 + 반익명 닉네임(랜덤 생성·수정).
/// (실명은 정산 신청 시점에만 수집 — 여기선 표시용 닉네임/아바타만 다룬다.)
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late int _colorIndex;
  late int _emojiIndex;
  final TextEditingController _nickname = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final user = AppScope.of(context).currentUser;
    final decoded = decodeAvatar(
      (user?.avatarPreset.isNotEmpty ?? false)
          ? user!.avatarPreset
          : defaultAvatarPreset,
    );
    _colorIndex = decoded.colorIndex;
    _emojiIndex = decoded.emojiIndex;
    _nickname.text = (user?.nickname.isNotEmpty ?? false)
        ? user!.nickname
        : randomNickname();
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nickname.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임을 입력해 주세요.')));
      return;
    }
    // 서버 반영을 기다린 뒤 닫는다 — await 없이 pop하면 돌아간 화면이
    // 아직 갱신 안 된 사용자 정보를 다시 읽어 옛 닉네임·아바타가 보인다.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await AppScope.of(context).updateProfile(
      nickname: name,
      avatarPreset: encodeAvatar(_colorIndex, _emojiIndex),
    );
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = avatarColors[_colorIndex];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('프로필 편집')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // 선택된 조합 미리보기 (배경색 + 이모지)
            Center(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                ),
                child: Text(avatarEmojis[_emojiIndex],
                    style: const TextStyle(fontSize: 46)),
              ),
            ),
            const SizedBox(height: 24),
            const _Label('닉네임'),
            const SizedBox(height: 12),
            TextField(
              controller: _nickname,
              maxLength: 16,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: '닉네임을 입력하세요',
                filled: true,
                fillColor: AppColors.surf,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  tooltip: '랜덤 생성',
                  icon: Transform.rotate(
                    angle: -0.35,
                    child: const Icon(Icons.casino_rounded,
                        color: AppColors.p600),
                  ),
                  onPressed: () =>
                      setState(() => _nickname.text = randomNickname()),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('닉네임은 커뮤니티 등에서 표시돼요. 실명은 노출되지 않아요.',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink4,
                )),
            const SizedBox(height: 26),
            const _Label('배경색'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var i = 0; i < avatarColors.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: avatarColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorIndex == i
                              ? AppColors.ink9
                              : AppColors.line,
                          width: _colorIndex == i ? 2.6 : 1,
                        ),
                      ),
                      child: _colorIndex == i
                          ? const Icon(Icons.check_rounded,
                              size: 18, color: AppColors.ink7)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            const _Label('이모지'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var i = 0; i < avatarEmojis.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _emojiIndex = i),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _emojiIndex == i ? AppColors.p50 : AppColors.surf,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _emojiIndex == i
                              ? AppColors.p500
                              : Colors.transparent,
                          width: 2.2,
                        ),
                      ),
                      child: Text(avatarEmojis[i],
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: FilledButton(onPressed: _save, child: const Text('저장')),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink7,
        ));
  }
}
