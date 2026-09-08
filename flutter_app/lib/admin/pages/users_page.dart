import 'package:flutter/material.dart';

import '../../mock_ui/theme/app_colors.dart';
import '../../mock_ui/widgets/ui.dart';
import '../admin_models.dart';
import '../admin_repository.dart';
import '../widgets/admin_ui.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.repository, this.initialQuery, this.adminUserId});
  final AdminRepository repository;
  final String? initialQuery;
  final int? adminUserId;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery ?? '');
  int _page = 0;
  PagedResult<UserItem>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.users(query: _query.text.trim(), page: _page);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _search() {
    setState(() => _page = 0);
    _load();
  }

  Future<void> _open(UserItem u) async {
    final changed = await showSideDrawer<bool>(context, builder: (_) => _UserDrawer(user: u, repository: widget.repository, adminUserId: widget.adminUserId));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(32, 28, 32, 64), children: [
      const NoteBox('이메일·거주지·전화·실명·증빙·코스·기기 토큰은 API 응답에 포함되지 않아요. 여기서 하는 건 검색 · 정지 · 닉네임 초기화 · 관리자 승격뿐이에요.', title: '개인정보는 보이지 않아요.'),
      const SizedBox(height: 24),
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AdminSearchField(controller: _query, hint: '닉네임 또는 userId', onSubmitted: (_) => _search()),
            const SizedBox(width: 10),
            AdminButton('검색', small: true, variant: BtnVariant.ghost, onTap: _search),
            const Spacer(),
            if (_data != null) Text('${_query.text.trim().isEmpty ? '최근 가입순 · ' : '검색 결과 '}${fmtNum(_data!.total)}명', style: kTextSub),
          ]),
          const SizedBox(height: 18),
          AsyncBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            child: Column(children: [
              AdminTable(
                emptyText: '검색 결과가 없어요.',
                columns: const [
                  DataColumn(label: Text('사용자')),
                  DataColumn(label: Text('가입')),
                  DataColumn(label: Text('글 · 댓글'), numeric: true),
                  DataColumn(label: Text('신고당함'), numeric: true),
                  DataColumn(label: Text('차단당함'), numeric: true),
                  DataColumn(label: Text('상태')),
                ],
                rows: [
                  for (final u in _data?.items ?? const <UserItem>[])
                    DataRow(
                      onSelectChanged: u.withdrawn ? null : (_) => _open(u),
                      cells: [
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(u.withdrawn ? '' : avatarEmoji(u.avatarPreset), style: const TextStyle(fontSize: 18)),
                          if (!u.withdrawn) const SizedBox(width: 8),
                          cellTwo(u.displayName, 'userId ${u.id} · ${providerLabel(u.provider)}', strong: !u.withdrawn, mainColor: u.withdrawn ? AppColors.ink5 : null),
                        ])),
                        DataCell(cellTwo(fmtDate(u.createdAt), _ago(u.createdAt), strong: false)),
                        DataCell(cellNum('${u.postCount} · ${u.commentCount}')),
                        DataCell(u.reportedCount > 0 ? Align(alignment: Alignment.centerRight, child: Pill('${u.reportedCount}회', tone: PillTone.red)) : cellNum('0')),
                        DataCell(cellNum(u.blockedCount > 0 ? '${u.blockedCount}명' : '0')),
                        DataCell(userStatusPill(u)),
                      ],
                    ),
                ],
              ),
              if (_data != null && _data!.total > 0)
                Pager(page: _data!.page, pageCount: _data!.pageCount, total: _data!.total, size: _data!.size, unit: '명', onChanged: (p) {
                  setState(() => _page = p);
                  _load();
                }),
            ]),
          ),
        ]),
      ),
    ]);
  }

  static String _ago(DateTime? d) {
    if (d == null) return '';
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return '오늘';
    if (days < 7) return '$days일 전';
    if (days < 30) return '${days ~/ 7}주 전';
    if (days < 365) return '${days ~/ 30}개월 전';
    return '${days ~/ 365}년 전';
  }
}

