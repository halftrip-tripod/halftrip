import 'package:flutter/material.dart';

import '../../mock_ui/widgets/ui.dart';
import '../admin_models.dart';
import '../admin_repository.dart';
import '../widgets/admin_ui.dart';

class RegionsPage extends StatefulWidget {
  const RegionsPage({super.key, required this.repository});
  final AdminRepository repository;

  @override
  State<RegionsPage> createState() => _RegionsPageState();
}

class _RegionsPageState extends State<RegionsPage> {
  static const _pageSize = 20;
  String _filter = 'ALL';
  int _page = 0;
  List<RegionItem>? _all;
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
      final data = await widget.repository.regions();
      if (mounted) {
        setState(() {
          _all = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<RegionItem> get _visible => switch (_filter) {
        'LOCKED' => (_all ?? []).where((r) => r.syncLocked).toList(),
        'ALL' => _all ?? [],
        _ => (_all ?? []).where((r) => r.statusCode == _filter).toList(),
      };

  Future<void> _edit(RegionItem? r) async {
    final saved = await showSideDrawer<bool>(context, width: 640, builder: (_) => _RegionDrawer(region: r, repository: widget.repository));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final all = _all ?? const <RegionItem>[];
    int count(String s) => all.where((r) => r.statusCode == s).length;
    return ListView(padding: const EdgeInsets.fromLTRB(32, 28, 32, 64), children: [
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SegFilter(
              options: [('ALL', '전체 ${all.length}'), ('APPLYING', '접수중 ${count('APPLYING')}'), ('PREPARING', '준비중 ${count('PREPARING')}'), ('CLOSED', '마감 ${count('CLOSED')}'), ('LOCKED', '잠금 ${all.where((r) => r.syncLocked).length}')],
              value: _filter,
              onChanged: (v) => setState(() {
                _filter = v;
                _page = 0;
              }),
            ),
            const Spacer(),
            AdminButton('지역 추가', small: true, icon: Icons.add_rounded, onTap: () => _edit(null)),
          ]),
          const SizedBox(height: 18),
          AsyncBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            child: Builder(builder: (context) {
              final visible = _visible;
              final pageCount = (visible.length + _pageSize - 1) ~/ _pageSize;
              final page = _page.clamp(0, pageCount == 0 ? 0 : pageCount - 1);
              final rows = visible.skip(page * _pageSize).take(_pageSize).toList();
              return Column(children: [
                AdminTable(
                  columns: const [
                    DataColumn(label: Text('지역')),
                    DataColumn(label: Text('상태')),
                    DataColumn(label: Text('접수 기간')),
                    DataColumn(label: Text('여행 기간')),
                    DataColumn(label: Text('가맹점'), numeric: true),
                    DataColumn(label: Text('관광지'), numeric: true),
                    DataColumn(label: Text('동기화')),
                    DataColumn(label: Text('마지막 수정')),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow(
                        onSelectChanged: (_) => _edit(r),
                        cells: [
                          DataCell(cellTwo(r.name, '${r.province} · ${r.roundLabel ?? '차수 미정'}')),
                          DataCell(statusPill(r.statusCode)),
                          DataCell(cellTwo(_applyRange(r), r.settlementDeadlineDays == null ? '정산 기한 미정' : '정산 기한 여행 후 ${r.settlementDeadlineDays}일', strong: false)),
                          DataCell(Text(_range(r.travelPeriodStart, r.travelPeriodEnd), style: kText)),
                          DataCell(cellNum(fmtNum(r.merchantCount), danger: r.merchantCount == 0)),
                          DataCell(cellNum('${r.placeCount}', danger: r.placeCount == 0)),
                          DataCell(r.syncLocked ? const Pill('🔒 잠금', tone: PillTone.warn) : const Pill('자동', tone: PillTone.sky)),
                          DataCell(cellMuted(fmtShort(r.updatedAt))),
                        ],
                      ),
                  ],
                ),
                if (visible.isNotEmpty)
                  Pager(page: page, pageCount: pageCount, total: visible.length, size: _pageSize, unit: '개', onChanged: (v) => setState(() => _page = v)),
              ]);
            }),
          ),
        ]),
      ),
    ]);
  }

  static String _md(String? iso) => iso == null || iso.length < 10 ? '' : '${int.parse(iso.substring(5, 7))}월 ${int.parse(iso.substring(8, 10))}일';

  static String _range(String? a, String? b) {
    if (a == null && b == null) return '—';
    return '${_md(a).isEmpty ? '미정' : _md(a)} ~ ${_md(b).isEmpty ? '미정' : _md(b)}';
  }

  static String _applyRange(RegionItem r) {
    final start = _md(r.applyStartDate), end = _md(r.applyDeadline);
    if (start.isEmpty && end.isEmpty) return r.statusCode == 'PREPARING' ? '일정 미정' : '—';
    if (end.isEmpty) return r.statusCode == 'PREPARING' ? '$start 시작 예정' : '$start ~ 예산 소진 시';
    return '${start.isEmpty ? '' : '$start ~ '}$end';
  }
}

