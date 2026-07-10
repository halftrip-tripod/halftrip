import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../models/app_models.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S0-1 스플래시/로그인.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _social(BuildContext context, LoginProvider provider) async {
    // 로그인 후 거주지 미설정이면 루트 게이트가 ResidenceScreen을 띄운다.
    await AppScope.of(context).login(provider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(children: [
            const Spacer(flex: 3),
            Image.asset('assets/brand/logo.png', height: 44),
            const SizedBox(height: 28),
            const Text(
              '여행경비의 절반,',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
            ),
            const Text.rich(
              TextSpan(children: [
                TextSpan(text: '돌려받는', style: TextStyle(color: AppColors.p600)),
                TextSpan(text: ' 국내여행'),
              ]),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
            ),
            const SizedBox(height: 10),
            const Text('반값여행 + 디지털 관광주민증을 한 번에',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            const Spacer(flex: 4),
            _SocialButton(
              label: '카카오로 시작하기',
              bg: const Color(0xFFFEE500),
              fg: const Color(0xFF191919),
              icon: Icons.chat_bubble_rounded,
              onTap: () => _social(context, LoginProvider.kakao),
            ),
            const SizedBox(height: 10),
            _SocialButton(
              label: '네이버로 시작하기',
              bg: const Color(0xFF03C75A),
              fg: Colors.white,
              leading: const Text('N',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
              onTap: () => _social(context, LoginProvider.naver),
            ),
            const SizedBox(height: 18),
            const Text.rich(
              TextSpan(children: [
                TextSpan(text: '이용약관', style: TextStyle(decoration: TextDecoration.underline)),
                TextSpan(text: ' · '),
                TextSpan(text: '개인정보처리방침', style: TextStyle(decoration: TextDecoration.underline)),
              ]),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink4),
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
                      decoration: TextDecoration.underline)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
    this.leading,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (leading != null) leading! else Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
        ]),
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
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '계정이 없으신가요?  '),
                  TextSpan(
                      text: '회원가입',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.p600,
                          decoration: TextDecoration.underline)),
                ]),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5),
              ),
            ),
          ),
        ),
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

/// 로컬 회원가입 — 이름·아이디·비밀번호·휴대전화·거주지 → localSignUp.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _phone = TextEditingController();
  String _province = '서울특별시';
  String _city = '강남구';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _pw.dispose();
    _pw2.dispose();
    _phone.dispose();
    super.dispose();
  }

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

  String? get _validationError {
    if (_name.text.trim().isEmpty) return '이름을 입력해주세요.';
    if (_id.text.trim().length < 4) return '아이디는 4자 이상 입력해주세요.';
    if (_pw.text.length < 4) return '비밀번호는 4자 이상 입력해주세요.';
    if (_pw.text != _pw2.text) return '비밀번호가 서로 달라요.';
    if (_phone.text.trim().isEmpty) return '휴대전화 번호를 입력해주세요.';
    return null;
  }

  Future<void> _submit() async {
    final error = _validationError;
    if (error != null) {
      showMock(context, error);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final controller = AppScope.of(context);
    final navigator = Navigator.of(context);
    try {
      await controller.signUpWithCredentials(
        name: _name.text.trim(),
        loginId: _id.text.trim(),
        password: _pw.text,
        phoneNumber: _phone.text.trim(),
        residence: '$_province $_city',
      );
      // 가입 즉시 로그인 상태 — 루트 게이트가 메인으로 전환한다.
      navigator.popUntil((r) => r.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMock(context, '회원가입에 실패했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '회원가입',
      cta: CtaBar(children: [
        PrimaryButton(_saving ? '가입 중…' : '가입하고 시작하기', disabled: _saving, onTap: _submit),
      ]),
      children: [
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: '반값여행,\n'),
            TextSpan(text: '시작해볼까요?', style: TextStyle(color: AppColors.p600)),
          ]),
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1, height: 1.3),
        ),
        const Text('이름과 거주지는 반값여행 신청 자격 확인에 쓰여요.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5)),
        _Field(label: '이름', controller: _name, hint: '실명을 입력하세요'),
        _Field(label: '아이디', controller: _id, hint: '4자 이상'),
        _Field(label: '비밀번호', controller: _pw, hint: '4자 이상', obscure: true),
        _Field(label: '비밀번호 확인', controller: _pw2, hint: '한 번 더 입력', obscure: true),
        _Field(label: '휴대전화', controller: _phone, hint: '010-0000-0000'),
        _PickField(label: '거주지 · 시/도', value: _province, onTap: _pickProvince),
        _PickField(label: '거주지 · 시/군/구', value: _city, onTap: _pickCity),
        const NoteRow('거주지와 같거나 인접한 지역은 반값여행 대상에서 제외돼요.'),
      ],
    );
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
