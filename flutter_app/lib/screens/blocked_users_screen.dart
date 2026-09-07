import 'package:flutter/material.dart';

import '../mock_ui/state/app_state.dart';
import '../mock_ui/theme/app_colors.dart';
import '../mock_ui/widgets/ui.dart';

/// 마이페이지 > 차단한 사용자 — 차단 목록 보기·해제.
/// 차단은 기기 저장(AppState.blockedUsers)이라 이 화면도 그 목록을 그대로 보여준다.
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final entries = AppState.I.blockedUsers.entries.toList();
        return DetailScaffold(
          title: '차단한 사용자',
          children: [
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('차단한 사용자가 없어요.\n커뮤니티 글의 ⋯ 메뉴나 댓글을 길게 눌러 차단할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink4, height: 1.6)),
                ),
              )
            else
              MenuGroup(children: [
                for (final e in entries)
                  ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: AppColors.surf,
                        child: Icon(Icons.person_off_outlined, color: AppColors.ink5)),
                    title: Text(e.value,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9)),
                    trailing: TextButton(
                      onPressed: () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: '${e.value} 님 차단을 해제할까요?',
                          message: '이 사용자의 글과 댓글이 다시 보여요.',
                          confirmLabel: '해제',
                        );
                        if (!ok || !context.mounted) return;
                        await AppState.I.unblockUser(e.key);
                        if (context.mounted) showToast(context, '차단을 해제했어요.');
                      },
                      child: const Text('해제',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.p600)),
                    ),
                  ),
              ]),
          ],
        );
      },
    );
  }
}
