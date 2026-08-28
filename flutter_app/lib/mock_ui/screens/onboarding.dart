import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../../core/app_config.dart';
import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../../screens/info_screens.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S0-1 로그인 — 아이디·비밀번호 폼 + 하단 간편(소셜) 로그인.
/// 이전엔 소셜 버튼 + "로컬 로그인" 별도 화면 구조였는데, 일반적인 앱 관례(폼 + 원형
/// 간편 버튼)로 통일했다. 심사·테스트 계정도 이 화면에서 바로 입력한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _localLogin() async {
    final controller = AppScope.of(context);
    final id = _id.text.trim();
    if (id.isEmpty || _pw.text.isEmpty) {
      showMock(context, '아이디와 비밀번호를 입력해주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      await controller.loginWithCredentials(loginId: id, password: _pw.text);
    } catch (_) {
      if (mounted) {
        showMock(context, '아이디 또는 비밀번호를 확인해주세요.');
      }
    }
  }

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
        LoginProvider.google => await _googleAccessToken(context),
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
  /// 현재 화면에서는 보류 상태(버튼 없음) — 플러그인이 최신 네이버앱과 호환되면 되살린다.
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

  /// 구글 로그인 → 액세스 토큰. 서버(SocialAuthClient)가 이 토큰으로 userinfo를 검증한다.
  /// Firebase 콘솔에 업로드키·디버그키 SHA-1이 등록돼 있어야 동작(미등록이면 sign_in_failed).
  Future<String?> _googleAccessToken(BuildContext context) async {
    if (kIsWeb) {
      showMock(context, '구글 로그인은 앱에서 이용할 수 있어요.');
      return null;
    }
    try {
      final signIn = GoogleSignIn(scopes: const ['email', 'profile']);
      final account = await signIn.signIn();
      if (account == null) return null; // 사용자 취소
      final token = (await account.authentication).accessToken;
      return (token == null || token.isEmpty) ? null : token;
    } on PlatformException {
      if (context.mounted) {
        showMock(context, '구글 로그인 준비 중이에요. (콘솔 SHA-1 등록 대기)');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // AppScope는 InheritedNotifier — 로그인 진행(isBusy) 변화에 맞춰 오버레이가 갱신된다.
    final controller = AppScope.of(context);
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: LayoutBuilder(builder: (context, viewport) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(children: [
                const Spacer(flex: 2),
                Image.asset('assets/logo/logo-3d.png', height: 205),
                const Spacer(flex: 2),
                const Text(
                  '복잡한 반값여행,',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -1,
                      height: 1.3),
                ),
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '하프트립', style: TextStyle(color: AppColors.p600)),
                    TextSpan(text: ' 하나로'),
                  ]),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink9,
                      letterSpacing: -1,
                      height: 1.3),
                ),
                const SizedBox(height: 10),
                const Text('정보 확인부터 인증·증빙·정산 관리까지',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink5)),
                const SizedBox(height: 22),
                _LoginField(controller: _id, hint: '아이디'),
                const SizedBox(height: 10),
                _LoginField(
                  controller: _pw,
                  hint: '비밀번호',
                  obscure: true,
                  onSubmitted: (_) => _localLogin(),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _localLogin,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.p500,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x470EA5E9),
                            blurRadius: 18,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('로그인',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3)),
                  ),
                ),
                const SizedBox(height: 30),
                const Row(children: [
                  Expanded(child: Divider(color: AppColors.line, thickness: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('간편 로그인',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink4)),
                  ),
                  Expanded(child: Divider(color: AppColors.line, thickness: 1)),
                ]),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // 카카오: 구글과 동일한 원형 아이콘 — 공식 컨테이너 색(#FEE500) 위에
                  // 공식 버튼 리소스의 말풍선 심벌(형태·비율·색 무변형)을 얹는다.
                  GestureDetector(
                    onTap: () => _social(context, LoginProvider.kakao),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE500),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Image.asset('assets/brand/kakao_symbol.png',
                          width: 24, height: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 구글: 공식 gsi-material-button 아이콘 버튼의 뉴트럴 스펙 그대로 —
                  // 40×40, radius 20, 배경 #F2F2F2, 보더 없음, G 로고 20px.
                  GestureDetector(
                    onTap: () => _social(context, LoginProvider.google),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F2F2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Image.asset('assets/brand/google_g_logo.png',
                          width: 20, height: 20),
                    ),
                  ),
                ]),
                const Spacer(flex: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DocLink('이용약관', () => PolicyScreen.terms()),
                    const Text(' · ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink4)),
                    _DocLink('개인정보처리방침', () => PolicyScreen.privacy()),
                  ],
                ),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
        // 소셜 인증 후 서버 확인 단계 — 무료 서버 콜드스타트면 수십 초 걸릴 수 있어
        // 전체 화면으로 진행 상태를 보여준다 (터치도 이 스크림이 막는다).
        if (controller.isBusy)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x73101828),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: AppColors.p600),
                    ),
                    SizedBox(height: 16),
                    Text('로그인하고 있어요',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink9,
                            letterSpacing: -0.3)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// 로그인 폼 입력칸 — 앱 카드 스타일(흰 배경·라운드·라인)과 동일 결.
class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink9),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink4),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.p500, width: 1.6),
        ),
      ),
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
