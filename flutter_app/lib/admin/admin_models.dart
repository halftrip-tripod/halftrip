/// 관리자 콘솔 모델 — 서버 AdminDtos 와 1:1. 개인정보 필드(이메일·거주지·전화)는 서버가 내려주지 않는다.
library;

class AdminSession {
  const AdminSession({required this.userId, required this.token, required this.loginId, required this.role});

  final int userId;
  final String token;
  final String loginId;
  final String role;

  bool get isAdmin => role == 'ADMIN';

  Map<String, dynamic> toJson() => {'userId': userId, 'token': token, 'loginId': loginId, 'role': role};

  factory AdminSession.fromJson(Map<String, dynamic> json) => AdminSession(
        userId: json['userId'] as int,
        token: json['token'] as String,
        loginId: json['loginId'] as String? ?? '',
        role: json['role'] as String? ?? 'USER',
      );
}

DateTime? _dt(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;
String? _str(Object? v) => v?.toString();
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class DailyCounts {
  const DailyCounts({required this.date, required this.signups, required this.trips, required this.settlements, required this.posts, required this.comments});
  final String date;
  final int signups, trips, settlements, posts, comments;
  factory DailyCounts.fromJson(Map<String, dynamic> j) => DailyCounts(
        date: j['date'] as String? ?? '',
        signups: _int(j['signups']), trips: _int(j['trips']), settlements: _int(j['settlements']),
        posts: _int(j['posts']), comments: _int(j['comments']));
}

class RegionStatus {
  const RegionStatus({required this.id, required this.name, required this.province, required this.statusCode, this.roundLabel, this.applyStartDate, this.applyDeadline, required this.merchantCount, required this.placeCount, required this.digitalPlaceCount, required this.syncLocked});
  final int id;
  final String name, province, statusCode;
  final String? roundLabel, applyStartDate, applyDeadline;
  final int merchantCount, placeCount, digitalPlaceCount;
  final bool syncLocked;
  bool get dataMissing => merchantCount == 0 || placeCount == 0;
  factory RegionStatus.fromJson(Map<String, dynamic> j) => RegionStatus(
        id: _int(j['id']), name: j['name'] as String? ?? '', province: j['province'] as String? ?? '',
        statusCode: j['statusCode'] as String? ?? 'PREPARING', roundLabel: _str(j['roundLabel']),
        applyStartDate: _str(j['applyStartDate']), applyDeadline: _str(j['applyDeadline']),
        merchantCount: _int(j['merchantCount']), placeCount: _int(j['placeCount']), digitalPlaceCount: _int(j['digitalPlaceCount']),
        syncLocked: j['syncLocked'] == true);
}

class BatchRunItem {
  const BatchRunItem({required this.name, this.lastStartedAt, this.lastFinishedAt, this.lastStatus, this.lastSummary});
  final String name;
  final DateTime? lastStartedAt, lastFinishedAt;
  final String? lastStatus, lastSummary;
  factory BatchRunItem.fromJson(Map<String, dynamic> j) => BatchRunItem(
        name: j['name'] as String? ?? '', lastStartedAt: _dt(j['lastStartedAt']), lastFinishedAt: _dt(j['lastFinishedAt']),
        lastStatus: _str(j['lastStatus']), lastSummary: _str(j['lastSummary']));
}

class Dashboard {
  const Dashboard({required this.today, required this.yesterday, required this.pendingReports, required this.totalUsers, required this.totalTrips, required this.regions, required this.batches, this.serverTime});
  final DailyCounts today, yesterday;
  final int pendingReports, totalUsers, totalTrips;
  final List<RegionStatus> regions;
  final List<BatchRunItem> batches;
  final DateTime? serverTime;
  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        today: DailyCounts.fromJson(j['today'] as Map<String, dynamic>),
        yesterday: DailyCounts.fromJson(j['yesterday'] as Map<String, dynamic>),
        pendingReports: _int(j['pendingReports']), totalUsers: _int(j['totalUsers']), totalTrips: _int(j['totalTrips']),
        regions: (j['regions'] as List? ?? const []).map((e) => RegionStatus.fromJson(e as Map<String, dynamic>)).toList(),
        batches: (j['batches'] as List? ?? const []).map((e) => BatchRunItem.fromJson(e as Map<String, dynamic>)).toList(),
        serverTime: _dt(j['serverTime']));
}

class PagedResult<T> {
  const PagedResult({required this.items, required this.page, required this.size, required this.total});
  final List<T> items;
  final int page, size, total;
  int get pageCount => size == 0 ? 1 : (total + size - 1) ~/ size;
  factory PagedResult.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) => PagedResult(
        items: (j['items'] as List? ?? const []).map((e) => parse(e as Map<String, dynamic>)).toList(),
        page: _int(j['page']), size: _int(j['size']), total: _int(j['total']));
}

