import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_scope.dart';
import '../mock_ui/screens/community.dart' show CommunityWriteScreen;
import '../mock_ui/screens/my_trips_tab.dart' show regionEmojiOf;
import '../mock_ui/state/app_state.dart' as mock;
import '../mock_ui/theme/app_colors.dart';
import '../mock_ui/widgets/ui.dart';
import '../models/app_models.dart';
import 'planner_screen.dart';
import 'submission_package_screen.dart';

/// 지난 여행 상세 — 목업 past_trip 1:1, 데이터는 TripDetail(실 repository).
/// 후기는 커뮤니티 백엔드(핸드오프 J) 전까지 미작성 상태만 존재한다.
class PastTripScreen extends StatefulWidget {
  const PastTripScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<PastTripScreen> createState() => _PastTripScreenState();
}

class _PastTripScreenState extends State<PastTripScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).repository.getTripDetail(widget.tripId);
  }

  void _goMallTab() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    mock.AppState.I.tabRequest.value = 2;
  }

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    return FutureBuilder<TripDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final detail = snapshot.data!;
        final trip = detail.trip;
        final course = AppScope.of(context).selectedCourseForTrip(trip.id);
        final authCount = detail.uploadedFiles
            .where((f) => f.fileCategory == FileCategory.authPhoto)
            .length;
        final hasLodging = detail.uploadedFiles
                .any((f) => f.fileCategory == FileCategory.lodgingConfirmation) ||
            detail.lodgingInfo?.uploadedFileId != null;
        final nights = trip.endDate.difference(trip.startDate).inDays;

        return DetailScaffold(
          title: '지난 여행',
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            // HERO
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  EmojiBox(regionEmojiOf(trip.regionName), size: 64, fontSize: 34, radius: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trip.regionName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
                      const SizedBox(height: 3),
                      Text('$nights박${nights + 1}일 · ${trip.travelerCount}명',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink4)),
                    ]),
                  ),
                  const Pill('정산 신청 완료', tone: PillTone.gold),
                ]),
                const SizedBox(height: 14),
                Text('${_d(trip.startDate)} ~ ${_d(trip.endDate)}${course != null ? ' · ${course.title}' : ''}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
              ]),
            ),
            // 다녀온 코스
            AppCard(
              padding: const EdgeInsets.all(14),
              child: SurfRow(
                icon: Icons.route_outlined,
                title: '다녀온 코스',
                subtitle: course == null
                    ? '저장된 코스가 없어요'
                    : '${course.title} · ${course.stops.length}곳',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PlannerScreen(tripId: trip.id))),
              ),
            ),
            // 내 후기 — 커뮤 로컬 글(서버 J 전까지 기기 저장)과 연동.
            _MyReviewCard(
              regionName: trip.regionName,
              onChanged: () => setState(() {}),
            ),
            // 여행 기록
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('여행 기록',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                const SizedBox(height: 8),
                _RecordRow(icon: Icons.photo_camera_outlined, label: '관광지 인증샷', value: '$authCount장'),
                _RecordRow(
                    icon: Icons.credit_card_rounded,
                    label: '영수증',
                    value: '${detail.receipts.length}건 · ${won.format(trip.totalSpentAmount)}원'),
                _RecordRow(icon: Icons.bed_outlined, label: '숙박확인서', value: hasLodging ? '1건' : '없음'),
                const SizedBox(height: 8),
                OutlineButton('제출한 증빙 패키지 보기',
                    icon: Icons.description_outlined,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SubmissionPackageScreen(
                            tripId: trip.id, detail: detail, showSettlementButton: false)))),
              ]),
            ),
            // 환급
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('환급',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(15)),
                  child: const Row(children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.success,
                      child: Icon(Icons.military_tech_rounded, size: 20, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('정산 신청 완료 · 환급 진행',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF177D43))),
                        SizedBox(height: 2),
                        Text('환급금은 지자체에서 개별 안내돼요. 보통 1~2개월 소요.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E9B5F))),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SurfRow(
                  icon: Icons.shopping_bag_outlined,
                  title: '환급금, 어디서 쓸까?',
                  subtitle: '${trip.regionName} 온라인몰 · 지역화폐 가맹점',
                  onTap: _goMallTab,
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

/// 내 후기 카드 — 이 지역의 내 글이 있으면 목업 '작성됨' 상태(나만보기 필·공개 전환),
/// 없으면 후기 쓰기 유도. 글은 커뮤 로컬 저장(AppState)과 공유.
class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({required this.regionName, required this.onChanged});
  final String regionName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final review = mock.AppState.I.posts
        .where((p) => p.mine && p.region == regionName)
        .firstOrNull;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('내 후기',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
          if (review != null && review.private) ...[
            const SizedBox(width: 8),
            const Pill('나만보기', tone: PillTone.gray, icon: Icons.lock_outline_rounded),
          ],
        ]),
        const SizedBox(height: 12),
        if (review == null) ...[
          const Text('아직 작성한 후기가 없어요.\n이번 여행을 기록으로 남겨보세요.',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
          const SizedBox(height: 14),
          OutlineButton('후기 쓰기',
              icon: Icons.edit_outlined,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CommunityWriteScreen(regionName: regionName)));
                onChanged();
              }),
        ] else ...[
          Text(review.text,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < review.photos.length && i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                EmojiBox(review.photos[i], size: 88, fontSize: 38, color: AppColors.surf),
              ],
            ]),
          ],
          if (review.private) ...[
            const SizedBox(height: 14),
            OutlineButton('공개로 전환하고 커뮤니티에 공유', onTap: () {
              mock.AppState.I.publishPost(review);
              onChanged();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('후기를 커뮤니티에 공개했어요.')));
            }),
          ],
        ],
      ]),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.ink5),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink7)),
        ),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink9)),
      ]),
    );
  }
}

String _d(DateTime d) => '${d.month}.${d.day}';
