import 'package:flutter/material.dart';

import '../mock_ui/theme/app_colors.dart';
import '../mock_ui/widgets/ui.dart';
import 'admin_repository.dart';
import 'widgets/admin_ui.dart';

/// 관리자 로그인 — 기존 /api/auth/login 을 쓰되 role 이 ADMIN 이 아니면 들여보내지 않는다.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, required this.repository, required this.onLoggedIn, this.notice});
  final AdminRepository repository;
  final VoidCallback onLoggedIn;
  final String? notice;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final id = _id.text.trim();
    final pw = _pw.text;
    if (id.isEmpty || pw.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.login(id, pw);
      widget.onLoggedIn();
    } on AdminApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '로그인에 실패했어요. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(widget.repository.config.apiBaseUrl)?.host ?? '';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.card),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Image.asset('assets/logo/app-icon-pin.png', width: 40, height: 40, filterQuality: FilterQuality.medium),
                const SizedBox(width: 10),
                const Text('하프트립', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5, color: AppColors.ink9)),
                const SizedBox(width: 8),
                const Pill('ADMIN', tone: PillTone.sky),
              ]),
              const SizedBox(height: 18),
              const Text('관리자 로그인', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5, color: AppColors.ink9)),
              const SizedBox(height: 16),
              AdminField(label: '아이디', controller: _id, hint: '아이디'),
              const SizedBox(height: 12),
              _PasswordField(controller: _pw, onSubmit: _submit),
              if (widget.notice != null && _error == null) ...[const SizedBox(height: 12), _Banner(widget.notice!, warn: true)],
              if (_error != null) ...[const SizedBox(height: 12), _Banner(_error!)],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('로그인'),
                ),
              ),
              const SizedBox(height: 14),
              Text('ADMIN 권한 계정만 들어올 수 있어요 · $host', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('비밀번호', style: kLabel),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          onSubmitted: (_) => onSubmit(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink9),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.p400, width: 1.5)),
          ),
        ),
      ]);
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.warn = false});
  final String text;
  final bool warn;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: warn ? AppColors.warningTint : AppColors.dangerTint, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: warn ? const Color(0xFFB8731B) : AppColors.danger, height: 1.45)),
      );
}
