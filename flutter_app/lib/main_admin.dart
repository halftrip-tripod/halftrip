import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'admin/admin_repository.dart';
import 'admin/admin_shell.dart';
import 'admin/login_page.dart';
import 'core/app_config.dart';
import 'mock_ui/theme/app_theme.dart';

/// 하프트립 관리자 콘솔(웹) 엔트리. 앱 번들에는 포함되지 않는다 — 이 파일로만 빌드한다.
///
/// flutter build web --target lib/main_admin.dart --release \
///   --dart-define=API_BASE_URL=https://halftrip-springboot.onrender.com/api -o build/admin-web
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  runApp(AdminApp(repository: AdminRepository(config)));
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  bool _restoring = true;
  bool _loggedIn = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    widget.repository.onSessionExpired = () {
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _notice = '세션이 만료됐어요. 다시 로그인해 주세요.';
      });
    };
    widget.repository.restoreSession().then((session) {
      if (!mounted) return;
      setState(() {
        _loggedIn = session != null && session.isAdmin;
        _restoring = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '하프트립 관리자',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      locale: const Locale('ko'),
      home: _restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _loggedIn
              ? AdminShell(
                  repository: widget.repository,
                  onLogout: () async {
                    await widget.repository.logout();
                    if (mounted) setState(() => _loggedIn = false);
                  },
                )
              : AdminLoginPage(
                  repository: widget.repository,
                  notice: _notice,
                  onLoggedIn: () => setState(() {
                    _loggedIn = true;
                    _notice = null;
                  }),
                ),
    );
  }
}
