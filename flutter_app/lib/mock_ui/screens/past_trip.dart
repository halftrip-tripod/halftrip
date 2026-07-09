import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'community.dart';

/// 지난 여행 (환급 완료).
class PastTripScreen extends StatelessWidget {
  const PastTripScreen({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: '지난 여행',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        // HERO
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              EmojiBox(trip.emoji, size: 64, fontSize: 34, radius: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trip.region,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -1)),
                  const SizedBox(height: 3),
                  const Text('충청북도 · 1박2일',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink4)),
                ]),
              ),
              const Pill('환급 완료', tone: PillTone.gold),
            ]),
            const SizedBox(height: 14),
            const Text('5.10 ~ 5.11 · 2명 · 환급 보장 코스',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          ]),
        ),
        // 다녀온 코스
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            SurfRow(
              icon: Icons.route_outlined,
              title: '다녀온 코스',
              subtitle: '${trip.region} 환급 보장 코스 · 5곳',
              onTap: () => showMock(context, '코스 상세는 저장 코스함에서 볼 수 있어요.'),
            ),
            const SizedBox(height: 10),
            const CourseMapCard(day1: 4, day2: 1, showLegend: false),
          ]),
        ),
        // 내 후기
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('내 후기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
              const SizedBox(width: 8),
              const Pill('나만보기', tone: PillTone.gray, icon: Icons.lock_outline_rounded),
              const Spacer(),
              GestureDetector(
                onTap: () => showMock(context, '후기 수정은 목업에서 생략했어요.'),
                child: const Row(children: [
                  Icon(Icons.edit_outlined, size: 14, color: AppColors.ink5),
                  SizedBox(width: 4),
                  Text('수정',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('혼자 다녀온 기록용. 청풍호 케이블카 뷰 정리해뒀음. 의림지 야경도 좋았고 다음엔 친구랑 또 가기.',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
            const SizedBox(height: 12),
            const Row(children: [
              EmojiBox('🚠', size: 88, fontSize: 38, color: AppColors.surf),
              SizedBox(width: 8),
              EmojiBox('🌌', size: 88, fontSize: 38, color: AppColors.surf),
              SizedBox(width: 8),
              EmojiBox('🏞️', size: 88, fontSize: 38, color: AppColors.surf),
            ]),
            const SizedBox(height: 14),
            OutlineButton('공개로 전환하고 커뮤니티에 공유', onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CommunityWriteScreen(regionName: trip.region)));
            }),
          ]),
        ),
        // 여행 기록
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('여행 기록',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.3)),
            const SizedBox(height: 8),
            const _RecordRow(icon: Icons.photo_camera_outlined, label: '관광지 인증샷', value: '8장'),
            const _RecordRow(icon: Icons.credit_card_rounded, label: '영수증', value: '12건 · 41만원'),
            const _RecordRow(icon: Icons.bed_outlined, label: '숙박확인서', value: '1건'),
            const SizedBox(height: 8),
            OutlineButton('제출한 증빙 패키지 보기',
                icon: Icons.description_outlined,
                onTap: () => showMock(context, '증빙 패키지 미리보기는 목업에서 생략했어요.')),
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
              subtitle: '${trip.region} 온라인몰 · 지역화폐 가맹점',
              onTap: () => showMock(context, '온라인몰 탭에서 확인할 수 있어요.'),
            ),
          ]),
        ),
      ],
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
        Text(value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink4)),
      ]),
    );
  }
}
