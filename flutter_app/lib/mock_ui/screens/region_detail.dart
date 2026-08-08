import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../data/region_guides.dart';
import '../../models/app_models.dart';
import '../data/models.dart' show Post;
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'community.dart';
import 'place_detail.dart';

/// S1-2 지역 상세 (신청 판단 허브) — 실 API(RegionSummary) 연동.
class RegionDetailScreen extends StatefulWidget {
  const RegionDetailScreen({super.key, required this.region});
  final RegionSummary region;

  @override
  State<RegionDetailScreen> createState() => _RegionDetailScreenState();
}

class _RegionDetailScreenState extends State<RegionDetailScreen> {
  final _openAcc = {0};

  // 환급 인정 관광지 — 장소 API 연동 전까지 쓰는 임시 목업 리스트.
  static const _places = [
    ('🏯', '다산초당', '역사·문화'),
    ('🌉', '가우도 출렁다리', '자연·체험'),
    ('🏺', '고려청자박물관', '문화'),
    ('🌾', '강진만 생태공원', '자연'),
  ];

  bool get _isPreparing => widget.region.statusCode.toUpperCase() == 'PREPARING';

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) {
      showMock(context, '연결된 링크가 없어요.');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final r = widget.region;
    final guide = settlementGuideFor(r.name);
    final guideText = guide.sections.expand((s) => s.bullets).join(' ');
    final isFavorite =
        controller.currentUser?.favoriteRegions.any((f) => f.id == r.id) ?? false;
    final dday = regionDday(r);

    return DetailScaffold(
      title: r.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          onPressed: () => showMock(context, '공유 링크를 복사했어요. (목업)'),
        ),
      ],
      // 오픈예정: 관심 등록 = 오픈 알림이므로 별표 없이 알림 CTA 하나만.
      // 접수중: 별표(즐겨찾기) + 신청 CTA(실제 지자체 신청 링크로 이동).
      cta: CtaBar(children: [
        if (_isPreparing)
          PrimaryButton(
            controller.preopenAlertRegionIds.contains(r.id) ? '오픈 알림 신청됨 ✓' : '오픈 알림 받기',
            icon: controller.preopenAlertRegionIds.contains(r.id) ? null : Icons.notifications_none_rounded,
            onTap: () async {
              final wasEnabled = controller.preopenAlertRegionIds.contains(r.id);
              await controller.togglePreopenAlertRegion(r.id);
              if (!context.mounted) return;
              showMock(context,
                  wasEnabled ? '${r.name} 오픈 알림을 해제했어요.' : '${r.name}을(를) 관심 지역에 담고 오픈 알림을 신청했어요!');
            },
          )
        else ...[
          GhostButton(
            icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            active: isFavorite,
            onTap: () => controller.toggleFavoriteRegion(r),
          ),
          PrimaryButton('신청하러 가기', onTap: () => _openUrl(r.halfPriceApplyUrl)),
        ],
      ]),
      children: [
        // HERO
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              EmojiBox(_regionEmoji(r.name), size: 64, fontSize: 34, radius: 20),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
                const SizedBox(height: 3),
                Text(r.province,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink4)),
              ]),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Pill(r.statusLabel, tone: _isPreparing ? PillTone.gray : PillTone.sky),
              if (r.digitalBenefitAvailable) ...[const SizedBox(width: 8), const Pill('디민증 중복혜택', tone: PillTone.mint)],
              const Spacer(),
              DdayChip(
                dday == null
                    ? (_isPreparing ? '오픈일 확인 필요' : '마감일 확인 필요')
                    : (_isPreparing ? '오픈 D-${dday.$1}' : '마감 D-${dday.$1}'),
                warn: !_isPreparing && (dday?.$2 ?? false),
              ),
            ]),
          ]),
        ),
        // 오픈 전 안내 (조건은 지자체 공고 기준으로 미리 공개)
        if (_isPreparing)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(16)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.campaign_outlined, size: 20, color: AppColors.p600),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '아직 접수 전이에요. 아래 조건은 지자체 사업 공고 기준 — 미리 확인하고 오픈되면 바로 신청하세요.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.5),
                ),
              ),
            ]),
          ),
        // 환급 조건 요약
        _DCard(title: '환급 조건 요약', children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(15)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${r.refundRate ?? 50}%', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.p600, letterSpacing: -1.2, height: 1)),
              const SizedBox(width: 9),
              const Text('여행경비 환급',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink7)),
            ]),
          ),
          _Kv(
            '결제 수단',
            r.paymentMethods.isNotEmpty
                ? r.paymentMethods
                    .map((code) => PaymentTypeWire.fromWire(code).label)
                    .join(' · ')
                : _paymentSummary(guideText),
          ),
          _Kv('인증 조건', _proofSummary(guideText)),
          _Kv('최소 소비', _minSpendSummary(guideText)),
          _Kv(
            '1인 최대 환급',
            r.maxRefundPerPerson != null
                ? '${_formatWon(r.maxRefundPerPerson!)}원'
                : '${_formatWon(r.refundConditionAmount)}원',
          ),
        ]),
        // 인정 관광지 — 장소 API 연동 전까지 목업.
        _DCard(title: '환급 인정 관광지', children: [
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlaceDetailScreen(
                        emoji: _places[i].$1, name: _places[i].$2, category: _places[i].$3))),
                child: SizedBox(
                  width: 128,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 128,
                      height: 90,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(16)),
                      child: Text(_places[i].$1, style: const TextStyle(fontSize: 38)),
                    ),
                    const SizedBox(height: 8),
                    Text(_places[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink9)),
                    const SizedBox(height: 2),
                    Text(_places[i].$3,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
        // 상세 정산 규칙
        _DCard(title: '상세 정산 규칙', children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.soft),
                child: const Icon(Icons.schedule_rounded, size: 19, color: AppColors.p600),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('정산 신청 기한',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.p600)),
                  const SizedBox(height: 2),
                  Text(
                    r.settlementDeadlineDays != null
                        ? '여행 종료 후 ${r.settlementDeadlineDays}일 이내'
                        : guide.deadline,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9),
                  ),
                ]),
              ),
            ]),
          ),
          Column(children: [
            for (var i = 0; i < guide.sections.length; i++) _accordion(i, guide.sections[i]),
          ]),
          if (guide.note != null && guide.note!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFF6E9), borderRadius: BorderRadius.circular(15)),
              child: Text(guide.note!,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF9A6800), height: 1.55)),
            ),
        ]),
        // 디민증
        if (r.digitalBenefitAvailable)
          _DCard(title: '디지털 관광주민증 혜택', children: [
            const Text('반값여행 + 디민증 중복 혜택 가능',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.mintDeep)),
            Text('${r.name} 관광주민증 제시 시 일부 가맹점에서 추가 할인 혜택을 받을 수 있어요.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.45)),
            OutlineButton('관광주민증 발급받으러 가기',
                icon: Icons.badge_outlined,
                trailingIcon: Icons.open_in_new_rounded,
                onTap: () => _openUrl(r.digitalTourCardApplyUrl)),
          ]),
        // 지역화폐
        _DCard(title: '지역화폐 앱 안내', children: [
          Text(_localCurrencyAppName(r.name),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9)),
          Text(_localCurrencyDescription(r.name),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.45)),
          if (r.localCurrencyAppUrl != null && r.localCurrencyAppUrl!.trim().isNotEmpty)
            OutlineButton('지역화폐 앱 열기',
                icon: Icons.smartphone_rounded,
                trailingIcon: Icons.open_in_new_rounded,
                onTap: () => _openUrl(r.localCurrencyAppUrl!)),
        ]),
        // 후기 — 커뮤니티 API 연동 전까지 목업 게시글 데이터 기반.
        if (regionPosts.isNotEmpty)
          _DCard(
            title: '${r.name} 여행 후기',
            children: [
              const Text('다녀온 사람들의 생생한 후기로 코스를 그려보세요.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5)),
              for (var i = 0; i < regionPosts.length && i < 2; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ReviewRow(post: regionPosts[i]),
              ],
              OutlineButton('${r.name} 후기 전체보기',
                  icon: Icons.chat_bubble_outline_rounded,
                  trailingIcon: Icons.chevron_right_rounded,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => CommunityFeedScreen(region: r.name)))),
            ],
          ),
      ],
    );
  }

  List<Post> get regionPosts =>
      AppState.I.posts.where((p) => !p.private && p.region == widget.region.name).toList();

  Widget _accordion(int i, RegionRuleSection section) {
    final open = _openAcc.contains(i);
    return Column(children: [
      if (i > 0) const Divider(height: 1),
      InkWell(
        onTap: () => setState(() => open ? _openAcc.remove(i) : _openAcc.add(i)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(11)),
              child: Icon(_sectionIcon(section.title), size: 18, color: AppColors.p600),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(section.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
            ),
            AnimatedRotation(
              turns: open ? .25 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
            ),
          ]),
        ),
      ),
      if (open)
        Padding(
          padding: const EdgeInsets.only(left: 45, bottom: 14, right: 2),
          child: Column(children: [
            for (final b in section.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(color: AppColors.p400, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(b,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
                  ),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

IconData _sectionIcon(String title) {
  if (title.contains('인증') || title.contains('사진')) return Icons.photo_camera_outlined;
  if (title.contains('결제') || title.contains('경비') || title.contains('소비')) return Icons.credit_card_rounded;
  if (title.contains('숙박')) return Icons.bed_outlined;
  return Icons.description_outlined;
}

/// 지역상세 카드 (제목 + 컨텐츠 리스트).
class _DCard extends StatelessWidget {
  const _DCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
        for (final c in children) ...[const SizedBox(height: 13), c],
      ]),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 88,
          child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9, height: 1.4)),
        ),
      ]),
    );
  }
}


