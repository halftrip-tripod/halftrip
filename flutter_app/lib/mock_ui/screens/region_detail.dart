import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'community.dart';
import 'place_detail.dart';

/// S1-2 지역 상세 (신청 판단 허브).
class RegionDetailScreen extends StatefulWidget {
  const RegionDetailScreen({super.key, required this.region});
  final Region region;

  @override
  State<RegionDetailScreen> createState() => _RegionDetailScreenState();
}

class _RegionDetailScreenState extends State<RegionDetailScreen> {
  final _openAcc = {0};

  static const _places = [
    ('🏯', '다산초당', '역사·문화'),
    ('🌉', '가우도 출렁다리', '자연·체험'),
    ('🏺', '고려청자박물관', '문화'),
    ('🌾', '강진만 생태공원', '자연'),
  ];

  static const _accordions = [
    (Icons.photo_camera_outlined, '관광지 인증', [
      '강진 관광지 2개소 이상 방문 사진이 필요합니다.',
      '반드시 신청대표자와 신청구성원 얼굴이 모두 나와야 합니다.',
    ]),
    (Icons.credit_card_rounded, '경비 · 결제', [
      '개인 3만원 이상, 팀(2인 이상) 5만원 이상 지출 영수증이 필요합니다.',
      '신청대표자 명의 카드영수증을 인정합니다.',
      '대표자 번호가 기재된 현금영수증·CHAK 거래내역을 인정합니다.',
      '연 30억원 이상 매출 업소 결제 비용은 지원 제외입니다.',
    ]),
    (Icons.bed_outlined, '숙박', [
      '선결제한 경우 숙소 이용 완료 내역서와 결제 영수증을 함께 제출해야 합니다.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final r = widget.region;
    final soon = r.status == RegionStatus.soon;
    return DetailScaffold(
      title: r.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          onPressed: () => showMock(context, '공유 링크를 복사했어요. (목업)'),
        ),
      ],
      // 오픈예정: 관심 등록 = 오픈 알림이므로 별표 없이 알림 CTA 하나만.
      // 접수중: 별표(관심·마감 알림 대상) + 신청 CTA.
      cta: CtaBar(children: [
        if (soon)
          ValueListenableBuilder(
            valueListenable: r.favorite,
            builder: (_, fav, _) => PrimaryButton(
              fav ? '오픈 알림 신청됨 ✓' : '오픈 알림 받기',
              icon: fav ? null : Icons.notifications_none_rounded,
              onTap: () {
                AppState.I.toggleFavorite(r);
                showMock(
                    context,
                    fav
                        ? '${r.name} 오픈 알림을 해제했어요.'
                        : '${r.name}을(를) 관심 지역에 담고 오픈 알림을 신청했어요!');
              },
            ),
          )
        else ...[
          ValueListenableBuilder(
            valueListenable: r.favorite,
            builder: (_, fav, _) => GhostButton(
              icon: fav ? Icons.star_rounded : Icons.star_outline_rounded,
              active: fav,
              onTap: () => AppState.I.toggleFavorite(r),
            ),
          ),
          PrimaryButton('신청하러 가기',
              onTap: () => showMock(context, '지자체 신청 페이지로 이동해요. (외부 링크 · 목업)')),
        ],
      ]),
      children: [
        // HERO
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              EmojiBox(r.emoji, size: 64, fontSize: 34, radius: 20),
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
              Pill(soon ? '오픈예정' : '접수중', tone: soon ? PillTone.gray : PillTone.sky),
              if (r.mintBenefit) ...[const SizedBox(width: 8), const Pill('디민증 중복혜택', tone: PillTone.mint)],
              const Spacer(),
              DdayChip(soon ? '오픈 D-${r.dday}' : '마감 D-${r.dday}', warn: r.ddayWarn),
            ]),
          ]),
        ),
        // 오픈 전 안내 (조건은 지자체 공고 기준으로 미리 공개)
        if (soon)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(16)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.campaign_outlined, size: 20, color: AppColors.p600),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${r.openLabel} · 선착순 접수\n',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.p700)),
                    const TextSpan(
                        text: '아래 조건은 지자체 사업 공고 기준이에요. 미리 확인하고 오픈되면 바로 신청하세요.'),
                  ]),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.5),
                ),
              ),
            ]),
          ),
        // 신청 일정
        _DCard(title: '신청 일정', children: [
          if (soon)
            _CRow(icon: Icons.calendar_today_outlined, label: '접수 시작', rich: [
              TextSpan(
                  text: r.openLabel ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
              TextSpan(text: ' 10:00 · D-${r.dday}'),
            ])
          else
            const _CRow(icon: Icons.calendar_today_outlined, label: '접수 기간', rich: [
              TextSpan(text: '6.02 ~ 6.18', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
              TextSpan(text: ' · 마감 D-5'),
            ]),
          _CRow(icon: Icons.calendar_month_outlined, label: '여행 기간', rich: [
            TextSpan(
                text: soon ? '6.16 ~ 7.13' : '6.02 ~ 6.30',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
            const TextSpan(text: ' 중 1박2일'),
          ]),
          const _CRow(icon: Icons.schedule_rounded, label: '정산 신청', rich: [
            TextSpan(text: '여행 종료 다음날부터 '),
            TextSpan(text: '7일 이내', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink9)),
          ]),
        ]),
        // 환급 조건 요약
        _DCard(title: '환급 조건 요약', children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(15)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('50%', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.p600, letterSpacing: -1.2, height: 1)),
              SizedBox(width: 9),
              Text('여행경비 환급 · 1인 최대 25만원',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink7)),
            ]),
          ),
          const _Kv('결제 수단', '강진사랑상품권 Chak\n카드 · 현금영수증'),
          const _Kv('인증 조건', '영수증 + 여행 인증 사진'),
          const _Kv('최소 소비', '개인 3만원 / 팀 5만원 이상'),
          const _Kv('지정관광지', '2곳 이상 방문 인증 · 1박 숙박 필수'),
        ]),
        // 인정 관광지
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
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('정산 신청 기한',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.p600)),
                SizedBox(height: 2),
                Text('여행 종료 다음날부터 7일 이내',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              ]),
            ]),
          ),
          // 아코디언들을 한 그룹으로 묶어 _DCard 간격이 한 번만 적용되게 →
          // 항목 사이 구분선 위/아래 여백이 14로 대칭이 된다.
          Column(children: [
            for (var i = 0; i < _accordions.length; i++) _accordion(i),
          ]),
        ]),
        // 디민증
        _DCard(title: '디지털 관광주민증 혜택', children: [
          const Text('반값여행 + 디민증 중복 혜택 가능',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.mintDeep)),
          Text('${r.name} 관광주민증 제시 시 일부 가맹점에서 추가 할인 혜택을 받을 수 있어요.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.45)),
          OutlineButton('관광주민증 발급받으러 가기',
              icon: Icons.badge_outlined,
              trailingIcon: Icons.open_in_new_rounded,
              onTap: () => showMock(context, '디민증 발급 페이지로 이동해요. (외부 링크 · 목업)')),
        ]),
        // 지역화폐
        _DCard(title: '지역화폐 앱 안내', children: [
          const Text('강진사랑상품권 · Chak',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink9)),
          const Text('강진사랑상품권 Chak 거래내역을 정산 증빙으로 활용할 수 있어요.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.45)),
          OutlineButton('앱 바로가기',
              icon: Icons.account_balance_wallet_outlined,
              trailingIcon: Icons.open_in_new_rounded,
              onTap: () => showMock(context, 'Chak 앱으로 이동해요. (외부 링크 · 목업)')),
        ]),
        // 후기 — 지난 차수·작년 운영 지역이면 오픈 전이어도 후기가 있을 수 있다.
        // 커뮤니티 글 데이터 기반: 이 지역 글이 하나도 없으면 섹션 자체를 뺀다.
        if (regionPosts.isNotEmpty)
          _DCard(
            titleWidget: Row(children: [
              Text('${r.name} 여행 후기',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
              const SizedBox(width: 7),
              Pill('${regionPosts.length}'),
            ]),
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
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CommunityFeedScreen(region: r.name)))),
            ],
          ),
      ],
    );
  }

  List<Post> get regionPosts => AppState.I.posts
      .where((p) => !p.private && p.region == widget.region.name)
      .toList();

  Widget _accordion(int i) {
    final (icon, title, bullets) = _accordions[i];
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
              child: Icon(icon, size: 18, color: AppColors.p600),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(title,
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
            for (final b in bullets)
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

/// 지역상세 카드 (제목 + 컨텐츠 리스트).
class _DCard extends StatelessWidget {
  const _DCard({this.title, this.titleWidget, required this.children});
  final String? title;
  final Widget? titleWidget;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        titleWidget ??
            Text(title!,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
        for (final c in children) ...[const SizedBox(height: 13), c],
      ]),
    );
  }
}

class _CRow extends StatelessWidget {
  const _CRow({required this.icon, required this.label, required this.rich});
  final IconData icon;
  final String label;
  final List<TextSpan> rich;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 14, color: AppColors.p600),
      ),
      const SizedBox(width: 11),
      SizedBox(
        width: 62,
        child: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text.rich(
          TextSpan(children: rich),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink7, height: 1.45),
        ),
      ),
    ]);
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
          child: Text(k,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        ),
        Expanded(
          child: Text(v,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9, height: 1.4)),
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
