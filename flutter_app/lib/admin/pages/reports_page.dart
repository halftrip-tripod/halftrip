import 'package:flutter/material.dart';

import '../../mock_ui/theme/app_colors.dart';
import '../../mock_ui/widgets/ui.dart';
import '../admin_models.dart';
import '../admin_repository.dart';
import '../widgets/admin_ui.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.repository, required this.onPendingChanged, required this.onOpenUser});
  final AdminRepository repository;
  final ValueChanged<int> onPendingChanged;
  final ValueChanged<int> onOpenUser;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _status = 'PENDING';
  int _page = 0;
  PagedResult<ReportItem>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.reports(status: _status, page: _page);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      if (_status == 'PENDING') widget.onPendingChanged(data.total);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(ReportItem r) async {
    final changed = await showSideDrawer<bool>(
      context,
      builder: (c) => _ReportDrawer(report: r, repository: widget.repository, onOpenUser: (id) {
        Navigator.pop(c);
        widget.onOpenUser(id);
      }),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (_status) { 'RESOLVED' => '처리됨', 'DISMISSED' => '기각', 'ALL' => '전체', _ => '대기' };
    return ListView(padding: const EdgeInsets.fromLTRB(32, 28, 32, 64), children: [
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SegFilter(
              options: const [('PENDING', '대기'), ('RESOLVED', '처리됨'), ('DISMISSED', '기각'), ('ALL', '전체')],
              value: _status,
              onChanged: (v) {
                setState(() {
                  _status = v;
                  _page = 0;
                });
                _load();
              },
            ),
            const Spacer(),
            if (_data != null) Text('$statusLabel ${_data!.total}건', style: kTextSub),
          ]),
          const SizedBox(height: 18),
          AsyncBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            child: Column(children: [
              AdminTable(
                emptyText: _status == 'PENDING' ? '대기 중인 신고가 없어요 🎉' : '해당하는 신고가 없어요.',
                columns: const [
                  DataColumn(label: Text('대상')),
                  DataColumn(label: Text('신고된 내용')),
                  DataColumn(label: Text('작성자')),
                  DataColumn(label: Text('신고자 · 사유')),
                  DataColumn(label: Text('같은 대상 신고'), numeric: true),
                  DataColumn(label: Text('상태')),
                  DataColumn(label: Text('접수')),
                ],
                rows: [
                  for (final r in _data?.items ?? const <ReportItem>[])
                    DataRow(
                      onSelectChanged: (_) => _open(r),
                      cells: [
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          Pill(r.isComment ? '댓글' : '글', tone: r.isComment ? PillTone.mint : PillTone.sky),
                          const SizedBox(width: 8),
                          cellId('#${r.targetId}'),
                        ])),
                        DataCell(cellEllipsis(r.targetRemoved ? '(내려간 콘텐츠) ${r.targetBody ?? ''}' : (r.targetBody ?? ''), width: 340)),
                        DataCell(cellTwo(r.authorNickname ?? '—', 'userId ${r.authorId ?? '-'}${r.authorReportedCount > 0 ? ' · 신고당함 ${r.authorReportedCount}회' : ''}')),
                        DataCell(cellTwo(r.reporterNickname ?? '—', reasonLabel(r.reason), strong: false)),
                        DataCell(r.targetReportCount > 1 ? Align(alignment: Alignment.centerRight, child: Pill('${r.targetReportCount}건', tone: PillTone.red)) : cellNum('${r.targetReportCount}건')),
                        DataCell(_statusPill(r)),
                        DataCell(cellMuted(fmtShort(r.createdAt))),
                      ],
                    ),
                ],
              ),
              if (_data != null && _data!.total > 0)
                Pager(page: _data!.page, pageCount: _data!.pageCount, total: _data!.total, size: _data!.size, onChanged: (p) {
                  setState(() => _page = p);
                  _load();
                }),
            ]),
          ),
        ]),
      ),
    ]);
  }

  static Widget _statusPill(ReportItem r) => switch (r.status) {
        'RESOLVED' => Pill(r.action == 'DELETE' ? '삭제됨' : '숨김', tone: PillTone.gray),
        'DISMISSED' => const Pill('기각', tone: PillTone.gray),
        _ => const Pill('대기', tone: PillTone.warn),
      };
}

class _ReportDrawer extends StatefulWidget {
  const _ReportDrawer({required this.report, required this.repository, required this.onOpenUser});
  final ReportItem report;
  final AdminRepository repository;
  final ValueChanged<int> onOpenUser;

  @override
  State<_ReportDrawer> createState() => _ReportDrawerState();
}

