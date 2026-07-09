import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// 마이페이지 "이용 안내" 정적 콘텐츠 화면 모음
/// (공지사항 · 자주 묻는 질문 · 이용약관 · 개인정보 처리방침).
/// halftrip-app flutter_app/lib/screens/info_screens.dart 콘텐츠 이식.

// ─────────────────────────────────────────────── 공지사항

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '공지사항',
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [for (final n in _notices) _NoticeCard(n)],
    );
  }
}

class _Notice {
  const _Notice({
    required this.tag,
    required this.title,
    required this.date,
    required this.body,
  });
  final String tag;
  final String title;
  final String date;
  final String body;
}

const _notices = [
  _Notice(
    tag: '안내',
    title: '하프트립 정식 출시 안내',
    date: '2026.06.20',
    body: '반값여행부터 인증·정산·환급까지 한 번에 관리하는 하프트립이 정식 출시됐어요. '
        '여행 지역을 골라 신청하고, 인증샷과 영수증을 기록해 지역화폐 환급까지 받아보세요.',
  ),
  _Notice(
    tag: '업데이트',
    title: '증빙 패키지 자동 묶음 기능 추가',
    date: '2026.06.24',
    body: '관광지 인증샷·영수증·숙박확인서를 정산 규격에 맞춰 하나의 패키지로 자동으로 묶어드려요. '
        '내 여행 상세에서 "증빙 패키지"를 확인해보세요.',
  ),
  _Notice(
    tag: '점검',
    title: '정기 서버 점검 안내 (매주 화 02~04시)',
    date: '2026.06.25',
    body: '안정적인 서비스를 위해 매주 화요일 새벽 2시부터 4시까지 정기 점검이 진행돼요. '
        '점검 시간에는 일부 기능 이용이 제한될 수 있어요.',
  ),
];

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.notice);
  final _Notice notice;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.p50,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(notice.tag,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.p600)),
          ),
          const Spacer(),
          Text(notice.date,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4)),
        ]),
        const SizedBox(height: 10),
        Text(notice.title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
        const SizedBox(height: 6),
        Text(notice.body,
            style: const TextStyle(fontSize: 13, height: 1.55, color: AppColors.ink5)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────── 자주 묻는 질문 (FAQ)

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '자주 묻는 질문',
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        for (var i = 0; i < _faqs.length; i++)
          _FaqTile(
            faq: _faqs[i],
            open: _openIndex == i,
            onTap: () => setState(() => _openIndex = _openIndex == i ? null : i),
          ),
      ],
    );
  }
}

class _Faq {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
}

const _faqs = [
  _Faq(
    '반값여행이 뭔가요?',
    '지자체가 운영하는 국내 관광 지원 사업이에요. 대상 지역을 여행하고 조건(최소 소비·지정 관광지 방문 등)을 채우면 '
        '여행 경비의 일부를 지역화폐로 돌려받을 수 있어요. 하프트립은 신청부터 인증·정산·환급까지 도와드려요.',
  ),
  _Faq(
    '거주지는 왜 입력하나요?',
    '반값여행은 보통 거주지와 같거나 인접한 지역은 대상에서 제외돼요. 내가 신청할 수 있는 지역만 정확히 보여드리려고 '
        '거주지를 확인해요. 거주지는 마이페이지에서 언제든 바꿀 수 있어요.',
  ),
  _Faq(
    '관광지 인증샷은 어떻게 찍나요?',
    '지정 관광지에서 촬영한 사진을 업로드하면 위치·촬영시각(EXIF)과 인원·배경을 자동으로 확인해 방문을 인증해요. '
        '캡처나 저장된 이미지가 아닌 현장에서 찍은 원본 사진을 올려주세요.',
  ),
  _Faq(
    '영수증은 어떤 게 인정되나요?',
    '여행 기간 중 대상 지역에서 결제한 영수증이 인정돼요. 사진을 올리면 결제수단·금액·일시를 자동으로 인식하고, '
        '지역화폐 환급 조건에 해당하는 소비인지 판별해드려요.',
  ),
  _Faq(
    '정산은 언제, 어떻게 신청하나요?',
    '여행이 끝나면 인증샷·영수증·숙박확인서를 증빙 패키지로 묶어 지자체 정산 페이지에 제출하면 돼요. '
        '앱의 "정산 신청" 화면에서 준비 상태를 확인하고 해당 지역 페이지로 이동할 수 있어요.',
  ),
  _Faq(
    '환급은 얼마나 걸리나요?',
    '지자체 심사를 거쳐 보통 여행 후 1~2개월 이내에 지역화폐로 지급돼요. 지급 시점과 방식은 지역마다 다르며, '
        '앱은 정산 "신청 완료"까지 도와드리고 이후 심사·지급은 지자체가 개별 안내해요.',
  ),
  _Faq(
    '받은 지역화폐는 어디서 쓰나요?',
    '해당 지역의 지역화폐 가맹점, 지역 온라인몰, 지역화폐 앱에서 사용할 수 있어요. 대형마트·유흥업소 등 일부 업종은 '
        '제한될 수 있어요.',
  ),
];

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq, required this.open, required this.onTap});
  final _Faq faq;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 헤더 — splash 없이 탭만 (펼침 자체가 피드백)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('Q',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.p600)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(faq.q,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: open ? AppColors.p600 : AppColors.ink4),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(faq.a,
                  style: const TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.ink5)),
            ),
          ),
          crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────── 약관 / 개인정보 (공용)

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({
    super.key,
    required this.title,
    required this.effectiveDate,
    required this.sections,
  });

  final String title;
  final String effectiveDate;
  final List<PolicySection> sections;

  factory PolicyScreen.terms() => const PolicyScreen(
        title: '이용약관',
        effectiveDate: '2026.06.20',
        sections: _termsSections,
      );

  factory PolicyScreen.privacy() => const PolicyScreen(
        title: '개인정보 처리방침',
        effectiveDate: '2026.06.20',
        sections: _privacySections,
      );

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: title,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('시행일: $effectiveDate',
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink4)),
        for (final s in sections)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.heading,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
            const SizedBox(height: 8),
            Text(s.body,
                style: const TextStyle(fontSize: 13.5, height: 1.7, color: AppColors.ink7)),
          ]),
      ],
    );
  }
}

