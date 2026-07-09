import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

/// S9-2 알림 센터 — 오늘/지난 그룹, 안읽음 표시, 모두 읽음.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final today = s.notifications.take(3).toList();
    final past = s.notifications.skip(3).toList();

    return DetailScaffold(
      title: '알림',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      actions: [
        TextButton(
          onPressed: () {
            s.readAllNotifications();
            setState(() {});
          },
          child: const Text('모두 읽음',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        ),
      ],
      children: [
        if (s.notifications.every((n) => !n.unread) && today.isEmpty) ...[
          const SizedBox(height: 80),
          const Center(
            child: Column(children: [
              Text('새로운 알림이 없어요',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              SizedBox(height: 6),
              Text('접수 시작·정산 마감·좋아요 소식이 오면 여기에 모아둘게요.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5)),
            ]),
          ),
        ] else ...[
          const _NGroupLabel('오늘'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [for (final n in today) _NRow(n: n, onTap: () => _read(n))]),
          ),
          const _NGroupLabel('지난 알림'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [for (final n in past) _NRow(n: n, onTap: () => _read(n))]),
          ),
        ],
      ],
    );
  }

  void _read(NotifItem n) {
    setState(() => n.unread = false);
    AppState.I.update();
    showMock(context, '알림에서 해당 화면으로 이동해요. (목업)');
  }
}

class _NGroupLabel extends StatelessWidget {
  const _NGroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink5)),
    );
  }
}

class _NRow extends StatelessWidget {
  const _NRow({required this.n, required this.onTap});
  final NotifItem n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (n.tone) {
      NotifTone.sky => (AppColors.p100, AppColors.p600),
      NotifTone.coral => (AppColors.coralTint, AppColors.coralDeep),
      NotifTone.amber => (AppColors.warningTint, const Color(0xFFB8731B)),
      NotifTone.gray => (AppColors.track, AppColors.ink5),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(n.icon, size: 19, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink9)),
              const SizedBox(height: 3),
              Text(n.body,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.45)),
              const SizedBox(height: 5),
              Text(n.timeAgo,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink4)),
            ]),
          ),
          if (n.unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5, left: 6),
              decoration: const BoxDecoration(color: AppColors.p500, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}
