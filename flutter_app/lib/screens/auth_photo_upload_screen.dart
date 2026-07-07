import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';

/// 관광지 인증샷 — 기본 카메라 사진 업로드 → 위치·시간(EXIF)·인원·얼굴/배경 자동 판정.
/// 디자인: halftrip-design/auth-photo.html
class AuthPhotoUploadScreen extends StatefulWidget {
  const AuthPhotoUploadScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<AuthPhotoUploadScreen> createState() => _AuthPhotoUploadScreenState();
}

class _AuthPhotoUploadScreenState extends State<AuthPhotoUploadScreen> {
  Future<TripDetail>? _future;
  bool _initialized = false;
  bool _uploading = false;
  final Map<int, Uint8List> _previewBytesByFileId = {};

  // 가장 최근 분석한 사진의 미리보기·판정 결과 (판정 패널 표시용)
  Uint8List? _lastPreview;
  AuthPhotoReviewResult? _lastReview;

  static const _required = 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _future = _loadDetail();
  }

  Future<TripDetail> _loadDetail() async {
    final repository = AppScope.of(context).repository;
    final detail = await repository.getTripDetail(widget.tripId);
    await _hydratePreviews(detail);
    return detail;
  }

  Future<void> _hydratePreviews(TripDetail detail) async {
    final repository = AppScope.of(context).repository;
    final authFiles = detail.uploadedFiles.where(
      (file) =>
          file.fileCategory == FileCategory.authPhoto &&
          !_previewBytesByFileId.containsKey(file.id),
    );
    for (final file in authFiles) {
      try {
        _previewBytesByFileId[file.id] =
            await repository.downloadUploadedFileBytes(
          tripId: widget.tripId,
          uploadedFileId: file.id,
        );
      } catch (_) {
        // 미리보기 실패는 무시.
      }
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _loadDetail());
    await AppScope.of(context).refreshTrips();
  }

  Future<void> _pickAndUpload(TripDetail detail) async {
    final repository = AppScope.of(context).repository;
    final count = detail.uploadedFiles
        .where((f) => f.fileCategory == FileCategory.authPhoto)
        .length;
    if (count >= _required) {
      _snack('관광지 인증사진은 최대 $_required장까지 등록할 수 있어요.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) _snack('이미지 파일을 읽지 못했어요. 다시 시도해 주세요.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final uploaded = await repository.uploadFile(
        tripId: widget.tripId,
        category: FileCategory.authPhoto,
        file: UploadBinary(
          fileName: file.name,
          bytes: file.bytes!,
          mimeType: _guessMime(file.extension),
        ),
      );
      final review = await repository.analyzeAuthPhoto(
        tripId: widget.tripId,
        uploadedFileId: uploaded.id,
      );

      // 판정 결과는 항상 화면에 표시. 승인이면 보관, 반려면 파일은 지우되 결과는 남김.
      _lastPreview = file.bytes;
      _lastReview = review;
      if (review.approved) {
        _previewBytesByFileId[uploaded.id] = file.bytes!;
      } else {
        await repository.deleteUploadedFile(
          tripId: widget.tripId,
          uploadedFileId: uploaded.id,
        );
      }
      if (!mounted) return;
      await _reload();
    } catch (error) {
      if (!mounted) return;
      _snack('인증사진 업로드에 실패했어요: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(int fileId) async {
    await AppScope.of(context)
        .repository
        .deleteUploadedFile(tripId: widget.tripId, uploadedFileId: fileId);
    _previewBytesByFileId.remove(fileId);
    await _reload();
  }

  String _guessMime(String? ext) => switch ((ext ?? '').toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('관광지 인증')),
      body: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data!;
          final authFiles = detail.uploadedFiles
              .where((f) => f.fileCategory == FileCategory.authPhoto)
              .toList();
          final count = authFiles.length;
          final review = _lastReview;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // 진행 헤더
              Row(children: [
                const Icon(Icons.photo_camera_outlined,
                    size: 20, color: AppColors.p600),
                const SizedBox(width: 8),
                const Text('지정관광지 인증',
                    style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink9)),
                const Spacer(),
                Text('$count / $_required곳',
                    style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.p600)),
              ]),
              const SizedBox(height: 16),

              // 사진 영역
              _PhotoArea(
                bytes: _lastPreview,
                uploading: _uploading,
                onTap: _uploading ? null : () => _pickAndUpload(detail),
              ),
              const SizedBox(height: 10),
              const _Note(
                  '기본 카메라로 찍은 사진을 올려주세요. 위치·시간(GPS) 정보가 있어야 자동 인증돼요. 캡처·SNS 저장 사진은 정보가 지워질 수 있어요.'),

              // 자동 판정
              if (review != null) ...[
                const SizedBox(height: 16),
                _ReviewBanner(review: review),
                const SizedBox(height: 10),
                _ReviewList(review: review),
              ],

              // 등록 현황
              if (count > 0) ...[
                const SizedBox(height: 18),
                const Text('등록된 인증샷',
                    style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink9)),
                const SizedBox(height: 12),
                for (var i = 0; i < authFiles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _UploadedRow(
                      index: i + 1,
                      bytes: _previewBytesByFileId[authFiles[i].id],
                      onDelete: () => _deletePhoto(authFiles[i].id),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<TripDetail>(
        future: _future,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          final full = detail != null &&
              detail.uploadedFiles
                      .where((f) => f.fileCategory == FileCategory.authPhoto)
                      .length >=
                  _required;
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            child: FilledButton.icon(
              onPressed: (_uploading || detail == null || full)
                  ? null
                  : () => _pickAndUpload(detail),
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: Text(full
                  ? '인증 완료 ($_required/$_required)'
                  : (_lastReview != null ? '다시 촬영하기' : '기본 카메라 사진 올리기')),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoArea extends StatelessWidget {
  const _PhotoArea(
      {required this.bytes, required this.uploading, required this.onTap});
  final Uint8List? bytes;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surf,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: uploading
              ? const Center(child: CircularProgressIndicator())
              : bytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Image.memory(bytes!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 36, color: AppColors.ink4),
                        SizedBox(height: 10),
                        Text('기본 카메라 사진 올리기',
                            style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink5)),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded,
            size: 17, color: AppColors.warning),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A6800))),
        ),
      ]),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.review});
  final AuthPhotoReviewResult review;

  @override
  Widget build(BuildContext context) {
    final ok = review.approved;
    final bg = ok ? const Color(0xFFE7F7EE) : AppColors.coralTint;
    final fg = ok ? const Color(0xFF1B8E4B) : AppColors.coralDeep;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: fg, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ok ? '인증 완료됐어요' : '얼굴·배경 확인이 필요해요',
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: fg)),
            const SizedBox(height: 2),
            Text(
                ok
                    ? '위치·시각·인원이 모두 확인됐어요'
                    : (review.reason.isNotEmpty
                        ? review.reason
                        : '사람과 배경이 잘 보이게 다시 찍어주세요'),
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    height: 1.4,
                    color: fg.withValues(alpha: 0.85))),
          ]),
        ),
      ]),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.review});
  final AuthPhotoReviewResult review;

  @override
  Widget build(BuildContext context) {
    final faceBg = review.facesClear && review.backgroundVisible;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(children: [
        // 위치·촬영시각: EXIF 실검증 결과 (null = GPS/좌표·시각 정보 없음 → 판정 불가)
        _row(
            Icons.place_outlined,
            '위치 · 지정관광지 반경 내',
            review.locationVerified == true
                ? '일치'
                : review.locationVerified == false
                    ? '반경 밖'
                    : (review.gpsPresent ? '확인 불가' : 'GPS 정보 없음'),
            review.locationVerified == true),
        _row(
            Icons.schedule_outlined,
            '촬영 시각 · 여행 기간 내',
            review.withinTripPeriod == true
                ? '확인'
                : review.withinTripPeriod == false
                    ? '기간 밖'
                    : '시각 정보 없음',
            review.withinTripPeriod == true),
        _row(
            Icons.people_outline_rounded,
            '인원',
            '${review.detectedPeopleCount}명 확인',
            review.detectedPeopleCount >= review.requiredPeopleCount),
        _row(Icons.face_outlined, '얼굴 · 배경',
            faceBg ? '확인' : '확인 안됨', faceBg, last: true),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value, bool ok,
      {bool last = false}) {
    final tint = ok ? const Color(0xFF1B8E4B) : AppColors.coralDeep;
    final tintBg = ok ? const Color(0xFFE7F7EE) : AppColors.coralTint;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: last ? 10 : 10),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: tintBg, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: tint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink7)),
        ),
        Text(value,
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ok ? AppColors.ink7 : AppColors.coralDeep)),
      ]),
    );
  }
}

class _UploadedRow extends StatelessWidget {
  const _UploadedRow(
      {required this.index, required this.bytes, required this.onDelete});
  final int index;
  final Uint8List? bytes;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 52,
            height: 52,
            child: bytes != null
                ? Image.memory(bytes!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.track,
                    child: const Icon(Icons.image_outlined,
                        color: AppColors.ink4)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('관광지 인증 $index',
                style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink9)),
            const SizedBox(height: 2),
            const Text('인증 완료',
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B8E4B))),
          ]),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.ink4, size: 20),
        ),
      ]),
    );
  }
}