class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(post: post))),
      behavior: HitTestBehavior.opaque,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: post.avatarBg,
          child: Text(post.avatarEmoji, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(post.nick,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              ),
              const SizedBox(width: 6),
              Text('· ${post.timeAgo}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink4)),
            ]),
            const SizedBox(height: 4),
            Text(post.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.45)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.favorite_rounded, size: 13, color: AppColors.coralDeep),
              const SizedBox(width: 4),
              Text('${post.likes}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink5)),
            ]),
          ]),
        ),
        if (post.photos.isNotEmpty) ...[
          const SizedBox(width: 10),
          EmojiBox(post.photos.first, size: 54, fontSize: 25, color: AppColors.surf, radius: 13),
        ],
      ]),
    );
  }
}

String _formatWon(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final indexFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (indexFromEnd > 1 && indexFromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _paymentSummary(String guideText) {
  if (guideText.contains('카드') && guideText.contains('간편결제')) return '지역화폐, 카드, 간편결제';
  if (guideText.contains('제로페이')) return '지역화폐, 제로페이, 카드';
  if (guideText.contains('현금영수증')) return '카드, 현금영수증, 지역화폐';
  return '지역화폐, 카드 결제';
}

String _proofSummary(String guideText) {
  if (guideText.contains('인증샷') || guideText.contains('사진')) return '영수증 + 여행 인증 사진';
  return '영수증 제출';
}

String _minSpendSummary(String guideText) {
  if (guideText.contains('개인 신청자 3만 원')) return '개인 30,000원 / 팀 50,000원 이상';
  if (guideText.contains('개인 신청자 5만원')) return '개인 50,000원 / 팀 100,000원 이상';
  if (guideText.contains('개인당 5만원')) return '개인 50,000원 / 팀 100,000원 이상';
  if (guideText.contains('최소 소비액(여행경비) 5만원')) return '50,000원 이상';
  return '지역 공고 기준 확인';
}

String _localCurrencyAppName(String regionName) => switch (regionName) {
      '평창' => '평창사랑상품권',
      '횡성' => '횡성몰 / 홈페이지',
      '영월' => '영월별빛고운카드',
      '제천' => '제천화폐 Chak',
      '거창' => '거창반값여행 상품권',
      '고창' => '고창사랑카드',
      '합천' => '합천반값여행 상품권',
      '영광' => '그리고',
      '밀양' => '밀양사랑상품권',
      '영암' => '월출페이',
      '하동' => '하동반값여행 상품권',
      '강진' => '강진사랑상품권 Chak',
      '남해' => '남해사랑상품권',
      '해남' => '해남사랑상품권',
      '고흥' => '고흥사랑상품권',
      '완도' => '완도사랑상품권',
      _ => '지역화폐 앱',
    };

String _localCurrencyDescription(String regionName) => switch (regionName) {
      '평창' => '평창사랑상품권 가맹점에서 사용할 수 있어요.',
      '횡성' => '횡성 지역 공지에 따라 사용 앱이 공개될 예정입니다.',
      '영월' => '영월 지역화폐 결제 내역과 카드 정보를 함께 확인해요.',
      '제천' => '제천화폐 사용 내역은 Chak 시스템 기준으로 정산됩니다.',
      '거창' => '거창 반값여행 상품권 사용 내역을 앱에서 확인해요.',
      '고창' => '고창사랑카드 결제 내역을 정산 전에 확인해 주세요.',
      '합천' => '모바일 합천반값여행 상품권 사용 내역이 필요해요.',
      '영광' => '그리고 앱 또는 카드 거래내역을 준비해 주세요.',
      '밀양' => '밀양사랑상품권 제로페이 사용 내역이 필요해요.',
      '영암' => '월출페이 이용내역 상세 화면으로 정산에 활용해요.',
      '하동' => '하동반값여행 상품권 제로페이 전자영수증이 필요해요.',
      '강진' => '강진사랑상품권 Chak 거래내역을 확인할 수 있어요.',
      _ => '지역화폐 거래내역을 정산 증빙으로 활용할 수 있어요.',
    };

String _regionEmoji(String regionName) {
  const map = <String, String>{
    '평창': '🏔️',
    '횡성': '🥩',
    '영월': '🌊',
    '제천': '⛰️',
    '거창': '🌿',
    '고창': '🏛️',
    '합천': '🌄',
    '영광': '🐟',
    '밀양': '🏞️',
    '영암': '🏎️',
    '하동': '🍃',
    '강진': '🍲',
    '남해': '🌴',
    '해남': '🌾',
    '고흥': '🚀',
    '완도': '🏝️',
  };
  return map[regionName] ?? '📍';
}
