import 'package:flutter/material.dart';

import '../../mock_ui/theme/app_colors.dart';
import '../../mock_ui/widgets/ui.dart';
import '../admin_models.dart';
import '../admin_repository.dart';
import '../widgets/admin_ui.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.repository, required this.onLoaded, required this.onOpenReports, required this.onOpenRegions});
  final AdminRepository repository;
  final ValueChanged<Dashboard> onLoaded;
  final VoidCallback onOpenReports, onOpenRegions;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _regionPageSize = 12;
  Dashboard? _data;
  int _regionPage = 0;
  Duration? _springLatency;
  Duration? _fastApiLatency;
  bool _fastApiChecked = false;
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
    final sw = Stopwatch()..start();
    try {
      final data = await widget.repository.dashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _springLatency = sw.elapsed;
        _loading = false;
      });
      widget.onLoaded(data);
      widget.repository.pingFastApi().then((d) {
        if (mounted) {
          setState(() {
            _fastApiLatency = d;
            _fastApiChecked = true;
          });
        }
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

  @override
  Widget build(BuildContext context) {
    return AsyncBody(loading: _loading, error: _error, onRetry: _load, child: _data == null ? const SizedBox() : _body(_data!));
  }

  Widget _body(Dashboard d) {
    final t = d.today, y = d.yesterday;
    final applying = d.regions.where((r) => r.statusCode == 'APPLYING').length;
    final preparing = d.regions.where((r) => r.statusCode == 'PREPARING').length;
    final closed = d.regions.length - applying - preparing;
    final missing = d.regions.where((r) => r.dataMissing).toList();
    final locked = d.regions.where((r) => r.syncLocked).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(32, 28, 32, 64), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: KpiCard(label: '오늘 신규 가입', value: '${t.signups}', unit: '명', delta: _delta(t.signups, y.signups, '명'), deltaTone: _deltaTone(t.signups, y.signups))),
        const SizedBox(width: 20),
        Expanded(child: KpiCard(label: '여행 생성 · 정산 신청', value: '${t.trips} · ${t.settlements}', unit: '건', delta: ('', '어제 ${y.trips}건 · ${y.settlements}건'))),
        const SizedBox(width: 20),
        Expanded(child: KpiCard(label: '커뮤니티 글 · 댓글', value: '${t.posts} · ${t.comments}', unit: '개', delta: _delta(t.posts, y.posts, '개', extra: ' · ${y.comments}개'), deltaTone: _deltaTone(t.posts, y.posts))),
        const SizedBox(width: 20),
        Expanded(child: KpiCard(label: '미처리 신고', value: '${d.pendingReports}', unit: '건', delta: (d.pendingReports > 0 ? '신고 큐 열기 →' : '', d.pendingReports > 0 ? '' : '대기 중인 신고가 없어요'), danger: d.pendingReports > 0, onTap: widget.onOpenReports)),
      ]),
      const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: AdminCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CardTitle('지역 현황', hint: '${d.regions.length}개 · 접수중 $applying · 준비중 $preparing · 마감 $closed', trailing: LinkText('지역 관리 →', onTap: widget.onOpenRegions)),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = (c.maxWidth / 210).floor().clamp(2, 4);
                  final w = (c.maxWidth - (cols - 1) * 14) / cols;
                  final pageCount = (d.regions.length + _regionPageSize - 1) ~/ _regionPageSize;
                  final page = _regionPage.clamp(0, pageCount == 0 ? 0 : pageCount - 1);
                  final shown = d.regions.skip(page * _regionPageSize).take(_regionPageSize);
                  return Column(children: [
                    Wrap(spacing: 14, runSpacing: 14, children: [for (final r in shown) SizedBox(width: w, child: _RegionCard(r))]),
                    if (pageCount > 1)
                      Pager(page: page, pageCount: pageCount, total: d.regions.length, size: _regionPageSize, unit: '개', onChanged: (v) => setState(() => _regionPage = v)),
                  ]);
                },
              ),
            ]),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Column(children: [
            AdminCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CardTitle('상태 신호등', hint: d.serverTime == null ? null : '서버 ${fmtDateTime(d.serverTime)} 기준'),
                StatusLight(tone: PillTone.success, label: 'Spring API', value: '정상 · 대시보드 응답 ${_sec(_springLatency)}'),
                StatusLight(
                  tone: !_fastApiChecked ? PillTone.gray : _fastApiLatency == null ? PillTone.warn : PillTone.success,
                  label: 'FastAPI 워커',
                  value: !_fastApiChecked ? '확인 중…' : _fastApiLatency == null ? '응답 없음 · 슬립 중이거나 브라우저에서 확인 불가(CORS)' : '정상 · /health 응답 ${_sec(_fastApiLatency)}',
                ),
                _batchLight(d, 'visitkorea-sync', 'VisitKorea 동기화 (08:30 · 18:30)', staleAfter: const Duration(hours: 14)),
                _batchLight(d, 'daily-reminder', '리마인더 배치 (매일 09:00)', staleAfter: const Duration(hours: 26)),
                const StatusLight(tone: PillTone.gray, label: 'FCM 푸시 진단', value: '시스템 메뉴에서 확인 (S3)'),
              ]),
            ),
            const SizedBox(height: 24),
            AdminCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CardTitle('총계'),
                KvGrid(keyWidth: 120, [
                  ('전체 회원', Text('${fmtNum(d.totalUsers)}명')),
                  ('전체 여행', Text('${fmtNum(d.totalTrips)}건')),
                  ('데이터 없는 지역', Text(missing.isEmpty ? '없음' : '${missing.length}곳 (${missing.map((r) => r.name).take(5).join('·')}${missing.length > 5 ? ' 외' : ''})', style: TextStyle(color: missing.isEmpty ? AppColors.ink9 : AppColors.danger))),
                  ('동기화 잠금', Text(locked.isEmpty ? '없음' : '${locked.length}곳 (${locked.map((r) => r.name).join('·')})')),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    ]);
  }

  Widget _batchLight(Dashboard d, String name, String label, {required Duration staleAfter}) {
    final run = d.batches.where((b) => b.name == name).firstOrNull;
    if (run == null) return StatusLight(tone: PillTone.gray, label: label, value: '아직 실행 기록이 없어요');
    final finished = run.lastFinishedAt ?? run.lastStartedAt;
    final stale = finished != null && DateTime.now().difference(finished) > staleAfter;
    final tone = run.lastStatus == 'FAILED' ? PillTone.red : run.lastStatus == 'RUNNING' ? PillTone.warn : stale ? PillTone.warn : PillTone.success;
    final status = switch (run.lastStatus) { 'FAILED' => '실패', 'RUNNING' => '실행 중', _ => stale ? '마지막 실행이 오래됨' : '성공' };
    final summary = run.lastSummary == null || run.lastSummary!.isEmpty ? '' : ' · ${run.lastSummary}';
    return StatusLight(tone: tone, label: label, value: '$status · ${fmtShort(finished)}$summary');
  }

  static String _sec(Duration? d) => d == null ? '—' : d.inMilliseconds >= 1000 ? '${(d.inMilliseconds / 1000).toStringAsFixed(1)}초' : '${d.inMilliseconds}ms';

  static (String, String) _delta(int today, int yesterday, String unit, {String extra = ''}) {
    final diff = today - yesterday;
    final arrow = diff == 0 ? '' : diff > 0 ? '▲ $diff' : '▼ ${-diff}';
    return (arrow, '어제 $yesterday$unit$extra');
  }

  static Color? _deltaTone(int today, int yesterday) => today == yesterday ? null : today > yesterday ? const Color(0xFF177D43) : AppColors.danger;
}

