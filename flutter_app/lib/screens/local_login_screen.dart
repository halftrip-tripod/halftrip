import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../theme/app_colors.dart';

/// 아이디/비밀번호 로컬 로그인 (심사·테스트 계정용).
/// 디자인: halftrip-design/local-login.html
class LocalLoginScreen extends StatefulWidget {
  const LocalLoginScreen({super.key});

  @override
  State<LocalLoginScreen> createState() => _LocalLoginScreenState();
}

class _LocalLoginScreenState extends State<LocalLoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('로컬 로그인')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                _Field(
                  label: '아이디',
                  controller: _loginIdController,
                  hintText: '아이디를 입력하세요',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                _Field(
                  label: '비밀번호',
                  controller: _passwordController,
                  hintText: '비밀번호를 입력하세요',
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(context),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      size: 18,
                      color: AppColors.ink4,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        child: FilledButton(
          onPressed: controller.isBusy ? null : () => _handleLogin(context),
          child: controller.isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text('로그인'),
        ),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    final controller = AppScope.of(context);
    final loginId = _loginIdController.text.trim();
    final password = _passwordController.text.trim();
    if (loginId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 모두 입력해 주세요.')),
      );
      return;
    }

    try {
      await controller.loginWithCredentials(
        loginId: loginId,
        password: password,
      );
      if (!context.mounted) return;
      // 로그인 성공 시 루트가 메인 화면으로 전환되므로 로그인 스택을 닫는다.
      Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디 또는 비밀번호가 올바르지 않습니다.')),
      );
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink7,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink9,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.ink4,
            ),
            filled: true,
            fillColor: AppColors.surf,
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
