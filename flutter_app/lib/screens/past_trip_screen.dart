import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/pill.dart';
import 'planner_screen.dart';
import 'receipt_card_screen.dart';
import 'submission_package_screen.dart';

/// 지난 여행 상세 — 다녀온 코스·여행 기록·증빙·환급.
/// 디자인: halftrip-design/past-trip.html
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

  void _todo(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final won = NumberFormat('#,###');
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('지난 여행')),
      body: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // HERO
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('${trip.regionName} $nights박${nights + 1}일',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      const Pill('환급 완료', tone: PillTone.gold),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '${_d(trip.startDate)} ~ ${_d(trip.endDate)} · ${trip.travelerCount}명',
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          color: AppColors.ink5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 다녀온 코스
              _Section(
                title: '다녀온 코스',
                child: _LinkRow(
                  icon: Icons.route_rounded,
                  iconColor: AppColors.p600,
                  bg: AppColors.p50,
                  title: course?.title ?? '코스 기록 없음',
                  subtitle: course == null
                      ? '저장된 코스가 없어요'
                      : '${course.regionName} · ${course.stops.length}곳',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlannerScreen(tripId: trip.id))),
                ),
              ),
              const SizedBox(height: 14),

              // 내 후기
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text('내 후기',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      const Pill('나만보기',
                          tone: PillTone.gray, icon: Icons.lock_outline_rounded),
                    ]),
                    const SizedBox(height: 12),
                    const Text('아직 작성한 후기가 없어요. 영수증 카드로 이번 여행을 기록해보세요.',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.ink5)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  ReceiptCardScreen(tripId: trip.id))),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('후기 쓰기'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.field))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 여행 기록
              _Section(
                title: '여행 기록',
                child: Column(children: [
                  _RecordRow(
                      icon: Icons.photo_camera_outlined,
                      label: '관광지 인증샷',
                      value: '$authCount장'),
                  _RecordRow(
                      icon: Icons.receipt_long_outlined,
                      label: '영수증',
                      value:
                          '${detail.receipts.length}건 · ${won.format(trip.totalSpentAmount)}원'),
                  _RecordRow(
                      icon: Icons.hotel_outlined,
                      label: '숙박확인서',
                      value: hasLodging ? '1건' : '없음'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => SubmissionPackageScreen(
                                tripId: trip.id,
                                detail: detail,
                                showSettlementButton: false))),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('제출한 증빙 패키지 보기'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.field))),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // 환급
              _Section(
                title: '환급',
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFBF1D5), shape: BoxShape.circle),
                      child: const Icon(Icons.workspace_premium_outlined,
                          color: Color(0xFFA9790C), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('정산 신청 완료 · 환급 진행',
                                style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink9)),
                            SizedBox(height: 2),
                            Text('환급금은 지자체에서 개별 안내돼요. 보통 1~2개월 소요.',
                                style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: AppColors.ink5)),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _LinkRow(
                    icon: Icons.storefront_outlined,
                    iconColor: AppColors.ink7,
                    bg: AppColors.surf,
                    title: '환급금, 어디서 쓸까?',
                    subtitle: '${trip.regionName} 온라인몰 · 가맹점 지도',
                    onTap: () => _todo('온라인몰 탭에서 확인할 수 있어요.'),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: AppColors.white, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink9)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          color: AppColors.ink5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
          ]),
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(
      {required this.icon, required this.label, required this.value});
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
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink7)),
        ),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink9)),
      ]),
    );
  }
}

String _d(DateTime d) => '${d.month}.${d.day}';
