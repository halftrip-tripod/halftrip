import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'community.dart';
import 'course_flow.dart';
import 'record_screens.dart';

/// S2-3 여행 상세 (컨트롤 센터) — 단계별 뷰.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  static const _checklist = [
    '강진사랑상품권(Chak) 앱 설치',
    '결제수단(인정 카드) 확인',
    '인증사진 가이드 확인',
    '숙소 예약 확인',
  ];

  Trip get trip => widget.trip;

  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) => DetailScaffold(
        title: trip.name,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: switch (trip.stage) {
          TripStage.before => _before(),
          TripStage.during => _during(),
          TripStage.settle => _settle(),
          _ => _review(),
        },
      ),
    );
  }

  // ===== 여행 전 =====
  List<Widget> _before() {
    final s = AppState.I;
    final course = trip.course;
    return [
      _TripHeader(trip: trip, pill: '여행 전', tone: PillTone.sky),
      const _StageBar(current: 0),
      _DCard(title: '여행 코스', children: [
        if (course != null)
          SurfRow(
            icon: Icons.route_outlined,
            title: course.title,
            subtitle:
                '${course.durationLabel} · ${course.placeCount}곳${course.refundOk ? ' · 환급 조건 충족' : ''}',
            tinted: true,
            onTap: () => _push(CourseViewScreen(course: course)),
          )
        else ...[
          OutlineButton('코스 추가하기',
              icon: Icons.add_rounded,
              onTap: () => _push(CourseCreateScreen(forTrip: trip))),
          OutlineButton('${trip.region} 인기 코스 보러 가기',
              icon: Icons.chat_bubble_outline_rounded,
              trailingIcon: Icons.chevron_right_rounded,
              onTap: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                AppState.I.communityRegion.value = trip.region;
                AppState.I.tabRequest.value = 3; // 커뮤니티 탭
              }),
        ],
      ]),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('출발 준비 체크리스트',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const Spacer(),
            Text('${s.checklistDone.length}/4',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
          ]),
          const SizedBox(height: 10),
          for (var i = 0; i < _checklist.length; i++)
            InkWell(
              onTap: () => s.toggleChecklist(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: s.checklistDone.contains(i) ? AppColors.p500 : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: s.checklistDone.contains(i)
                          ? null
                          : Border.all(color: AppColors.line, width: 2),
                    ),
                    child: s.checklistDone.contains(i)
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(_checklist[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: s.checklistDone.contains(i) ? AppColors.ink5 : AppColors.ink9,
                          decoration:
                              s.checklistDone.contains(i) ? TextDecoration.lineThrough : null,
                        )),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      _DCard(title: '여행 중 · 후 할 일', sub: '출발하면 순서대로 열려요. 눌러서 준비 방법을 미리 확인해두세요.', children: [
        for (var i = 0; i < _taskGuides.length; i++)
          _UpRow(
            icon: _taskGuides[i].$1,
            label: _taskGuides[i].$2,
            when: _taskGuides[i].$3,
            onTap: () => _showTaskGuide(i),
          ),
      ]),
    ];
  }

  /// 여행 전: 할 일 준비 가이드 (등록은 여행이 시작되면 열림).
  static const _taskGuides = [
    (Icons.photo_camera_outlined, '관광지 인증샷 (EXIF)', '여행 중', [
      '지정관광지 2곳 이상에서 인증샷을 찍어야 해요.',
      '기본 카메라로 촬영해 위치·시간(GPS·EXIF) 정보가 남아야 자동 인증돼요.',
      '신청 대표자와 일행 얼굴, 배경이 함께 나오게 찍어주세요.',
      '캡처·SNS 저장본은 촬영 정보가 지워져 인증이 어려워요.',
    ]),
    (Icons.credit_card_rounded, '영수증 OCR · 소비 추적', '여행 중', [
      '인정 결제수단: 지역화폐(Chak) · 신청 대표자 명의 카드 · 현금영수증.',
      '최소 소비 조건: 개인 3만원 / 팀(2인 이상) 5만원 이상.',
      '영수증 사진을 올리면 상호·금액·결제수단을 자동으로 인식해 누적 소비로 관리해줘요.',
      '간이영수증·계좌이체는 인정되지 않을 수 있어요.',
    ]),
    (Icons.bed_outlined, '숙박확인서 작성·서명', '여행 중', [
      '반값여행은 1박 숙박이 필수예요.',
      '숙소명·대표자·일정·금액을 적고 체크아웃 때 숙소 대표자 서명을 받아요.',
      '선결제한 경우 숙소 이용 완료 내역서와 결제 영수증을 함께 준비하세요.',
    ]),
    (Icons.description_outlined, '증빙 패키지 · 정산 신청', '여행 후', [
      '여행이 끝나면 인증샷 + 영수증 + 숙박확인서를 제출 규격 PDF로 자동으로 묶어드려요.',
      '정산 신청은 여행 종료 다음날부터 7일 이내, 지자체 정산 페이지에서 해요.',
      '제출 후 심사를 거쳐 보통 1~2개월 뒤 지역화폐로 환급돼요.',
    ]),
  ];

  void _showTaskGuide(int i) {
    final (icon, title, timing, bullets) = _taskGuides[i];
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 22, color: AppColors.p600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
            ),
            Pill(timing, tone: timing == '여행 중' ? PillTone.sky : PillTone.gray),
          ]),
          const SizedBox(height: 18),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(color: AppColors.p400, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(b,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
                ),
              ]),
            ),
          const SizedBox(height: 6),
          const NoteRow('여행이 시작되면 이 화면에서 바로 등록할 수 있어요.'),
          const SizedBox(height: 18),
          Row(children: [
            PrimaryButton('확인했어요', onTap: () => Navigator.of(context).pop()),
          ]),
        ]),
      ),
    );
  }

  // ===== 여행 중 =====
  List<Widget> _during() {
    final s = AppState.I;
    final course = trip.course;
    return [
      _TripHeader(trip: trip, pill: '여행 중', tone: PillTone.live),
      const _StageBar(current: 1),
      _DCard(title: '관광지 인증', children: [
        ProgressGauge(label: '관광지 인증샷', value: '${s.authPhotoDone} / 2곳',
            progress: s.authPhotoDone / 2, green: true),
        _NextLink('인증샷 추가하기', onTap: () => _push(const AuthPhotoScreen())),
      ]),
      _DCard(title: '소비 기록', children: [
        ProgressGauge(label: '누적 소비 (조건 20만원)', value: '${s.spentAmount ~/ 10000}만 / 20만원',
            progress: (s.spentAmount / 200000).clamp(0, 1)),
        _NextLink('영수증 추가하기', onTap: () => _push(const ReceiptOcrScreen())),
      ]),
      _DCard(title: '숙박확인서', sub: '체크아웃 때 사장님 서명을 받아 작성하면 정산이 편해져요.', children: [
        _NextLink(s.lodgingSaved ? '숙박확인서 확인하기' : '숙박확인서 작성하기',
            onTap: () => _push(const LodgingFormScreen())),
      ]),
      _DCard(
        titleWidget: Row(children: [
          const Text('오늘 동선',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
          const Spacer(),
          if (course != null)
            GestureDetector(
              onTap: () => _push(CourseViewScreen(course: course)),
              child: const Text('코스 전체 보기 ›',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.p600)),
            ),
        ]),
        children: [
          const CourseMapCard(),
          if (course != null)
            SurfRow(
              icon: Icons.route_outlined,
              title: course.title,
              subtitle: '${course.durationLabel} · ${course.placeCount}곳',
              tinted: true,
              onTap: () => _push(CourseViewScreen(course: course)),
            ),
        ],
      ),
    ];
  }

  // ===== 정산 =====
  List<Widget> _settle() {
    return [
      _TripHeader(trip: trip, pill: '정산 신청', tone: PillTone.warn),
      const _StageBar(current: 2),
      _DCard(title: '증빙 자료 준비 완료', children: const [
        _CheckLine('관광지 인증샷 2/2 · EXIF 검증 완료'),
        _CheckLine('영수증 OCR · 소비 21만원 (조건 충족)'),
        _CheckLine('숙박확인서 서명 완료'),
      ]),
      _DCard(title: '증빙 패키지', sub: '인증샷 + 영수증 + 숙박확인서를 제출 규격 PDF로 자동 병합해요.', children: [
        _NextLink('증빙 패키지 만들기', onTap: () => _push(EvidencePackageScreen(trip: trip))),
      ]),
      _DCard(title: '정산 신청', sub: '증빙 패키지를 지자체 정산 페이지에 제출하세요. (마감 D-5)', children: [
        _NextLink('정산 신청하러 가기', onTap: () async {
          showMock(context, '지자체 정산 페이지로 이동해요. (외부 링크 · 목업)');
          await Future.delayed(const Duration(milliseconds: 900));
          if (!mounted) return;
          showSettleConfirmSheet(context, trip);
        }),
        Center(
          child: GestureDetector(
            onTap: () => showSettleConfirmSheet(context, trip),
            child: const Text.rich(
              TextSpan(children: [
                TextSpan(text: '이미 신청했어요 · '),
                TextSpan(text: '완료로 표시', style: TextStyle(decoration: TextDecoration.underline)),
              ]),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5),
            ),
          ),
        ),
      ]),
    ];
  }

  // ===== 환급 대기 =====
  List<Widget> _review() {
    return [
      _TripHeader(trip: trip, pill: '정산 완료', tone: PillTone.gray),
      const _StageBar(current: 3),
      AppCard(
        child: Column(children: const [
          SizedBox(height: 4),
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.p50,
            child: Icon(Icons.check_rounded, size: 28, color: AppColors.p600),
          ),
          SizedBox(height: 12),
          Text('정산 신청 완료',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9)),
          SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '수고하셨어요! 환급은 '),
              TextSpan(text: '보통 1~2개월 뒤', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
              TextSpan(text: ' 지자체에서 개별 안내돼요.'),
            ]),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.5),
          ),
        ]),
      ),
      _DCard(title: '환급금, 어디서 쓸까?', sub: '환급받은 지역화폐 사용처를 미리 둘러보세요.', children: [
        SurfRow(
          icon: Icons.shopping_bag_outlined,
          title: '지역화폐 사용처 보기',
          subtitle: '${trip.region} 온라인몰 · 가맹점 지도',
          onTap: () => showMock(context, '온라인몰 탭에서 확인할 수 있어요.'),
        ),
      ]),
      _DCard(title: '이번 여행 후기 남기기', sub: '영수증 카드로 이번 여행을 커뮤니티에 공유해보세요 (금액 비공개).', children: [
        _NextLink('후기 올리기', onTap: () => _push(CommunityWriteScreen(regionName: trip.region))),
      ]),
      _DCard(title: '다음 여행', children: [
        SurfRow(
          icon: Icons.route_outlined,
          title: '다음 반값여행 찾기',
          subtitle: '접수중인 다른 지역 보기',
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ]),
    ];
  }
}

