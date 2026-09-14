import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import 'admin_models.dart';

/// 관리자 API 호출 실패. [status] 401 이면 세션 만료(정지 포함), 403 이면 권한 없음.
class AdminApiException implements Exception {
  AdminApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// 관리자 콘솔 전용 HTTP 클라이언트 — ApiTravelRepository 의 `_jsonRequest` 패턴을 그대로 옮겼다.
/// 앱 Repository 를 재사용하지 않는 이유: 관리자 API 는 userId 파라미터가 없고, 토큰 보관·만료 처리가 다르다.
class AdminRepository {
  AdminRepository(this.config);

  static const _sessionKey = 'admin.session';

  final AppConfig config;
  AdminSession? _session;
  AdminSession? get session => _session;

  /// 세션 만료(401)를 셸에 알린다 — 로그인 화면으로 되돌리기 위해.
  void Function()? onSessionExpired;

  // ── 세션 ──

  Future<AdminSession?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return null;
      _session = AdminSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _session;
    } catch (_) {
      return null;
    }
  }

  Future<AdminSession> login(String loginId, String password) async {
    final response = await _jsonRequest('POST', '/auth/login', body: {'loginId': loginId, 'password': password}, auth: false);
    final data = response['data'] as Map<String, dynamic>;
    final session = AdminSession(
      userId: data['userId'] as int,
      token: (data['token'] ?? data['mockToken']) as String,
      loginId: loginId,
      role: data['role'] as String? ?? 'USER',
    );
    if (!session.isAdmin) {
      throw AdminApiException(403, '관리자 권한이 없는 계정입니다.');
    }
    _session = session;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (_) {}
    return session;
  }

  Future<void> logout() async {
    _session = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

  // ── 대시보드 ──

  Future<Dashboard> dashboard() async {
    final r = await _jsonRequest('GET', '/admin/dashboard');
    return Dashboard.fromJson(r['data'] as Map<String, dynamic>);
  }

  /// 서버 헬스 — Spring 은 CORS 가 /api/** 에만 열려 있어 브라우저에서 막힐 수 있다. 실패는 null(확인 불가).
  Future<Duration?> pingSpring() => _ping(Uri.parse('${_serverRoot()}/actuator/health'));
  Future<Duration?> pingFastApi() => _ping(Uri.parse('${config.fastApiBaseUrl}/health'));

  String _serverRoot() {
    final base = config.apiBaseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  Future<Duration?> _ping(Uri uri) async {
    final sw = Stopwatch()..start();
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 60));
      if (res.statusCode >= 200 && res.statusCode < 300) return sw.elapsed;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── 신고 ──

  Future<PagedResult<ReportItem>> reports({String status = 'PENDING', int page = 0, int size = 20}) async {
    final r = await _jsonRequest('GET', '/admin/reports', query: {'status': status, 'page': page, 'size': size});
    return PagedResult.fromJson(r['data'] as Map<String, dynamic>, ReportItem.fromJson);
  }

  Future<ReportItem> resolveReport(int reportId, {required String action, String? memo}) async {
    final r = await _jsonRequest('POST', '/admin/reports/$reportId/resolve', body: {'action': action, 'memo': memo});
    return ReportItem.fromJson(r['data'] as Map<String, dynamic>);
  }

  // ── 회원 ──

  Future<PagedResult<UserItem>> users({String query = '', int page = 0, int size = 20}) async {
    final r = await _jsonRequest('GET', '/admin/users', query: {if (query.isNotEmpty) 'query': query, 'page': page, 'size': size});
    return PagedResult.fromJson(r['data'] as Map<String, dynamic>, UserItem.fromJson);
  }

  Future<UserItem> suspendUser(int userId, {required int? days, required String reason}) async {
    final r = await _jsonRequest('POST', '/admin/users/$userId/suspend', body: {'days': days, 'reason': reason});
    return UserItem.fromJson(r['data'] as Map<String, dynamic>);
  }

  Future<UserItem> unsuspendUser(int userId) async {
    final r = await _jsonRequest('DELETE', '/admin/users/$userId/suspend');
    return UserItem.fromJson(r['data'] as Map<String, dynamic>);
  }

  Future<UserItem> resetNickname(int userId) async {
    final r = await _jsonRequest('POST', '/admin/users/$userId/nickname-reset');
    return UserItem.fromJson(r['data'] as Map<String, dynamic>);
  }

  Future<UserItem> changeRole(int userId, String role) async {
    final r = await _jsonRequest('POST', '/admin/users/$userId/role', body: {'role': role});
    return UserItem.fromJson(r['data'] as Map<String, dynamic>);
  }

  // ── 지역 ──

  Future<List<RegionItem>> regions() async {
    final r = await _jsonRequest('GET', '/admin/regions');
    return (r['data'] as List).map((e) => RegionItem(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<RegionItem> saveRegion(int? regionId, Map<String, dynamic> body) async {
    final r = regionId == null
        ? await _jsonRequest('POST', '/admin/regions', body: body)
        : await _jsonRequest('PUT', '/admin/regions/$regionId', body: body);
    return RegionItem(Map<String, dynamic>.from(r['data'] as Map));
  }

  // ── 공통 ──

  Map<String, String> _headers(bool auth) => {
        'Content-Type': 'application/json',
        if (auth && _session != null) 'Authorization': 'Bearer ${_session!.token}',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(config.apiBaseUrl);
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(
      path: '$basePath$path',
      queryParameters: query == null || query.isEmpty ? null : query.map((k, v) => MapEntry(k, v?.toString())),
    );
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final uri = _uri(path, query);
    final headers = _headers(auth);
    late http.Response response;
    try {
      // Render 무료 인스턴스는 슬립에서 깨는 데 최대 4분이 걸린다.
      const timeout = Duration(seconds: 240);
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(timeout);
        case 'POST':
          response = await http.post(uri, headers: headers, body: jsonEncode(body ?? const {})).timeout(timeout);
        case 'PUT':
          response = await http.put(uri, headers: headers, body: jsonEncode(body ?? const {})).timeout(timeout);
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(timeout);
        default:
          throw UnsupportedError('Unsupported method: $method');
      }
    } catch (e) {
      // 릴리즈 빌드는 타입명이 난독화되므로 사용자에게는 원인 대신 다음 행동만 알린다.
      throw AdminApiException(0, '서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.');
    }

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded == null || decoded['success'] == false) {
      final message = decoded?['message'] as String? ?? 'API 오류 ${response.statusCode}';
      if (response.statusCode == 401 && auth) {
        _session = null;
        onSessionExpired?.call();
      }
      throw AdminApiException(response.statusCode, message);
    }
    return decoded;
  }
}
