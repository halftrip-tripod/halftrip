import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ui/app_card.dart';

/// 마이페이지 "이용 안내" 정적 콘텐츠 화면 모음
/// (공지사항 · 자주 묻는 질문 · 이용약관 · 개인정보 처리방침).
/// 서버 연동 없이 앱 번들 콘텐츠로 제공 — 공지/약관은 추후 CMS·법무 확정 시 교체.

// ─────────────────────────────────────────────── 공지사항

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('공지사항')),
      body: SafeArea(
        child: _notices.isEmpty
            ? const _EmptyInfo('등록된 공지가 없어요')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: _notices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _NoticeCard(_notices[i]),
              ),
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.p50,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(notice.tag,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.p600,
                    )),
              ),
              const Spacer(),
              Text(notice.date,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink4,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(notice.title,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink9,
              )),
          const SizedBox(height: 6),
          Text(notice.body,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                height: 1.55,
                color: AppColors.ink5,
              )),
        ],
      ),
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('자주 묻는 질문')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          itemCount: _faqs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _FaqTile(
            faq: _faqs[i],
            open: _openIndex == i,
            onTap: () =>
                setState(() => _openIndex = _openIndex == i ? null : i),
          ),
        ),
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 — splash/하이라이트 없이 탭만 (펼침 자체가 피드백)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Q',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.p600,
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(faq.q,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink9,
                        )),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: open ? AppColors.p600 : AppColors.ink4),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(faq.a,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      height: 1.6,
                      color: AppColors.ink5,
                    )),
              ),
            ),
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
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
        effectiveDate: '2026.07.27',
        sections: _termsSections,
      );

  factory PolicyScreen.privacy() => const PolicyScreen(
        title: '개인정보 처리방침',
        effectiveDate: '2026.07.27',
        sections: _privacySections,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text('시행일: $effectiveDate',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink4,
                )),
            const SizedBox(height: 16),
            ...sections.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.heading,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink9,
                          )),
                      const SizedBox(height: 8),
                      Text(s.body,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13.5,
                            height: 1.7,
                            color: AppColors.ink7,
                          )),
                    ],
                  ),
                )),
          ],
        ),
      ),
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
      '이 약관은 하프트립 팀(이하 "팀")이 제공하는 반값여행 정보 제공·여행 기록·환급 증빙 보조 서비스 "하프트립"(이하 "서비스")의 이용 조건과 팀·이용자의 권리, 의무 및 책임사항을 정합니다.'),
  PolicySection('제2조 (정의)',
      '1. "반값여행"이란 각 지방자치단체가 운영하는 국내 여행 경비 환급 지원 사업을 말합니다.\n'
          '2. "환급 증빙"이란 인증사진, 영수증, 숙박확인서 등 지자체 정산 신청에 필요한 자료를 말합니다.\n'
          '3. "커뮤니티"란 이용자가 후기·코스 등을 게시·열람하는 공간을 말합니다.'),
  PolicySection('제3조 (서비스의 성격) ★중요',
      '1. 서비스는 지자체 반값여행 사업의 정보 제공과 증빙 준비를 돕는 보조 도구입니다.\n'
          '2. 반값여행 신청 접수, 심사, 환급금 지급 여부·시기·금액은 전적으로 해당 지자체의 소관이며, 팀은 이를 보증하지 않습니다.\n'
          '3. 앱의 자동 판정(인증사진 분석, 영수증 인식 등)은 참고용이며, 최종 인정 여부는 지자체 심사에 따릅니다.\n'
          '4. 지역별 사업 조건은 지자체 사정으로 예고 없이 변경될 수 있으며, 앱 정보와 실제 공고가 다른 경우 지자체 공고가 우선합니다.'),
  PolicySection('제4조 (계정)',
      '1. 서비스는 카카오·네이버 계정 연동으로 가입할 수 있으며, 만 14세 미만은 가입할 수 없습니다.\n'
          '2. 계정은 본인만 이용해야 하며, 제3자에게 양도·대여할 수 없습니다.\n'
          '3. 이용자는 언제든지 앱 내 설정 또는 팀 이메일을 통해 탈퇴(계정 삭제)를 요청할 수 있습니다.'),
  PolicySection('제5조 (이용자의 의무)',
      '이용자는 다음 행위를 해서는 안 됩니다.\n'
          '1. 타인의 사진·영수증 도용 등 허위 증빙으로 환급을 신청하는 행위(관련 법령에 따라 처벌될 수 있습니다)\n'
          '2. 타인의 개인정보 수집·게시, 명예훼손, 음란·혐오 게시물 작성\n'
          '3. 서비스의 정상 운영을 방해하는 행위'),
  PolicySection('제6조 (게시물)',
      '1. 커뮤니티 게시물의 저작권은 작성자에게 있습니다.\n'
          '2. 팀은 서비스 운영·홍보를 위해 필요한 범위에서 게시물을 무상으로 사용할 수 있으며, 이용자는 언제든 게시물을 삭제할 수 있습니다.\n'
          '3. 제5조를 위반한 게시물은 사전 통지 없이 삭제될 수 있습니다.'),
  PolicySection('제7조 (면책)',
      '1. 팀은 지자체의 환급 거절·지연·사업 중단, 외부 서비스(지자체 사이트, 지도, 소셜 로그인 등) 장애로 인한 손해에 대해 책임을 지지 않습니다.\n'
          '2. 팀은 이용자의 귀책사유(허위 증빙, 기한 미준수 등)로 발생한 불이익에 대해 책임을 지지 않습니다.\n'
          '3. 무료로 제공되는 서비스의 하자와 관련하여 관련 법령에 특별한 규정이 없는 한 책임을 지지 않습니다.'),
  PolicySection('제8조 (약관의 변경)',
      '팀은 관련 법령을 위반하지 않는 범위에서 약관을 변경할 수 있으며, 변경 시 시행 7일 전(이용자에게 불리한 변경은 30일 전) 앱 내 공지합니다.'),
  PolicySection('제9조 (준거법 및 분쟁 해결)',
      '이 약관은 대한민국 법령에 따라 해석되며, 분쟁은 민사소송법상 관할법원에 제소합니다.'),
];

