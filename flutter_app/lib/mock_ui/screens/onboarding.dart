import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../../core/app_config.dart';
import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/info_screens.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S0-1 스플래시/로그인.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _social(BuildContext context, LoginProvider provider) async {
    final controller = AppScope.of(context);
    final config = AppConfig.fromEnvironment();
    // mock 로그인 모드는 기존 mock-login 경로 유지 (QA·개발용).
    if (config.useMockLogin) {
      await controller.login(provider);
      return;
    }
    try {
      final accessToken = switch (provider) {
        LoginProvider.kakao => await _kakaoAccessToken(context, config),
        LoginProvider.naver => await _naverAccessToken(context),
        _ => null,
      };
      if (accessToken == null) return; // 취소 또는 키 미설정 (안내는 내부에서)
      if (!context.mounted) return;
      // 로그인 후 거주지 미설정이면 루트 게이트가 ResidenceScreen을 띄운다.
      await controller.loginWithSocial(provider, accessToken);
    } catch (_) {
      if (context.mounted) {
        showMock(context, '로그인에 실패했어요. 잠시 후 다시 시도해주세요.');
      }
    }
  }

  /// 카카오 SDK 로그인 → 액세스 토큰. 카카오톡 설치 시 앱 전환, 아니면 계정 로그인(웹뷰).
  Future<String?> _kakaoAccessToken(BuildContext context, AppConfig config) async {
    if (!config.kakaoLoginConfigured) {
      showMock(context, '카카오 로그인 준비 중이에요. (개발자 앱 키 등록 대기)');
      return null;
    }
    try {
      final token = !kIsWeb && await kakao.isKakaoTalkInstalled()
          ? await kakao.UserApi.instance.loginWithKakaoTalk()
          : await kakao.UserApi.instance.loginWithKakaoAccount();
      return token.accessToken;
    } on kakao.KakaoAuthException catch (e) {
      if (e.error == kakao.AuthErrorCause.accessDenied) return null; // 사용자 취소
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null; // 카카오톡 앱 전환 취소
      rethrow;
    }
  }

  /// 네이버 SDK 로그인 → 액세스 토큰. 키는 AndroidManifest 메타데이터로 주입(웹 미지원).
  Future<String?> _naverAccessToken(BuildContext context) async {
    if (kIsWeb) {
      showMock(context, '네이버 로그인은 앱에서 이용할 수 있어요.');
      return null;
    }
    final result = await FlutterNaverLogin.logIn();
    if (result.status == NaverLoginStatus.loggedIn) {
      final token = result.accessToken?.accessToken;
      return (token == null || token.isEmpty) ? null : token;
    }
    // loggedOut = 사용자 취소 → 조용히 종료, error = 키 미설정·SDK 오류 → 안내.
    if (result.status == NaverLoginStatus.error && context.mounted) {
      showMock(context, '네이버 로그인 준비 중이에요. (개발자 앱 키 등록 대기)');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(children: [
            const Spacer(flex: 3),
            Image.asset('assets/logo/logo-3d.png', height: 285),
            const Spacer(flex: 4),
            const Text(
              '복잡한 반값여행,',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
            ),
            const Text.rich(
              TextSpan(children: [
                TextSpan(text: '하프트립', style: TextStyle(color: AppColors.p600)),
                TextSpan(text: ' 하나로'),
              ]),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
            ),
            const SizedBox(height: 10),
            const Text('정보 확인부터 인증·증빙·정산 관리까지',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            const SizedBox(height: 22),
            _OfficialLoginButton(
              asset: 'assets/brand/kakao_login.png',
              onTap: () => _social(context, LoginProvider.kakao),
            ),
            const SizedBox(height: 10),
            _OfficialLoginButton(
              asset: 'assets/brand/naver_login.png',
              onTap: () => _social(context, LoginProvider.naver),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DocLink('이용약관', () => PolicyScreen.terms()),
                const Text(' · ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink4)),
                _DocLink('개인정보처리방침', () => PolicyScreen.privacy()),
              ],
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LocalLoginScreen())),
              child: const Text('로컬 로그인',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink5,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.ink5,
                      decorationThickness: 1)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 카카오·네이버 공식 로그인 버튼 (브랜드 가이드 완성 이미지를 그대로 사용).
/// 이미지에 로고·문구·색·라운딩이 규격대로 포함돼 있어 수정 없이 그대로 노출한다.
class _OfficialLoginButton extends StatelessWidget {
  const _OfficialLoginButton({required this.asset, required this.onTap});
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(asset, width: double.infinity, fit: BoxFit.fitWidth),
    );
  }
}

/// 로컬 로그인 (테스트·심사용).
class LocalLoginScreen extends StatefulWidget {
  const LocalLoginScreen({super.key});

  @override
  State<LocalLoginScreen> createState() => _LocalLoginScreenState();
}

class _LocalLoginScreenState extends State<LocalLoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '로컬 로그인',
      cta: CtaBar(children: [
        PrimaryButton('로그인', onTap: () async {
          final controller = AppScope.of(context);
          final navigator = Navigator.of(context);
          try {
            await controller.loginWithCredentials(
              loginId: _id.text.trim(),
              password: _pw.text,
            );
            navigator.popUntil((r) => r.isFirst);
          } catch (_) {
            if (!context.mounted) return;
            showMock(context, '아이디 또는 비밀번호를 확인해주세요.');
          }
        }),
      ]),
      children: [
        _Field(label: '아이디', controller: _id, hint: '아이디를 입력하세요'),
        _Field(label: '비밀번호', controller: _pw, hint: '비밀번호를 입력하세요', obscure: true),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.hint, this.obscure = false});
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink9),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink4),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: obscure ? const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.ink4) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }
}

