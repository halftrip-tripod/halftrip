import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../widgets/app_shell.dart';
import 'auth_photo_upload_screen.dart';
import 'lodging_form_screen.dart';
import 'place_info_screen.dart';
import 'planner_screen.dart';
import 'receipt_evidence_screen.dart';
import 'saved_course_list_screen.dart';
import 'settlement_screen.dart';
import 'submission_package_screen.dart';
import 'youtube_course_analysis_screen.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _future = _loadDetail();
    _initialized = true;
  }

  Future<TripDetail> _loadDetail() {
    return AppScope.of(context).repository.getTripDetail(widget.tripId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadDetail();
    });
    await AppScope.of(context).refreshTrips();
  }

  Future<void> _openAuthPhotoScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthPhotoUploadScreen(tripId: widget.tripId),
      ),
    );
    await _reload();
  }

  Future<void> _openReceiptScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptEvidenceScreen(tripId: widget.tripId),
      ),
    );
    await _reload();
  }

  Future<void> _openLodgingForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LodgingFormScreen(tripId: widget.tripId),
      ),
    );
    await _reload();
  }

  Future<void> _openPlanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlannerScreen(tripId: widget.tripId),
      ),
    );
    await _reload();
  }

  Future<void> _openSettlement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettlementScreen(tripId: widget.tripId),
      ),
    );
    await _reload();
  }

  Future<void> _openSubmissionPackage(TripDetail detail) async {
    final hasEvidence =
        detail.uploadedFiles.any(
          (file) =>
              file.fileCategory == FileCategory.authPhoto ||
              file.fileCategory == FileCategory.receiptImage ||
              file.fileCategory == FileCategory.lodgingConfirmation,
        ) ||
        detail.lodgingInfo?.uploadedFileId != null;

    if (!hasEvidence) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제출할 증빙이 아직 없습니다.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmissionPackageScreen(
          tripId: widget.tripId,
          detail: detail,
        ),
      ),
    );
  }

  Future<void> _openCourseActions(TripDetail detail) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TripCourseActionSheet(
        detail: detail,
        onOpenAiCourse: () => _openYoutubeCourseSheet(detail),
      ),
    );
    await _reload();
  }

  Future<void> _openYoutubeCourseSheet(TripDetail detail) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AiCourseThemeSheet(
        onGenerate: (youtubeUrl) =>
            _openAiCourseBuilder(detail, youtubeUrl),
      ),
    );
    await _reload();
  }

  Future<void> _openAiCourseBuilder(
    TripDetail detail,
    String youtubeUrl,
  ) async {
    if (!mounted) return;
    if (youtubeUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유튜브 링크를 입력해 주세요.')),
      );
      return;
    }

    final controller = AppScope.of(context);
    final userId = controller.currentUser?.id;
    if (userId != null) {
      final activeJob = await controller.repository.getActiveYoutubeCourseJob(
        userId: userId,
        tripId: detail.trip.id,
      );
      if (activeJob != null) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => YoutubeCourseAnalysisScreen(
              tripDetail: detail,
              jobId: activeJob.jobId,
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YoutubeCourseAnalysisScreen(
          tripDetail: detail,
          youtubeUrl: youtubeUrl,
        ),
      ),
    );
  }

  List<_ChecklistItemData> _buildChecklist(TripDetail detail) {
    final authPhotoCount = detail.uploadedFiles
        .where((file) => file.fileCategory == FileCategory.authPhoto)
        .length;
    final hasApprovedReceipt = detail.receipts.any(
      (receipt) => receipt.reviewStatus == ReceiptReviewStatus.approved,
    );
    final hasLodgingConfirmation =
        detail.uploadedFiles.any(
          (file) => file.fileCategory == FileCategory.lodgingConfirmation,
        ) ||
        detail.lodgingInfo?.uploadedFileId != null;

    return [
      _ChecklistItemData(
        title: '관광지 인증사진 ($authPhotoCount/2)',
        subtitle: '필수 · 2곳 중 ${authPhotoCount.clamp(0, 2)}곳 완료',
        icon: Icons.photo_camera_back_rounded,
        completed: authPhotoCount >= 2,
        onTap: _openAuthPhotoScreen,
      ),
      _ChecklistItemData(
        title: '영수증 증빙 (${detail.receipts.length})',
        subtitle: detail.receipts.isEmpty
            ? '필수 · 등록된 영수증이 아직 없어요'
            : '필수 · ${detail.receipts.length}건 등록',
        icon: Icons.receipt_long_rounded,
        completed: hasApprovedReceipt,
        onTap: _openReceiptScreen,
      ),
      _ChecklistItemData(
        title: '숙박확인서',
        subtitle: hasLodgingConfirmation ? '필수 · 숙박확인서 제출 완료' : '필수 · 전자 서명 대기',
        icon: Icons.apartment_rounded,
        completed: hasLodgingConfirmation,
        onTap: _openLodgingForm,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('yyyy.MM.dd');

    return AppShell(
      title: '내 여행',
      modeName: AppScope.of(context).modeName,
      child: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final controller = AppScope.of(context);
          final detail = snapshot.data!;
          final trip = detail.trip;
          final plannerPlaces = [...detail.selectedPlaces]
            ..sort((a, b) => a.visitOrder.compareTo(b.visitOrder));
          final selectedCourse = controller.selectedCourseForTrip(trip.id);
          final places = selectedCourse != null
              ? selectedCourse.stops
                  .map(
                    (stop) => TripPlaceItem(
                      id: stop.placeId,
                      placeType: stop.sourceType.toUpperCase() ==
                              PlaceCategory.merchant.wireName
                          ? PlaceCategory.merchant
                          : stop.sourceType.toUpperCase() ==
                                  PlaceCategory.digitalTourCard.wireName
                              ? PlaceCategory.digitalTourCard
                              : PlaceCategory.halfPrice,
                      referencePlaceId: stop.placeId,
                      placeName: stop.name,
                      address: stop.address,
                      visitOrder: selectedCourse.stops.indexOf(stop) + 1,
                      latitude: stop.latitude,
                      longitude: stop.longitude,
                      checked: true,
                    ),
                  )
                  .toList()
              : plannerPlaces;
          final progress = trip.refundConditionAmount == 0
              ? 0.0
              : detail.settlementSummary.totalSpentAmount / trip.refundConditionAmount;
          final checklistItems = _buildChecklist(detail);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _TripSummaryCard(
                  regionName: trip.regionName,
                  dateText:
                      '${dateFormatter.format(trip.startDate)} - ${dateFormatter.format(trip.endDate)}',
                  spentAmount: detail.settlementSummary.totalSpentAmount,
                  goalAmount: trip.refundConditionAmount,
                  progress: progress.clamp(0.0, 1.0),
                  summaryMessage: detail.settlementSummary.statusMessage,
                ),
                const SizedBox(height: 16),
                _ChecklistCard(items: checklistItems),
                const SizedBox(height: 12),
                _PrimaryActionButton(
                  label: '제출물 통합',
                  icon: Icons.picture_as_pdf_rounded,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF111827),
                  borderColor: const Color(0xFFD7DEE8),
                  onTap: () => _openSubmissionPackage(detail),
                ),
                const SizedBox(height: 16),
                _CourseCard(
                  courseTitle: selectedCourse?.title,
                  places: places,
                  onCreateCourse: () => _openCourseActions(detail),
                  onOpenPlanner: places.isEmpty ? null : _openPlanner,
                ),
                const SizedBox(height: 12),
                _PrimaryActionButton(
                  label: '정산 신청',
                  icon: Icons.open_in_new_rounded,
                  backgroundColor: const Color(0xFF16A34A),
                  onTap: _openSettlement,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({
    required this.regionName,
    required this.dateText,
    required this.spentAmount,
    required this.goalAmount,
    required this.progress,
    required this.summaryMessage,
  });

  final String regionName;
  final String dateText;
  final int spentAmount;
  final int goalAmount;
  final double progress;
  final String summaryMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            regionName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            dateText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            '소비 현황',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              children: [
                TextSpan(
                  text: '${_formatWon(spentAmount)}원',
                  style: const TextStyle(color: Color(0xFF10B981)),
                ),
                TextSpan(
                  text: ' / 목표 ${_formatWon(goalAmount)}원',
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              summaryMessage,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWon(int amount) {
    return NumberFormat.decimalPattern('ko_KR').format(amount);
  }
}

class _ChecklistItemData {
  const _ChecklistItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final VoidCallback onTap;
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.items});

  final List<_ChecklistItemData> items;

  @override
  Widget build(BuildContext context) {
    final completedCount = items.where((item) => item.completed).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '제출 서류 현황',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
              ),
              const Spacer(),
              Text(
                '$completedCount/${items.length} 완료',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChecklistStatusRow(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistStatusRow extends StatelessWidget {
  const _ChecklistStatusRow({required this.item});

  final _ChecklistItemData item;

  @override
  Widget build(BuildContext context) {
    final statusLabel = item.completed ? '완료' : '미제출';
    final statusColor =
        item.completed ? const Color(0xFF16A34A) : const Color(0xFFEA580C);
    final statusBackground =
        item.completed ? const Color(0xFFE9F9EE) : const Color(0xFFFFF3E8);

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5EAF0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: const Color(0xFF334155)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    this.courseTitle,
    required this.places,
    required this.onCreateCourse,
    required this.onOpenPlanner,
  });

  final String? courseTitle;
  final List<TripPlaceItem> places;
  final VoidCallback onCreateCourse;
  final VoidCallback? onOpenPlanner;

  @override
  Widget build(BuildContext context) {
    final previewPlaces = places.take(5).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '내 코스',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
              ),
              const Spacer(),
              if (onOpenPlanner != null)
                TextButton(
                  onPressed: onOpenPlanner,
                  child: const Text('전체 보기'),
                ),
            ],
          ),
          if (courseTitle != null && courseTitle!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                courseTitle!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          const SizedBox(height: 10),
          if (previewPlaces.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '아직 담긴 코스가 없습니다. 코스 만들기에서 장소를 추가해 주세요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            )
          else
            ...previewPlaces.asMap().entries.map((entry) {
              final index = entry.key;
              final place = entry.value;
              final isFirst = index == 0;
              return Padding(
                padding: EdgeInsets.only(bottom: index == previewPlaces.length - 1 ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isFirst ? const Color(0xFF16A34A) : Colors.white,
                            border: Border.all(
                              color: isFirst
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD7DEE8),
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index != previewPlaces.length - 1)
                          Container(
                            width: 2,
                            height: 46,
                            color: const Color(0xFFE2E8F0),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.placeName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            place.address,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF64748B),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      index == 0 ? '완료' : '예정',
                      style: TextStyle(
                        color: index == 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCreateCourse,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    side: const BorderSide(color: Color(0xFFD7DEE8)),
                  ),
                  child: const Text(
                    '코스 만들기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (onOpenPlanner != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenPlanner,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '플래너 보기',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ??
        (backgroundColor == Colors.white ? const Color(0xFF111827) : Colors.white);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: backgroundColor,
          foregroundColor: foreground,
          side: borderColor == null ? null : BorderSide(color: borderColor!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _TripCourseActionSheet extends StatelessWidget {
  const _TripCourseActionSheet({
    required this.detail,
    required this.onOpenAiCourse,
  });

  final TripDetail detail;
  final Future<void> Function() onOpenAiCourse;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '코스 관리',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '지금 여행에 담긴 코스를 불러오거나, AI 추천 또는 직접 선택으로 새 코스를 만들 수 있어요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),
            _SheetActionTile(
              icon: Icons.route_rounded,
              title: '코스 불러오기',
              subtitle: '지금 저장된 여행 동선을 열어 순서를 바꾸고 제거할 수 있어요.',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SavedCourseListScreen(tripDetail: detail),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _SheetActionTile(
              icon: Icons.auto_awesome_rounded,
              title: 'AI 코스 생성',
              subtitle: '어떤 테마로 여행할지 고르고 추천 코스 흐름으로 넘어갈 수 있어요.',
              onTap: () async {
                Navigator.of(context).pop();
                await onOpenAiCourse();
              },
            ),
            const SizedBox(height: 12),
            _SheetActionTile(
              icon: Icons.map_outlined,
              title: '직접 코스 만들기',
              subtitle: '지도에서 관광지를 눌러 원하는 순서대로 코스를 구성해 보세요.',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaceInfoScreen(tripId: detail.trip.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCourseThemeSheet extends StatefulWidget {
  const _AiCourseThemeSheet({
    required this.onGenerate,
  });

  final Future<void> Function(String youtubeUrl) onGenerate;

  @override
  State<_AiCourseThemeSheet> createState() => _AiCourseThemeSheetState();
}

class _AiCourseThemeSheetState extends State<_AiCourseThemeSheet> {
  static const List<String> _allThemes = ['자연', '문화', '맛집', '체험'];
  final bool _showThemeSection = false;
  late final List<String> _availableThemes;
  final List<String> _selectedThemes = [];
  final TextEditingController _youtubeUrlController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _availableThemes = [..._allThemes];
  }

  void _addTheme(String theme) {
    if (_selectedThemes.contains(theme)) return;
    setState(() {
      _availableThemes.remove(theme);
      _selectedThemes.add(theme);
    });
  }

  void _removeTheme(String theme) {
    if (!_selectedThemes.contains(theme)) return;
    setState(() {
      _selectedThemes.remove(theme);
      if (!_availableThemes.contains(theme)) {
        _availableThemes.add(theme);
      }
    });
  }

  Future<void> _goToPlanner() async {
    if (_submitting) return;
    final youtubeUrl = _youtubeUrlController.text.trim();
    if (youtubeUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유튜브 링크를 입력해 주세요.')),
      );
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      Navigator.of(context).pop();
      await widget.onGenerate(youtubeUrl);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _youtubeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '어떤 테마로 여행하고 싶으신가요?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '카드를 끌어 아래 선택 영역에 담아 주세요. 유튜브 링크를 함께 넣으면 자막과 영상 이미지 단서를 바탕으로 추천 코스를 미리 구성합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _youtubeUrlController,
              decoration: InputDecoration(
                labelText: '유튜브 링크 입력',
                hintText: '완도 여행 브이로그 링크를 붙여넣어 주세요.',
                helperText: '자막이 있으면 자막을 우선 사용하고, 부족한 단서는 영상 이미지 분석으로 보완합니다.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
            ),
            if (_showThemeSection) ...[
            const SizedBox(height: 20),
            Text(
              '테마 선택',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableThemes.map((theme) {
                return Draggable<String>(
                  data: theme,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _ThemeChip(label: theme, selected: false),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: _ThemeChip(label: theme, selected: false),
                  ),
                  child: _ThemeChip(label: theme, selected: false),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              '선택한 테마',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            DragTarget<String>(
              onAcceptWithDetails: (details) => _addTheme(details.data),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: _selectedThemes.isEmpty
                      ? Text(
                          '여기로 드래그해서 담아 주세요.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _selectedThemes.map((theme) {
                            return GestureDetector(
                              onTap: () => _removeTheme(theme),
                              child: _ThemeChip(label: theme, selected: true),
                            );
                          }).toList(),
                        ),
                );
              },
            ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _goToPlanner,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '생성하기',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF16A34A) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xFF16A34A) : const Color(0xFFD7DEE8),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? Colors.white : const Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