const _privacySections = [
  PolicySection('1. 총칙',
      '하프트립 팀(이하 "팀")은 개인정보 보호법 제30조에 따라 이용자의 개인정보를 보호하고 관련 고충을 신속하게 처리하기 위해 다음과 같이 개인정보 처리방침을 수립·공개합니다.'),
  PolicySection('2. 처리하는 개인정보의 항목·목적·보유기간',
      '① 회원 관리 — 소셜 로그인 식별자(카카오·네이버 회원번호), 이메일, 거주지(시·군·구), 닉네임·프로필 설정 / 회원 탈퇴 시까지\n'
          '② 정산 신청 지원 — 성명, 전화번호 (정산 신청 시점에만 입력받아 해당 여행 기록에만 저장) / 회원 탈퇴 또는 삭제 요청 시까지\n'
          '③ 환급 증빙 보조 — 인증사진·영수증·숙박확인서 이미지 및 사진에 포함된 촬영 시각·위치(GPS) 정보, 전자서명 / 회원 탈퇴 또는 삭제 요청 시까지\n'
          '④ 알림 제공 — 푸시 토큰, 알림 설정 / 회원 탈퇴 시까지\n'
          '⑤ 서비스 이용 기록(접속 로그) / 3개월\n'
          '※ 팀은 위 목적 외로 개인정보를 이용하지 않으며, 만 14세 미만 아동의 개인정보를 수집하지 않습니다.'),
  PolicySection('3. 인증사진의 위치정보 처리',
      '인증사진에 포함된 위치(GPS)·촬영시각 정보는 지자체 환급 요건(지정관광지 방문, 여행 기간 내 촬영) 확인 목적으로만 이용됩니다. '
          '위치정보는 판정(적합/부적합) 목적으로 처리되며, 이용자가 사진을 삭제하면 함께 파기됩니다.'),
  PolicySection('4. 개인정보의 제3자 제공',
      '팀은 이용자의 개인정보를 제3자에게 제공하지 않습니다. 지자체 정산 신청 시 증빙 자료는 이용자가 직접 다운로드하여 해당 지자체에 제출합니다.'),
  PolicySection('5. 개인정보 처리의 위탁 및 국외 이전',
      '서비스 운영을 위해 다음과 같이 처리를 위탁하며, 일부는 국외에서 처리됩니다.\n'
          '· OpenAI, L.L.C.(미국) — 인증사진 적합성 판정, 영수증 문자 인식 / 이미지 데이터, 처리 즉시 결과 반환\n'
          '· Google LLC(미국) — 지도 표시, 푸시 알림(FCM) 전송 / 좌표·푸시 토큰\n'
          '· Render Services, Inc.(미국) — 서버 및 데이터 보관 / 제2항의 개인정보 일체\n'
          '· 카카오·네이버(국내) — 소셜 로그인 인증\n'
          '이용자는 국외 이전을 거부할 수 있으나, 이 경우 서비스 이용이 제한될 수 있습니다.'),
  PolicySection('6. 개인정보의 파기',
      '보유기간이 경과하거나 처리 목적이 달성된 개인정보는 지체 없이 파기합니다. 전자적 파일은 복구할 수 없는 방법으로 삭제하며, 관련 법령에 따라 보존해야 하는 정보는 별도 분리 보관 후 기간 경과 시 파기합니다.'),
  PolicySection('7. 정보주체의 권리와 행사 방법',
      '이용자는 언제든지 개인정보 열람·정정·삭제·처리정지를 요구할 수 있습니다.\n'
          '· 앱 내: 마이페이지에서 거주지·프로필 수정, 설정에서 회원 탈퇴(계정·데이터 삭제)\n'
          '· 이메일: 아래 보호책임자 연락처로 요청 (앱 삭제 후에도 이메일로 계정 삭제를 요청할 수 있습니다)\n'
          '팀은 요청을 받은 날부터 10일 이내에 조치 결과를 알려드립니다.'),
  PolicySection('8. 안전성 확보 조치',
      '팀은 개인정보의 안전한 처리를 위해 통신 구간 암호화(HTTPS), 접근 권한 최소화, 정산 관련 실명·연락처의 수집 시점 최소화(신청 시에만 수집) 등의 조치를 시행합니다.'),
  PolicySection('9. 개인정보 보호책임자',
      '개인정보 보호책임자: 하프트립 팀 대표(팀장)\n'
          '문의: rbgml4059@naver.com\n'
          '기타 개인정보 침해 신고·상담: 개인정보침해신고센터(privacy.kisa.or.kr, 118), 개인정보 분쟁조정위원회(kopico.go.kr, 1833-6972)'),
  PolicySection('10. 처리방침의 변경',
      '이 방침의 내용이 변경되는 경우 시행 7일 전부터 앱 내 공지사항을 통해 알려드립니다.'),
];

// ─────────────────────────────────────────────── 공용 빈 상태

class _EmptyInfo extends StatelessWidget {
  const _EmptyInfo(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink4,
          )),
    );
  }
}