class ReportItem {
  const ReportItem({required this.id, required this.targetType, required this.targetId, this.reason, required this.status, this.action, this.memo, this.createdAt, this.handledAt, this.handledBy, this.reporterId, this.reporterNickname, this.authorId, this.authorNickname, this.postId, this.targetTitle, this.targetBody, required this.targetRemoved, required this.targetReportCount, required this.authorReportedCount});
  final int id, targetId;
  final String targetType, status;
  final String? reason, action, memo, reporterNickname, authorNickname, targetTitle, targetBody;
  final DateTime? createdAt, handledAt;
  final int? handledBy, reporterId, authorId, postId;
  final bool targetRemoved;
  final int targetReportCount, authorReportedCount;
  bool get isComment => targetType == 'COMMENT';
  bool get isPending => status == 'PENDING';
  factory ReportItem.fromJson(Map<String, dynamic> j) => ReportItem(
        id: _int(j['id']), targetType: j['targetType'] as String? ?? 'POST', targetId: _int(j['targetId']),
        reason: _str(j['reason']), status: j['status'] as String? ?? 'PENDING', action: _str(j['action']), memo: _str(j['memo']),
        createdAt: _dt(j['createdAt']), handledAt: _dt(j['handledAt']), handledBy: j['handledBy'] as int?,
        reporterId: j['reporterId'] as int?, reporterNickname: _str(j['reporterNickname']),
        authorId: j['authorId'] as int?, authorNickname: _str(j['authorNickname']), postId: j['postId'] as int?,
        targetTitle: _str(j['targetTitle']), targetBody: _str(j['targetBody']), targetRemoved: j['targetRemoved'] == true,
        targetReportCount: _int(j['targetReportCount']), authorReportedCount: _int(j['authorReportedCount']));
}

class UserItem {
  const UserItem({required this.id, this.nickname, this.avatarPreset, this.provider, required this.role, this.createdAt, required this.withdrawn, required this.postCount, required this.commentCount, required this.reportedCount, required this.blockedCount, required this.suspended, required this.permanentSuspension, this.suspendedUntil, this.suspendReason});
  final int id;
  final String? nickname, avatarPreset, provider, suspendReason;
  final String role;
  final DateTime? createdAt, suspendedUntil;
  final bool withdrawn, suspended, permanentSuspension;
  final int postCount, commentCount, reportedCount, blockedCount;
  bool get isAdmin => role == 'ADMIN';
  String get displayName => withdrawn ? '탈퇴한 사용자' : (nickname ?? '(닉네임 없음)');
  factory UserItem.fromJson(Map<String, dynamic> j) => UserItem(
        id: _int(j['id']), nickname: _str(j['nickname']), avatarPreset: _str(j['avatarPreset']), provider: _str(j['provider']),
        role: j['role'] as String? ?? 'USER', createdAt: _dt(j['createdAt']), withdrawn: j['withdrawn'] == true,
        postCount: _int(j['postCount']), commentCount: _int(j['commentCount']), reportedCount: _int(j['reportedCount']),
        blockedCount: _int(j['blockedCount']), suspended: j['suspended'] == true, permanentSuspension: j['permanentSuspension'] == true,
        suspendedUntil: _dt(j['suspendedUntil']), suspendReason: _str(j['suspendReason']));
}

/// 지역 — 컬럼이 31개라 표 전용 필드만 타입을 두고, 편집 폼은 raw 맵을 그대로 다룬다(RegionSaveRequest 와 키가 같다).
class RegionItem {
  RegionItem(this.raw);
  final Map<String, dynamic> raw;

  static const readOnlyKeys = {'id', 'merchantCount', 'placeCount', 'digitalPlaceCount', 'updatedAt'};

  int get id => _int(raw['id']);
  String get name => raw['name'] as String? ?? '';
  String get province => raw['province'] as String? ?? '';
  String get statusCode => raw['statusCode'] as String? ?? 'PREPARING';
  String? get roundLabel => _str(raw['roundLabel']);
  String? get applyStartDate => _str(raw['applyStartDate']);
  String? get applyDeadline => _str(raw['applyDeadline']);
  String? get travelPeriodStart => _str(raw['travelPeriodStart']);
  String? get travelPeriodEnd => _str(raw['travelPeriodEnd']);
  int? get settlementDeadlineDays => raw['settlementDeadlineDays'] as int?;
  int get merchantCount => _int(raw['merchantCount']);
  int get placeCount => _int(raw['placeCount']);
  int get digitalPlaceCount => _int(raw['digitalPlaceCount']);
  bool get syncLocked => raw['syncLocked'] == true;
  DateTime? get updatedAt => _dt(raw['updatedAt']);

  /// PUT /api/admin/regions/{id} 본문 — 읽기 전용 키는 뺀다.
  Map<String, dynamic> toSaveBody() => {for (final e in raw.entries) if (!readOnlyKeys.contains(e.key)) e.key: e.value};

  static Map<String, dynamic> emptyBody() => {
        'name': '', 'province': '', 'eligibleForResidenceMatch': true, 'halfPriceApplyUrl': '', 'digitalTourCardApplyUrl': '',
        'refundConditionAmount': 0, 'mockBudgetRemaining': 0, 'dataSourceNote': '관리자 콘솔 입력', 'statusCode': 'PREPARING',
        'digitalBenefitAvailable': false, 'displayOrder': 0, 'syncLocked': false,
      };
}

String statusLabel(String code) => switch (code) { 'APPLYING' => '접수중', 'CLOSED' => '마감', _ => '준비중' };
String providerLabel(String? p) => switch (p) { 'KAKAO' => '카카오', 'NAVER' => '네이버', 'GOOGLE' => '구글', 'GUEST' => '게스트', 'LOCAL' => '로컬', _ => p ?? '-' };
String reasonLabel(String? r) => (r == null || r.isEmpty) ? '(사유 없음)' : r;

String fmtDate(DateTime? d) => d == null ? '—' : '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
String fmtDateTime(DateTime? d) => d == null ? '—' : '${fmtDate(d)} ${pad2(d.hour)}:${pad2(d.minute)}';
String fmtShort(DateTime? d) {
  if (d == null) return '—';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return '오늘 ${pad2(d.hour)}:${pad2(d.minute)}';
  return '${pad2(d.month)}-${pad2(d.day)} ${pad2(d.hour)}:${pad2(d.minute)}';
}
String fmtNum(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
String pad2(int v) => v.toString().padLeft(2, '0');