/// 정산 신청 완료 확인 시트.
void showSettleConfirmSheet(BuildContext context, Trip trip) {
  showAppSheet(
    context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('정산 신청 완료하셨나요?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: trip.region, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
            const TextSpan(text: ' 정산 페이지에 다녀오셨네요. 지자체 페이지에서 제출을 마쳤다면 완료를 눌러주세요. '),
            const TextSpan(
                text: '완료하면 환급 대기 단계', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
            const TextSpan(text: '로 넘어가요.'),
          ]),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.5),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            Text(trip.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: trip.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              const TextSpan(
                  text: '  6.14 ~ 6.15',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4)),
            ])),
          ]),
        ),
        const SizedBox(height: 22),
        Row(children: [
          SecondaryButton('아직이요', onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 10),
          PrimaryButton('네, 완료했어요', onTap: () {
            trip.stage = TripStage.review;
            trip.ddayLabel = '여행 종료';
            AppState.I.update();
            Navigator.of(context).pop();
            showMock(context, '정산 신청을 완료로 표시했어요. 환급 대기 단계로 넘어갑니다.');
          }),
        ]),
      ]),
    ),
  );
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip, required this.pill, required this.tone});
  final Trip trip;
  final String pill;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(pill, tone: tone),
          const Spacer(),
          Text(trip.ddayLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          EmojiBox(trip.emoji, size: 48, fontSize: 24, radius: 15),
          const SizedBox(width: 13),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trip.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 3),
            Text(trip.dateLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          ]),
        ]),
      ]),
    );
  }
}