enum _Kind { text, int_, double_, date, url }

class _F {
  const _F(this.key, this.label, this.kind, {this.hint, this.help, this.unit, this.wide = false});
  final String key, label;
  final _Kind kind;
  final String? hint, help, unit;
  final bool wide;
}

const _sections = <(String, List<_F>)>[
  ('기본', [_F('name', '지역명', _Kind.text, hint: '완도'), _F('province', '도·광역시', _Kind.text, hint: '전라남도'), _F('roundLabel', '차수 라벨', _Kind.text, hint: '5차'), _F('displayOrder', '표시 순서', _Kind.int_, help: '작을수록 앞에 보여요')]),
  ('일정', [_F('applyStartDate', '접수 시작', _Kind.date), _F('applyDeadline', '접수 마감', _Kind.date, help: '비우면 "예산 소진 시 마감"'), _F('travelPeriodStart', '여행 시작', _Kind.date), _F('travelPeriodEnd', '여행 종료', _Kind.date), _F('openDate', '오픈 예정일', _Kind.date), _F('settlementDeadlineDays', '정산 기한', _Kind.int_, unit: '여행 후 일수')]),
  ('환급 조건', [_F('refundConditionAmount', '최소 소비 금액', _Kind.int_, unit: '원'), _F('authRequiredCount', '인증 관광지 개소', _Kind.int_), _F('refundRate', '환급률', _Kind.int_, unit: '%'), _F('maxRefundPerPerson', '1인 최대 환급', _Kind.int_, unit: '원'), _F('refundConditionText', '조건 문구', _Kind.text, unit: '앱 화면에 그대로', wide: true), _F('paymentMethods', '결제수단 코드', _Kind.text, hint: 'ZEROPAY,LOCAL_CURRENCY', help: '쉼표로 여러 개', wide: true)]),
  ('링크', [_F('halfPriceApplyUrl', '반값여행 신청 URL', _Kind.url, wide: true), _F('digitalTourCardApplyUrl', '디지털관광주민증 URL', _Kind.url, wide: true), _F('localCurrencyAppUrl', '지역화폐 앱 URL', _Kind.url, hint: '없으면 비워 두세요', wide: true)]),
  ('거주지 제한', [_F('restrictedResidenceTokens', '제한 토큰', _Kind.text, hint: '전라남도,광주', help: '쉼표 구분 · 거주지에 포함되면 신청 불가'), _F('residenceRestrictionNote', '안내 문구', _Kind.text)]),
  ('지도 · 기타', [_F('mapCenterLat', '중심 위도', _Kind.double_), _F('mapCenterLng', '중심 경도', _Kind.double_), _F('mapTopPercent', '지도 top', _Kind.double_, unit: '%'), _F('mapLeftPercent', '지도 left', _Kind.double_, unit: '%'), _F('mockBudgetRemaining', '예산 잔여', _Kind.int_, unit: '표시용'), _F('dataSourceNote', '데이터 출처 메모', _Kind.text)]),
];

class _RegionDrawer extends StatefulWidget {
  const _RegionDrawer({required this.region, required this.repository});
  final RegionItem? region;
  final AdminRepository repository;

  @override
  State<_RegionDrawer> createState() => _RegionDrawerState();
}

