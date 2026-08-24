import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';

/// 영수증 카드(S2-11) — 여행 종료 후 자동 생성 카드(금액 비공개).
/// 별점·한줄후기 입력 → 커뮤니티 피드 게시. (커뮤니티 백엔드 미구현 → 게시는 placeholder)
class ReceiptCardScreen extends StatefulWidget {
  const ReceiptCardScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<ReceiptCardScreen> createState() => _ReceiptCardScreenState();
}

class _ReceiptCardScreenState extends State<ReceiptCardScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;
  int _rating = 5;
  final _reviewController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = AppScope.of(context).repository.getTripDetail(widget.tripId);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _todo(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('영수증 카드')),
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
          final nights = trip.endDate.difference(trip.startDate).inDays;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // 카드 프리뷰
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.p400, AppColors.p600],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.route_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('${trip.regionName} $nights박${nights + 1}일',
                          style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        course == null
                            ? '다녀온 여행'
                            : '${course.title} · ${course.stops.length}곳',
                        style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 18),
                    Row(children: [
                      _CardStat(label: '관광지 인증', value: '$authCount곳'),
                      const SizedBox(width: 24),
                      _CardStat(
                          label: '함께', value: '${trip.travelerCount}명'),
                      const Spacer(),
                      Row(
                          children: List.generate(
                              5,
                              (i) => Icon(
                                  i < _rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 18,
                                  color: Colors.white))),
                    ]),
                    if (_reviewController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('"${_reviewController.text.trim()}"',
                          style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 13, color: Colors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('금액은 공개되지 않아요',
                          style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 별점
              const Text('별점',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink9)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                    5,
                    (i) => IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _rating = i + 1),
                          icon: Icon(
                              i < _rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 34,
                              color: i < _rating
                                  ? AppColors.warning
                                  : AppColors.gray),
                        )),
              ),
              const SizedBox(height: 14),

              // 한줄 후기
              const Text('한줄 후기',
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink9)),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewController,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink9),
                decoration: InputDecoration(
                  hintText: '이번 여행 어땠나요?',
                  hintStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink4),
                  filled: true,
                  fillColor: AppColors.surf,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나만 보기'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _todo('커뮤니티 피드 게시는 준비 중이에요.'),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('피드 게시'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85))),
      ],
    );
  }
}