/// S0-2 거주지 입력.
class ResidenceScreen extends StatefulWidget {
  const ResidenceScreen({super.key, this.editMode = false});
  final bool editMode;

  @override
  State<ResidenceScreen> createState() => _ResidenceScreenState();
}

class _ResidenceScreenState extends State<ResidenceScreen> {
  String _province = '서울특별시';
  String _city = '강남구';

  Future<void> _pickProvince() async {
    final p = await pickOption(context, title: '시 / 도', options: residenceOptions.keys.toList());
    if (p == null || !mounted) return;
    setState(() {
      _province = p;
      _city = residenceOptions[p]!.first;
    });
  }

  Future<void> _pickCity() async {
    final c = await pickOption(context, title: '시 / 군 / 구', options: residenceOptions[_province]!);
    if (c == null || !mounted) return;
    setState(() => _city = c);
  }

  void _done() {
    final controller = AppScope.of(context);
    final residence = '$_province $_city';
    if (widget.editMode) {
      controller.updateResidence(residence);
      Navigator.of(context).pop();
      showMock(context, '거주지를 $residence(으)로 바꿨어요.');
    } else {
      controller.completeResidenceSetup(residence);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '거주지 설정',
      cta: CtaBar(children: [PrimaryButton(widget.editMode ? '저장하기' : '시작하기', onTap: _done)]),
      children: [
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: '어디에\n'),
            TextSpan(text: '살고 계신가요?', style: TextStyle(color: AppColors.p600)),
          ]),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
        ),
        const Text('반값여행은 거주지와 같은·인접한 지역은 대상에서 제외돼요.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
        _PickField(label: '시 / 도', value: _province, onTap: _pickProvince),
        _PickField(label: '시 / 군 / 구', value: _city, onTap: _pickCity),
        const NoteRow('거주지는 마이페이지에서 언제든 바꿀 수 있어요.'),
      ],
    );
  }
}

class _PickField extends StatelessWidget {
  const _PickField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.soft,
          ),
          child: Row(children: [
            Text(value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9)),
            const Spacer(),
            const Icon(Icons.expand_more_rounded, color: AppColors.ink4),
          ]),
        ),
      ),
    ]);
  }
}

/// 약관·개인정보처리방침 등 탭하면 문서 화면을 여는 밑줄 링크.
class _DocLink extends StatelessWidget {
  const _DocLink(this.label, this.pageBuilder);
  final String label;
  final Widget Function() pageBuilder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => pageBuilder())),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.ink4,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.ink4,
              decorationThickness: 1)),
    );
  }
}