Widget userStatusPill(UserItem u) {
  if (u.withdrawn) return const Pill('탈퇴', tone: PillTone.gray);
  if (u.suspended) return Pill(u.permanentSuspension ? '영구 정지' : '정지 · ${_mdLabel(u.suspendedUntil)}까지', tone: u.permanentSuspension ? PillTone.red : PillTone.warn);
  if (u.isAdmin) return const Pill('관리자', tone: PillTone.sky);
  return const Pill('정상', tone: PillTone.gray);
}

String _mdLabel(DateTime? d) => d == null ? '' : '${d.month}월 ${d.day}일';

/// 아바타 프리셋 "<배경>:<이모지>" — 앱 ProfilePresets 와 같은 이모지 순서.
String avatarEmoji(String? preset) {
  const emojis = ['🧑', '🐳', '🦊', '🌊', '⛺', '🍊', '🐻', '🌸', '🎈', '🍀'];
  final idx = int.tryParse(preset?.split(':').elementAtOrNull(1) ?? '') ?? 0;
  return emojis[idx % emojis.length];
}

class _UserDrawer extends StatefulWidget {
  const _UserDrawer({required this.user, required this.repository, required this.adminUserId});
  final UserItem user;
  final AdminRepository repository;
  final int? adminUserId;

  @override
  State<_UserDrawer> createState() => _UserDrawerState();
}