class PolicySection {
  const PolicySection(this.heading, this.body);
  final String heading;
  final String body;
}

const _termsSections = [
  PolicySection('제1조 (목적)',
      '이 약관은 하프트립(이하 "회사")이 제공하는 반값여행 신청·인증·정산 및 지역화폐 환급 지원 서비스(이하 "서비스")의 이용과 관련하여 '
          '회사와 이용자의 권리·의무 및 책임사항을 규정하는 것을 목적으로 합니다.'),
  PolicySection('제2조 (정의)',
      '1. "이용자"란 이 약관에 따라 서비스를 이용하는 회원을 말합니다.\n'
          '2. "반값여행"이란 지방자치단체가 운영하는 국내 관광 경비 지원 사업을 말합니다.\n'
          '3. "환급"이란 여행 후 조건 충족 시 지자체가 지역화폐 등으로 지급하는 금액을 말합니다.'),
  PolicySection('제3조 (서비스의 내용)',
      '회사는 여행 지역 안내, 반값여행 신청 연결, 관광지 인증샷·영수증 인식, 숙박확인서 작성, 증빙 패키지 생성, 정산 신청 안내 등의 '
          '기능을 제공합니다. 실제 환급의 심사·지급은 각 지방자치단체가 수행하며, 회사는 이를 보증하지 않습니다.'),
  PolicySection('제4조 (이용계약의 성립)',
      '이용계약은 이용자가 이 약관에 동의하고 회사가 정한 절차에 따라 가입을 완료함으로써 성립합니다. 소셜 로그인 또는 자체 계정으로 '
          '가입할 수 있습니다.'),
  PolicySection('제5조 (이용자의 의무)',
      '이용자는 인증샷·영수증 등 증빙을 사실대로 제출해야 하며, 타인의 정보를 도용하거나 허위 자료를 제출해서는 안 됩니다. '
          '부정한 방법으로 환급을 받으려 한 경우 관련 법령 및 지자체 규정에 따라 불이익을 받을 수 있습니다.'),
  PolicySection('제6조 (책임의 제한)',
      '회사는 지방자치단체의 정책 변경, 예산 소진, 심사 결과 등 회사의 통제 범위를 벗어난 사유로 발생한 환급 지연·거절에 대해 '
          '책임을 지지 않습니다. 다만 회사의 고의 또는 중대한 과실로 인한 손해는 관련 법령에 따라 배상합니다.'),
  PolicySection('부칙',
      '이 약관은 시행일부터 적용됩니다. 회사는 필요 시 관련 법령을 위반하지 않는 범위에서 약관을 개정할 수 있으며, '
          '개정 시 적용일 및 사유를 명시하여 사전 공지합니다.\n\n※ 본 약관은 서비스 준비 단계의 초안이며, 정식 출시 전 법무 검토를 거쳐 확정됩니다.'),
];

const _privacySections = [
  PolicySection('1. 수집하는 개인정보 항목',
      '- 필수: 이름, 거주지(시/군/구), 휴대전화번호, 계정 식별자(소셜 로그인 ID 등)\n'
          '- 서비스 이용 과정: 관광지 인증샷 및 사진의 위치·촬영시각 정보, 영수증 이미지 및 결제 정보, 숙박확인서 정보\n'
          '- 자동 수집: 기기 정보, 푸시 알림 토큰, 서비스 이용 기록'),
  PolicySection('2. 개인정보의 이용 목적',
      '수집한 정보는 반값여행 신청 자격 확인, 관광지 방문 및 소비 인증, 증빙 패키지 생성, 정산·환급 지원, 알림 발송, '
          '서비스 개선 및 문의 응대를 위해 이용됩니다. 목적이 달성되면 지체 없이 파기합니다.'),
  PolicySection('3. 보유 및 이용 기간',
      '원칙적으로 회원 탈퇴 시 즉시 파기합니다. 다만 관계 법령에 따라 보존이 필요한 경우 해당 기간 동안 안전하게 보관하며, '
          '인증·정산 증빙은 부정 방지 및 분쟁 대응을 위해 관련 절차 종료 시까지 보관될 수 있습니다.'),
  PolicySection('4. 제3자 제공 및 처리 위탁',
      '회사는 반값여행 정산·환급 처리를 위해 필요한 범위에서 관련 지방자치단체 또는 위탁 기관에 최소한의 정보를 제공할 수 있습니다. '
          '이 경우 제공 항목·목적·보유 기간을 사전에 안내하고 동의를 받습니다.'),
  PolicySection('5. 이용자의 권리',
      '이용자는 언제든지 자신의 개인정보를 조회·수정하거나 처리 정지·삭제(회원 탈퇴)를 요청할 수 있습니다. '
          '거주지 등 일부 정보는 마이페이지에서 직접 변경할 수 있습니다.'),
  PolicySection('6. 개인정보 보호책임자 및 문의',
      '개인정보 관련 문의는 앱 내 "자주 묻는 질문" 또는 고객센터를 통해 접수할 수 있습니다.\n\n'
          '※ 본 처리방침은 서비스 준비 단계의 초안이며, 정식 출시 전 최종 검토를 거쳐 확정됩니다.'),
];