class _RegionDrawerState extends State<_RegionDrawer> {
  late final Map<String, dynamic> _body = widget.region?.toSaveBody() ?? RegionItem.emptyBody();
  final Map<String, TextEditingController> _ctl = {};
  late String _status = (_body['statusCode'] as String?) ?? 'PREPARING';
  late bool _locked = _body['syncLocked'] == true;
  late bool _residenceMatch = _body['eligibleForResidenceMatch'] != false;
  late bool _digital = _body['digitalBenefitAvailable'] == true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final (_, fields) in _sections) {
      for (final f in fields) {
        _ctl[f.key] = TextEditingController(text: _body[f.key]?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _collect() {
    for (final (_, fields) in _sections) {
      for (final f in fields) {
        final raw = _ctl[f.key]!.text.trim();
        if (raw.isEmpty) {
          _body[f.key] = null;
          continue;
        }
        switch (f.kind) {
          case _Kind.int_:
            final v = int.tryParse(raw.replaceAll(',', ''));
            if (v == null) return '${f.label}: 숫자만 입력해 주세요.';
            _body[f.key] = v;
          case _Kind.double_:
            final v = double.tryParse(raw);
            if (v == null) return '${f.label}: 숫자만 입력해 주세요.';
            _body[f.key] = v;
          case _Kind.date:
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) || DateTime.tryParse(raw) == null) return '${f.label}: YYYY-MM-DD 형식으로 입력해 주세요.';
            _body[f.key] = raw;
          case _Kind.url:
            if (!raw.startsWith('http')) return '${f.label}: http(s)로 시작해야 해요.';
            _body[f.key] = raw;
          case _Kind.text:
            _body[f.key] = raw;
        }
      }
    }
    _body['statusCode'] = _status;
    _body['syncLocked'] = _locked;
    _body['eligibleForResidenceMatch'] = _residenceMatch;
    _body['digitalBenefitAvailable'] = _digital;
    if ((_body['name'] as String?)?.isEmpty ?? true) return '지역명은 필수예요.';
    if ((_body['province'] as String?)?.isEmpty ?? true) return '도·광역시는 필수예요.';
    return null;
  }

  Future<void> _save() async {
    final err = _collect();
    if (err != null) {
      showAdminToast(context, err, error: true);
      return;
    }
    final isNew = widget.region == null;
    final ok = await showConfirmDialog(
      context,
      title: isNew ? '지역을 추가할까요?' : '${_body['name']} 변경을 저장할까요?',
      message: '저장 즉시 앱 홈·지역 화면에 반영돼요. ${_locked ? '동기화 잠금이 켜져 있어 배치가 이 지역을 덮어쓰지 않아요.' : '동기화 잠금이 꺼져 있으면 다음 배치(08:30 · 18:30)가 상태·차수 일정을 덮어쓸 수 있어요.'}',
      confirmLabel: '저장',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.saveRegion(widget.region?.id, _body);
      if (!mounted) return;
      showAdminToast(context, isNew ? '지역을 추가했어요.' : '${_body['name']} 변경을 저장했어요. 앱에 바로 반영돼요.');
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
    final r = widget.region;
    return DrawerFrame(
      title: r == null ? '지역 추가' : '${r.name} 편집',
      subtitle: r == null ? null : Pill('${r.province} · regionId ${r.id}', tone: PillTone.gray),
      sections: [
        AdminToggle(label: '동기화 잠금', hint: '켜면 VisitKorea 배치(하루 2회)가 상태·차수 일정을 덮어쓰지 않아요', value: _locked, onChanged: (v) => setState(() => _locked = v)),
        DrawerSection('상태', children: [
          RadioRow(options: const [('APPLYING', '접수중'), ('PREPARING', '준비중'), ('CLOSED', '마감')], value: _status, onChanged: (v) => setState(() => _status = v)),
        ]),
        for (final (title, fields) in _sections)
          DrawerSection(title, children: [
            LayoutBuilder(
              builder: (context, c) {
                final half = (c.maxWidth - 14) / 2;
                return Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final f in fields)
                    SizedBox(
                      width: f.wide ? c.maxWidth : half,
                      child: AdminField(
                        label: f.unit == null ? f.label : '${f.label} (${f.unit})',
                        controller: _ctl[f.key]!,
                        hint: f.hint ?? (f.kind == _Kind.date ? 'YYYY-MM-DD' : null),
                        help: f.help,
                        keyboardType: f.kind == _Kind.text || f.kind == _Kind.url ? null : TextInputType.number,
                      ),
                    ),
                ]);
              },
            ),
            if (title == '거주지 제한') AdminToggle(label: '거주지 매칭 적용', hint: '끄면 거주지와 무관하게 모든 사용자에게 보여요', value: _residenceMatch, onChanged: (v) => setState(() => _residenceMatch = v)),
            if (title == '지도 · 기타') AdminToggle(label: '디지털관광주민증 혜택', hint: '지역 상세에 할인처 탭을 보여줘요', value: _digital, onChanged: (v) => setState(() => _digital = v)),
          ]),
        const NoteBox('저장하면 앱 지역 목록에 바로 반영되고 감사 로그에 남아요. 지정관광지·가맹점 데이터 편집은 S2에서 열려요.', icon: Icons.save_outlined),
      ],
      footer: [
        AdminButton('취소', variant: BtnVariant.ghost, onTap: () => Navigator.pop(context)),
        AdminButton(r == null ? '추가' : '저장', loading: _busy, onTap: _save),
      ],
    );
  }
}