/// 4단계 진행 바.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.current});
  final int current;

  static const _labels = ['여행 전', '여행 중', '정산', '환급'];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Column(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < current
                      ? AppColors.p100
                      : (i == current ? AppColors.p500 : AppColors.track),
                  shape: BoxShape.circle,
                ),
                child: i < current
                    ? const Icon(Icons.check_rounded, size: 15, color: AppColors.p600)
                    : Text('${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: i == current ? Colors.white : AppColors.ink4,
                        )),
              ),
              const SizedBox(height: 6),
              Text(_labels[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: i <= current ? AppColors.ink9 : AppColors.ink4,
                  )),
            ]),
          ),
      ]),
    );
  }
}

class _DCard extends StatelessWidget {
  const _DCard({this.title, this.titleWidget, this.sub, required this.children});
  final String? title;
  final Widget? titleWidget;
  final String? sub;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        titleWidget ??
            Text(title!,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.45)),
        ],
        for (final c in children) ...[const SizedBox(height: 13), c],
      ]),
    );
  }
}

class _NextLink extends StatelessWidget {
  const _NextLink(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.p600)),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.p600),
      ]),
    );
  }
}

class _UpRow extends StatelessWidget {
  const _UpRow({required this.icon, required this.label, required this.when, required this.onTap});
  final IconData icon;
  final String label;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: AppColors.p600),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
        ),
        Text(when,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink4)),
      ]),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: AppColors.p500, borderRadius: BorderRadius.circular(7)),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink9)),
      ),
    ]);
  }
}
