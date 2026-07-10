import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../mock_ui/screens/course_flow.dart';
import '../mock_ui/screens/region_detail.dart';
import '../mock_ui/screens/trip_detail.dart';
import '../mock_ui/state/app_state.dart' as mock;
import '../theme/app_colors.dart';

/// 알림 센터 — 리포지토리(mock/api)에서 알림을 불러와 오늘/지난 알림으로 그룹.
/// 계약: GET /api/notifications, POST /api/notifications/read-all (docs/backend-handoff G)
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  Future<List<AppNotification>>? _future;
  bool _initialized = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _load();
  }

  Future<List<AppNotification>> _load() {
    final controller = AppScope.of(context);
    final userId = controller.currentUser?.id;
    if (userId == null) return Future.value(const []);
    return controller.repository.getNotifications(userId);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markAllRead() async {
    setState(() => _busy = true);
    try {
      final controller = AppScope.of(context);
      final userId = controller.currentUser?.id;
      if (userId != null) {
        await controller.repository.markAllNotificationsRead(userId);
      }
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 알림 탭 → refType/refId 딥링크 (계약: 핸드오프 G).
  /// 백엔드가 참조를 안 주면(딥링크 미배포) 탭해도 아무 동작 안 함.
  Future<void> _open(AppNotification noti) async {
    final refId = noti.refId;
    if (refId == null) return;
    final nav = Navigator.of(context);
    switch (noti.refType) {
      case 'TRIP':
        await nav.push(
          MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: refId)),
        );
      case 'COURSE':
        await nav.push(
          MaterialPageRoute(builder: (_) => const CourseSavedScreen()),
        );
      case 'REGION':
        await _openRegion(refId);
      case 'POST':
        // 커뮤니티 백엔드(핸드오프 J) 전까지는 커뮤니티 탭으로.
        mock.AppState.I.tabRequest.value = 3;
        nav.pop();
      case 'MERCHANT':
        mock.AppState.I.tabRequest.value = 2;
        nav.pop();
    }
    if (mounted) await _reload();
  }

  /// 실서버 regionId → 지역명 → 지역 상세(목업 데이터 기반) 진입.
  Future<void> _openRegion(int regionId) async {
    try {
      final controller = AppScope.of(context);
      final regions = await controller.repository.getRegions(
        residence: controller.currentUser?.residence,
      );
      final match = regions.where((r) => r.id == regionId).firstOrNull;
      if (match == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => RegionDetailScreen(
                region: mock.AppState.I.regionByName(match.name),
              ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          FutureBuilder<List<AppNotification>>(
            future: _future,
            builder: (context, snapshot) {
              final hasUnread = snapshot.data?.any((n) => !n.read) ?? false;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: _busy ? null : _markAllRead,
                child: const Text('모두 읽음'),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) return const _EmptyNotifications();

            final now = DateTime.now();
            final today =
                items
                    .where((n) => DateUtils.isSameDay(n.createdAt, now))
                    .toList();
            final earlier =
                items
                    .where((n) => !DateUtils.isSameDay(n.createdAt, now))
                    .toList();

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (today.isNotEmpty) ...[
                    const _GroupLabel('오늘'),
                    ...today.map((n) => _NotiRow(n, onTap: () => _open(n))),
                  ],
                  if (earlier.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const _GroupLabel('지난 알림'),
                    ...earlier.map((n) => _NotiRow(n, onTap: () => _open(n))),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 알림 유형 → 아이콘·색 팔레트 매핑 (프레젠테이션 전용).
(IconData, Color, Color) _presentation(NotificationType type) => switch (type) {
  NotificationType.regionOpen => (
    Icons.flag_outlined,
    AppColors.p100,
    AppColors.p600,
  ),
  NotificationType.courseDone => (
    Icons.route_outlined,
    AppColors.p100,
    AppColors.p600,
  ),
  NotificationType.communityLike => (
    Icons.favorite,
    AppColors.coralTint,
    AppColors.coralDeep,
  ),
  NotificationType.communityComment => (
    Icons.chat_bubble_outline,
    AppColors.p100,
    AppColors.p600,
  ),
  NotificationType.settleDeadline => (
    Icons.schedule_outlined,
    const Color(0xFFFFF3E2),
    const Color(0xFFB8731B),
  ),
  NotificationType.benefit => (
    Icons.card_giftcard_outlined,
    AppColors.track,
    AppColors.ink5,
  ),
  NotificationType.unknown => (
    Icons.notifications_none_rounded,
    AppColors.track,
    AppColors.ink5,
  ),
};

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays == 1) return '어제';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${diff.inDays ~/ 7}주 전';
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink5,
        ),
      ),
    );
  }
}

class _NotiRow extends StatelessWidget {
  const _NotiRow(this.noti, {required this.onTap});
  final AppNotification noti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _presentation(noti.type);
    final unread = !noti.read;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? AppColors.p50 : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.field),
          boxShadow: unread ? null : AppShadows.soft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noti.title,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink9,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    noti.body,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.ink5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(noti.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink4,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.p500,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.surf,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 30,
              color: AppColors.ink4,
            ),
          ),
          const SizedBox(height: 16),
          Text('새로운 알림이 없어요', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            '접수 시작·정산 마감·좋아요 소식이 오면 여기에 모아둘게요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              height: 1.5,
              color: AppColors.ink5,
            ),
          ),
        ],
      ),
    );
  }
}
