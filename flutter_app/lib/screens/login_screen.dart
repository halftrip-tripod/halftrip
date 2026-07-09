import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import 'local_login_screen.dart';

/// 스플래시 겸 소셜 로그인 화면 (카카오·네이버).
/// 디자인: halftrip-design/login.html
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 상단 영역을 채워 로고를 가운데로 끌어올림
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/logo/logo.png',
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  _Copy(),
                  const SizedBox(height: 24),
                  _SocialButton(
                    background: const Color(0xFFFEE500),
                    foreground: const Color(0xFF181600),
                    icon: Icons.chat_bubble,
                    label: '카카오로 시작하기',
                    onPressed: controller.isBusy
                        ? null
                        : () => _handleSocial(context, LoginProvider.kakao),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    background: const Color(0xFF03C75A),
                    foreground: Colors.white,
                    leading: const Text(
                      'N',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    label: '네이버로 시작하기',
                    onPressed: controller.isBusy
                        ? null
                        : () => _handleSocial(context, LoginProvider.naver),
                  ),
                  const SizedBox(height: 16),
                  _TermsLinks(),
                  const SizedBox(height: 6),
                  _LocalLoginLink(
                    onTap: controller.isBusy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LocalLoginScreen(),
                              ),
                            ),
                  ),
                  if (controller.isBusy) ...[
                    const SizedBox(height: 18),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSocial(
    BuildContext context,
    LoginProvider provider,
  ) async {
    final controller = AppScope.of(context);
    try {
      await controller.login(provider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.label} 로그인에 실패했어요. 다시 시도해 주세요.')),
      );
    }
  }
}

class _Copy extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 22,
              height: 1.32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: AppColors.ink9,
            ),
            children: [
              TextSpan(text: '여행경비의 절반,\n'),
              TextSpan(
                text: '돌려받는',
                style: TextStyle(color: AppColors.p600),
              ),
              TextSpan(text: ' 국내여행'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '반값여행 + 디지털 관광주민증을 한 번에',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink5,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.background,
    required this.foreground,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
  });

  final Color background;
  final Color foreground;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: AppColors.ink5,
      decoration: TextDecoration.underline,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _showDoc(context, '이용약관'),
          child: const Text('이용약관', style: linkStyle),
        ),
        const Text(
          '  ·  ',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.ink4,
          ),
        ),
        GestureDetector(
          onTap: () => _showDoc(context, '개인정보처리방침'),
          child: const Text('개인정보처리방침', style: linkStyle),
        ),
      ],
    );
  }

  void _showDoc(BuildContext context, String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              '서비스 출시 전 데모 화면입니다. 실제 약관 내용은 정식 출시 시 제공됩니다.',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                height: 1.5,
                color: AppColors.ink5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalLoginLink extends StatelessWidget {
  const _LocalLoginLink({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '로컬 로그인',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink5,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
