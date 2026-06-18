import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 알림 센터. 디자인: halftrip-design/notifications.html
/// 현재는 mock 목록(알림 모델/리포지토리 미구현 — FCM·서버 연동 예정).
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late List<_Noti> _today;
  late List<_Noti> _earlier;

  @override
  void initState() {
    super.initState();
    _today = List.of(_mockToday);
    _earlier = List.of(_mockEarlier);
  }

  bool get _hasUnread =>
      _today.any((n) => n.unread) || _earlier.any((n) => n.unread);

  void _markAllRead() {
    setState(() {
      _today = _today.map((n) => n.read()).toList();
      _earlier = _earlier.map((n) => n.read()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('모두 읽음'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_today.isNotEmpty) ...[
              const _GroupLabel('오늘'),
              ..._today.map((n) => _NotiRow(n)),
            ],
            if (_earlier.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _GroupLabel('지난 알림'),
              ..._earlier.map((n) => _NotiRow(n)),
            ],
          ],
        ),
      ),
    );
  }
}

enum _NotiTone { sky, coral, amber, gray }

class _Noti {
  const _Noti({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    this.unread = false,
  });

  final _NotiTone tone;
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final bool unread;

  _Noti read() => _Noti(
        tone: tone,
        icon: icon,
        title: title,
        body: body,
        time: time,
        unread: false,
      );
}

const _mockToday = [
  _Noti(
    tone: _NotiTone.sky,
    icon: Icons.flag_outlined,
    title: '강진 반값여행 접수 시작 🎉',
    body: '관심 등록한 강진의 6월 반값여행 접수가 열렸어요. 지금 신청해보세요.',
    time: '10분 전',
    unread: true,
  ),
  _Noti(
    tone: _NotiTone.sky,
    icon: Icons.route_outlined,
    title: '유튜브 코스가 완성됐어요',
    body: '강진 유튜브 추천 코스를 내 코스함에 저장했어요. 확인해보세요.',
    time: '1시간 전',
    unread: true,
  ),
  _Noti(
    tone: _NotiTone.coral,
    icon: Icons.favorite,
    title: '여행하는민트님 외 4명이 좋아해요',
    body: '내 글 "강진 여행 후기"에 좋아요가 달렸어요.',
    time: '3시간 전',
    unread: true,
  ),
];

const _mockEarlier = [
  _Noti(
    tone: _NotiTone.amber,
    icon: Icons.schedule_outlined,
    title: '영월 정산 신청 마감 D-3',
    body: '여행 종료 다음날부터 7일 이내에 정산을 신청하세요.',
    time: '어제',
  ),
  _Noti(
    tone: _NotiTone.sky,
    icon: Icons.chat_bubble_outline,
    title: '강진가고파님이 댓글을 남겼어요',
    body: '가우도 주차는 어디 하셨어요?',
    time: '2일 전',
  ),
  _Noti(
    tone: _NotiTone.amber,
    icon: Icons.schedule_outlined,
    title: '완도 접수 마감 D-1',
    body: '관심 등록한 완도 반값여행 접수가 곧 마감돼요.',
    time: '3일 전',
  ),
  _Noti(
    tone: _NotiTone.gray,
    icon: Icons.card_giftcard_outlined,
    title: '디지털 관광주민증 혜택 추가',
    body: '강진 가맹점에 디민증 추가 할인 혜택이 생겼어요.',
    time: '1주 전',
  ),
];

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink5,
        ),
      ),
    );
  }
}

class _NotiRow extends StatelessWidget {
  const _NotiRow(this.noti);
  final _Noti noti;

  (Color, Color) _palette() => switch (noti.tone) {
        _NotiTone.sky => (AppColors.p100, AppColors.p600),
        _NotiTone.coral => (AppColors.coralTint, AppColors.coralDeep),
        _NotiTone.amber => (const Color(0xFFFFF3E2), const Color(0xFFB8731B)),
        _NotiTone.gray => (AppColors.track, AppColors.ink5),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: noti.unread ? AppColors.p50 : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        boxShadow: noti.unread ? null : AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(noti.icon, size: 19, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(noti.title,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink9,
                    )),
                const SizedBox(height: 3),
                Text(noti.body,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.ink5,
                    )),
                const SizedBox(height: 6),
                Text(noti.time,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink4,
                    )),
              ],
            ),
          ),
          if (noti.unread)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.p500,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