class _ReportDrawerState extends State<_ReportDrawer> {
  String _action = 'HIDE';
  final _memo = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final r = widget.report;
    final label = switch (_action) { 'DELETE' => '삭제', 'DISMISS' => '기각', _ => '숨김' };
    final effect = _action == 'DISMISS'
        ? '대상은 그대로 두고 신고만 닫아요.'
        : '${r.isComment ? '댓글' : '글'} #${r.targetId}이(가) 피드에서 바로 내려가요.${_action == 'DELETE' ? ' 작성자에게 삭제 안내가 가요.' : ''}';
    final siblings = r.targetReportCount > 1 ? ' 같은 대상의 대기 신고 ${r.targetReportCount}건이 함께 닫혀요.' : '';
    final ok = await showConfirmDialog(context, title: '$label 처리할까요?', message: '$effect$siblings 신고자에게 결과 알림이 가요.', confirmLabel: '$label 처리', danger: _action == 'DELETE');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.resolveReport(r.id, action: _action, memo: _memo.text.trim().isEmpty ? null : _memo.text.trim());
      if (!mounted) return;
      showAdminToast(context, '신고 #${r.id}을(를) $label 처리했어요.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAdminToast(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final pending = r.isPending;
    final kind = r.isComment ? '댓글' : '글';
    return DrawerFrame(
      title: pending ? '신고 #${r.id} 처리' : '신고 #${r.id}',
      subtitle: Pill('$kind #${r.targetId}', tone: r.isComment ? PillTone.mint : PillTone.sky),
      sections: [
        DrawerSection('신고된 게시물 — 공개 본문', children: [
          QuoteBox(
            title: r.isComment ? null : (r.targetTitle == null || r.targetTitle!.isEmpty ? '제목 없음' : r.targetTitle),
            body: r.targetBody ?? '',
            meta: [if (r.targetRemoved) '이미 내려간 콘텐츠', if (r.isComment && r.postId != null) '글 #${r.postId}의 댓글'].join(' · '),
          ),
        ]),
        DrawerSection('신고 정보', children: [
          KvGrid([
            ('작성자', Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
              Text(r.authorNickname ?? '—'),
              if (r.authorId != null) Text('userId ${r.authorId}', style: kTextId),
              if (r.authorReportedCount > 0) Text('· 신고당함 ${r.authorReportedCount}회', style: const TextStyle(color: AppColors.danger)),
              if (r.authorId != null) LinkText('회원 보기 →', onTap: () => widget.onOpenUser(r.authorId!)),
            ])),
            ('신고자', Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [Text(r.reporterNickname ?? '—'), if (r.reporterId != null) Text('userId ${r.reporterId}', style: kTextId)])),
            ('사유', Text(reasonLabel(r.reason))),
            ('접수', Text(fmtDateTime(r.createdAt))),
            ('같은 대상 신고', r.targetReportCount > 1
                ? Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [Pill('${r.targetReportCount}건', tone: PillTone.red), const Text('처리하면 함께 닫혀요')])
                : const Text('이 건뿐이에요')),
            if (!pending) ...[
              ('처리 결과', Text('${switch (r.action) { 'DELETE' => '삭제', 'DISMISS' => '기각', _ => '숨김' }} · ${fmtDateTime(r.handledAt)} · 관리자 userId ${r.handledBy ?? '-'}')),
              ('내부 메모', Text(r.memo == null || r.memo!.isEmpty ? '—' : r.memo!)),
            ],
          ]),
        ]),
        if (pending)
          DrawerSection('처리 방법', children: [
            RadioRow(options: const [('HIDE', '숨김'), ('DELETE', '삭제 + 작성자 안내'), ('DISMISS', '기각')], value: _action, onChanged: (v) => setState(() => _action = v)),
            const Text.rich(TextSpan(children: [
              TextSpan(text: '숨김·삭제 모두 피드에서 바로 내려가요(소프트 삭제). '),
              TextSpan(text: '삭제', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink9)),
              TextSpan(text: '는 작성자에게 "게시물이 삭제되었어요" 알림이 가고, 신고자에게는 어느 쪽이든 결과 알림이 가요.'),
            ]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.5)),
            AdminField(label: '내부 메모', controller: _memo, hint: '처리 근거를 남겨 두면 감사 로그에 함께 저장돼요', maxLines: 3, help: '선택 · 신고자·작성자에게는 보이지 않아요'),
            if (r.targetRemoved) const NoteBox('이미 내려간 콘텐츠예요. 처리하면 신고만 닫혀요.', icon: Icons.info_outline_rounded),
          ]),
      ],
      footer: [
        AdminButton(pending ? '취소' : '닫기', variant: BtnVariant.ghost, onTap: () => Navigator.pop(context)),
        if (pending) AdminButton(switch (_action) { 'DELETE' => '삭제 처리', 'DISMISS' => '기각', _ => '숨김 처리' }, variant: _action == 'DELETE' ? BtnVariant.danger : BtnVariant.sky, loading: _busy, onTap: _submit),
      ],
    );
  }
}