class _RegionCard extends StatelessWidget {
  const _RegionCard(this.r);
  final RegionStatus r;
  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (r.roundLabel != null && r.roundLabel!.isNotEmpty) r.roundLabel!,
      if (r.applyDeadline != null) '접수 마감 ${_md(r.applyDeadline!)}' else if (r.statusCode == 'APPLYING') '예산 소진 시 마감' else if (r.applyStartDate != null && r.statusCode == 'PREPARING') '${_md(r.applyStartDate!)} 접수 시작',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: r.dataMissing ? AppColors.dangerTint : AppColors.surf, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink9))),
              if (r.syncLocked) ...[const SizedBox(width: 6), const Icon(Icons.lock_rounded, size: 13, color: AppColors.ink4), const Text(' 잠금', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink4))],
            ]),
          ),
          statusPill(r.statusCode),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _stat('가맹점', fmtNum(r.merchantCount), bad: r.merchantCount == 0),
          const SizedBox(width: 16),
          _stat('관광지', '${r.placeCount}', bad: r.placeCount == 0),
        ]),
        const SizedBox(height: 8),
        Text(
          r.dataMissing ? '데이터 미등록${meta.isEmpty ? '' : ' · ${meta.last}'}' : (meta.isEmpty ? '일정 정보 없음' : meta.join(' · ')),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: r.dataMissing ? FontWeight.w600 : FontWeight.w500, color: r.dataMissing ? AppColors.danger : AppColors.ink5, height: 1.4),
        ),
      ]),
    );
  }

  static String _md(String iso) => iso.length >= 10 ? '${int.parse(iso.substring(5, 7))}월 ${int.parse(iso.substring(8, 10))}일' : iso;

  Widget _stat(String label, String value, {required bool bad}) => Text.rich(TextSpan(children: [
        TextSpan(text: '$label ', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink5)),
        TextSpan(text: value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: bad ? AppColors.danger : AppColors.ink9)),
      ]));
}