class _UserDrawerState extends State<_UserDrawer> {
  late UserItem _u = widget.user;
  String _days = '7';
  late final _reason = TextEditingController(text: widget.user.suspendReason ?? '');
  bool _busy = false;
  bool _changed = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<UserItem> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _u = updated;
        _changed = true;
        _busy = false;
      });
      showAdminToast(context, doneMessage);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAdminToast(context, e.toString(), error: true);
      }
    }
  }

  Future<void> _suspend() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      showAdminToast(context, '정지 사유를 입력해 주세요. 로그인 거부 화면에 그대로 보여요.', error: true);
      return;
    }
    final permanent = _days == 'P';
    final label = permanent ? '영구 정지' : '$_days일 정지';
    final ok = await showConfirmDialog(context, title: '${_u.displayName} 님을 $label할까요?', message: '즉시 로그아웃되고, 로그인하면 "이용이 정지된 계정입니다. (사유: $reason)"가 보여요.', confirmLabel: label, danger: true);
    if (!ok) return;
    await _run(() => widget.repository.suspendUser(_u.id, days: permanent ? null : int.parse(_days), reason: reason), '$label을 적용했어요.');
  }

  Future<void> _unsuspend() async {
    final ok = await showConfirmDialog(context, title: '정지를 해제할까요?', message: '바로 다시 로그인할 수 있어요.', confirmLabel: '해제');
    if (!ok) return;
    await _run(() => widget.repository.unsuspendUser(_u.id), '정지를 해제했어요.');
  }

  Future<void> _resetNickname() async {
    final ok = await showConfirmDialog(context, title: '닉네임을 초기화할까요?', message: '"${_u.displayName}"이(가) 무작위 기본 닉네임으로 바뀌어요. 본인이 다시 바꿀 수 있어요.', confirmLabel: '초기화');
    if (!ok) return;
    await _run(() => widget.repository.resetNickname(_u.id), '닉네임을 초기화했어요.');
  }

  Future<void> _toggleRole() async {
    final toAdmin = !_u.isAdmin;
    final ok = await showConfirmDialog(context, title: toAdmin ? '관리자로 승격할까요?' : '관리자 권한을 해제할까요?', message: toAdmin ? '이 계정으로 관리자 콘솔에 들어와 모든 제재·설정을 할 수 있게 돼요.' : '더 이상 콘솔에 들어올 수 없어요.', confirmLabel: toAdmin ? '승격' : '해제', danger: toAdmin);
    if (!ok) return;
    await _run(() => widget.repository.changeRole(_u.id, toAdmin ? 'ADMIN' : 'USER'), toAdmin ? '관리자로 승격했어요.' : '관리자 권한을 해제했어요.');
  }

  @override
  Widget build(BuildContext context) {
    final u = _u;
    final isSelf = u.id == widget.adminUserId;
    final penalty = u.reportedCount + u.blockedCount > 0;
    return DrawerFrame(
      title: u.displayName,
      leading: Text(avatarEmoji(u.avatarPreset), style: const TextStyle(fontSize: 26)),
      subtitle: Pill('userId ${u.id}', tone: PillTone.gray),
      sections: [
        DrawerSection('활동 요약', children: [
          KvGrid(keyWidth: 132, [
            ('가입', Text('${fmtDate(u.createdAt)} · ${providerLabel(u.provider)} 계정')),
            ('권한', Text(u.isAdmin ? '관리자' : '일반 사용자')),
            ('글 · 댓글', Text('${u.postCount}개 · ${u.commentCount}개')),
            ('신고당함 · 차단당함', Text('${u.reportedCount}회 · ${u.blockedCount}명', style: TextStyle(color: penalty ? AppColors.danger : AppColors.ink9))),
            ('현재 상태', Align(alignment: Alignment.centerLeft, child: userStatusPill(u))),
            if (u.suspended) ('정지 사유', Text(u.suspendReason ?? '—')),
            if (u.suspended && !u.permanentSuspension) ('해제 예정', Text(fmtDateTime(u.suspendedUntil))),
          ]),
        ]),
        const NoteBox('이메일·거주지·전화·여행 기록은 이 화면에 없어요.'),
        if (isSelf)
          const NoteBox('자기 자신은 정지하거나 권한을 바꿀 수 없어요.', title: '내 계정이에요.', icon: Icons.person_outline_rounded)
        else if (u.isAdmin)
          DrawerSection('관리자 계정', children: [
            const NoteBox('관리자는 정지할 수 없어요. 먼저 권한을 해제해 주세요.', icon: Icons.admin_panel_settings_outlined),
            Row(children: [
              Expanded(child: AdminButton('닉네임 초기화', variant: BtnVariant.ghost, onTap: _busy ? null : _resetNickname)),
              const SizedBox(width: 10),
              Expanded(child: AdminButton('관리자 권한 해제', variant: BtnVariant.dangerGhost, onTap: _busy ? null : _toggleRole)),
            ]),
          ])
        else ...[
          DrawerSection('이용 정지', children: [
            RadioRow(options: const [('1', '1일'), ('7', '7일'), ('30', '30일'), ('P', '영구')], value: _days, onChanged: (v) => setState(() => _days = v)),
            AdminField(label: '정지 사유', required: true, controller: _reason, hint: '예: 스팸 게시 반복', maxLines: 2, help: '로그인 거부 화면에 "이용이 정지된 계정입니다. (사유: …)"로 그대로 보여요.'),
            Row(children: [
              Expanded(child: AdminButton(u.suspended ? '정지 기간·사유 변경' : '정지 적용', variant: BtnVariant.dangerGhost, loading: _busy, onTap: _suspend)),
              const SizedBox(width: 10),
              Expanded(child: AdminButton('정지 해제', variant: BtnVariant.ghost, onTap: u.suspended && !_busy ? _unsuspend : null)),
            ]),
          ]),
          DrawerSection('기타 조치', children: [
            Row(children: [
              Expanded(child: AdminButton('닉네임 초기화', variant: BtnVariant.ghost, onTap: _busy ? null : _resetNickname)),
              const SizedBox(width: 10),
              Expanded(child: AdminButton('관리자로 승격', variant: BtnVariant.ghost, onTap: _busy ? null : _toggleRole)),
            ]),
          ]),
        ],
      ],
      footer: [AdminButton('닫기', variant: BtnVariant.ghost, onTap: () => Navigator.pop(context, _changed))],
    );
  }
}
