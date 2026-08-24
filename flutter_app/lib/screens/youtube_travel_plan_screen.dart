import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../theme/app_colors.dart';
import '../features/youtube_travel_plan/google_sheets_export_service.dart';
import '../features/youtube_travel_plan/travel_plan_edit_sheet.dart';
import '../features/youtube_travel_plan/travel_plan_models.dart';
import '../features/youtube_travel_plan/travel_plan_store.dart';
import '../mock_ui/widgets/trip_calendar_sheet.dart';
import '../models/app_models.dart';
import '../widgets/place_map_view.dart';

class YoutubeTravelPlanScreen extends StatefulWidget {
  const YoutubeTravelPlanScreen({
    super.key,
    required this.job,
    this.tripDetail,
    this.onDocumentSaved,
  });

  final YoutubeCourseJobItem job;
  final TripDetail? tripDetail;
  final Future<void> Function(TravelPlanDocument document)? onDocumentSaved;

  @override
  State<YoutubeTravelPlanScreen> createState() =>
      _YoutubeTravelPlanScreenState();
}

class _YoutubeTravelPlanScreenState extends State<YoutubeTravelPlanScreen> {
  TravelPlanStore? _store;
  Object? _loadError;
  bool _exporting = false;
  late final GoogleSheetsExportService _sheetsService;

  @override
  void initState() {
    super.initState();
    final config = AppConfig.fromEnvironment();
    _sheetsService = GoogleSheetsExportService(
      oauthClientId: config.googleOAuthClientId,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final store = await TravelPlanStore.load(
        job: widget.job,
        tripDetail: widget.tripDetail,
        onSaved: widget.onDocumentSaved,
      );
      if (!mounted) {
        store.dispose();
        return;
      }
      setState(() => _store = store);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 52,
        title: const Text(
          '여행 계획표',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (store != null)
            IconButton(
              tooltip: '직접 저장',
              onPressed: store.saveNow,
              // 문서 저장 글리프 — 숙박확인서 'PDF 저장'과 동일한 다운로드 아이콘.
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: switch ((store, _loadError)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (null, final error?) => _ErrorView(
          message: '여행 계획표를 불러오지 못했습니다.\n$error',
          onRetry: () {
            setState(() => _loadError = null);
            _load();
          },
        ),
        (final loaded?, _) => AnimatedBuilder(
          animation: loaded,
          builder:
              (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1000) {
                    return _buildDesktop(context, loaded);
                  }
                  return _buildMobile(context, loaded);
                },
              ),
        ),
      },
    );
  }

  Widget _buildDesktop(BuildContext context, TravelPlanStore store) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _PlanHeader(
            store: store,
            onEdit: () => _editHeader(store),
            onExport: () => _showExportDialog(store),
          ),
          const SizedBox(height: 14),
          _PlanToolbar(store: store),
          if (store.conflicts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ConflictBanner(conflicts: store.conflicts),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _SectionTitle(
                          title: '여행 계획표',
                          subtitle:
                              '${store.visibleItems.length}개 일정 · 셀 또는 행을 눌러 편집',
                          trailing: FilledButton.tonalIcon(
                            onPressed: store.addItem,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('행 추가'),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _DesktopScheduleTable(
                            store: store,
                            onEdit: _editItem,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: _MapPanel(store: store, height: double.infinity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, TravelPlanStore store) {
    final items = store.visibleItems;
    return Column(
      children: [
        _MobilePlannerHeader(
          store: store,
          onEditHeader: () => _editHeader(store),
          onExport: () => _showExportDialog(store),
        ),
        if (store.conflicts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ConflictBanner(conflicts: store.conflicts),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: _MobileSpreadsheet(
            items: items,
            selectedItemId: store.selectedItemId,
            onSelect: (item) {
              store.selectItem(item.id);
              _editItem(item);
            },
            onAdd: store.addItem,
          ),
        ),
        _MobileBottomToolbar(
          store: store,
          onFilter: () => _showFilterSheet(store),
          onSort: () => _showSortSheet(store),
          onMore: () => _showMoreSheet(store),
        ),
      ],
    );
  }

  Future<void> _showFilterSheet(TravelPlanStore store) async {
    final selected = await showModalBottomSheet<TravelPlanFilter>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                const _SheetMenuTitle(title: '일정 필터'),
                RadioGroup<TravelPlanFilter>(
                  groupValue: store.filter,
                  onChanged: (selection) {
                    if (selection != null) Navigator.pop(context, selection);
                  },
                  child: Column(
                    children: [
                      for (final value in TravelPlanFilter.values)
                        RadioListTile<TravelPlanFilter>(
                          value: value,
                          title: Text(value.label),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
    if (selected != null) store.setFilter(selected);
  }

  Future<void> _showSortSheet(TravelPlanStore store) async {
    final selected = await showModalBottomSheet<TravelPlanSort>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                const _SheetMenuTitle(title: '일정 정렬'),
                RadioGroup<TravelPlanSort>(
                  groupValue: store.sort,
                  onChanged: (selection) {
                    if (selection != null) Navigator.pop(context, selection);
                  },
                  child: Column(
                    children: [
                      for (final value in TravelPlanSort.values)
                        RadioListTile<TravelPlanSort>(
                          value: value,
                          title: Text(value.label),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
    if (selected != null) store.setSort(selected);
  }

  Future<void> _showMoreSheet(TravelPlanStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetMenuTitle(title: '더보기'),
                  ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: const Text('지도에서 일정 보기'),
                    subtitle: const Text('입력된 좌표를 일정 순서대로 표시합니다.'),
                    onTap: () {
                      Navigator.pop(context);
                      _showMobileMap(store);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded),
                    title: const Text('여행 정보 수정'),
                    onTap: () {
                      Navigator.pop(context);
                      _editHeader(store);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showMobileMap(TravelPlanStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      // 시트 드래그가 지도 팬 제스처를 가로채 모달이 따라 움직이던 문제 —
      // 시트 드래그를 끄고(지도 드래그 = 지도 이동) 닫기는 X 버튼으로.
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: _SheetMenuTitle(title: '일정 지도')),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            size: 22, color: AppColors.ink5),
                      ),
                    ]),
                    Expanded(child: _MapPanel(store: store, height: 680)),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _editItem(TravelPlanItem item) async {
    final updated = await showTravelPlanItemEditor(
      context,
      item,
      onDelete: () => _store?.deleteItem(item.id),
    );
    if (updated != null && mounted) {
      _store?.updateItem(updated);
    }
  }

  Future<void> _editHeader(TravelPlanStore store) async {
    final document = store.document;
    final titleController = TextEditingController(text: document.title);
    final cityController = TextEditingController(text: document.city);
    final startDateController = TextEditingController(
      text: document.startDate ?? '',
    );
    final endDateController = TextEditingController(
      text: document.endDate ?? '',
    );
    final participantController = TextEditingController(
      text: document.participantCount?.toString() ?? '',
    );

    final result = await showDialog<_HeaderEditResult>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
            title: Row(children: [
              const Expanded(
                child: Text('여행 정보 수정',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink9)),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded,
                    size: 22, color: AppColors.ink5),
              ),
            ]),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Theme(
                  data: travelPlanFormTheme(dialogContext),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    travelPlanLabeledField('여행 제목', TextField(
                      controller: titleController,
                      decoration: const InputDecoration(),
                    )),
                    const SizedBox(height: 12),
                    travelPlanLabeledField('여행 도시', TextField(
                      controller: cityController,
                      decoration: const InputDecoration(),
                    )),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          // 날짜는 직접 타이핑 대신 캘린더로 — 숙박확인서와 동일 UX.
                          child: travelPlanLabeledField('시작일', TextField(
                            controller: startDateController,
                            readOnly: true,
                            onTap: () => _pickPlanDateRange(dialogContext,
                                startDateController, endDateController),
                            decoration: const InputDecoration(
                              hintText: '날짜 선택',
                              suffixIcon: Icon(Icons.calendar_month_rounded,
                                  size: 18),
                            ),
                          )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: travelPlanLabeledField('종료일', TextField(
                            controller: endDateController,
                            readOnly: true,
                            onTap: () => _pickPlanDateRange(dialogContext,
                                startDateController, endDateController),
                            decoration: const InputDecoration(
                              hintText: '날짜 선택',
                              suffixIcon: Icon(Icons.calendar_month_rounded,
                                  size: 18),
                            ),
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    travelPlanLabeledField('참여 인원', TextField(
                      controller: participantController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        
                        suffixText: '명',
                      ),
                    )),
                    const SizedBox(height: 10),
                    Row(children: const [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: AppColors.p500),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('확인되지 않은 날짜와 인원은 빈칸으로 두세요.',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink5)),
                      ),
                    ]),
                  ],
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    _HeaderEditResult(
                      title: titleController.text.trim(),
                      city: cityController.text.trim(),
                      startDate: startDateController.text.trim(),
                      endDate: endDateController.text.trim(),
                      participantCount: participantController.text.trim(),
                    ),
                  );
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );

    titleController.dispose();
    cityController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    participantController.dispose();

    if (result == null || !mounted) return;
    final participantCount = int.tryParse(result.participantCount);
    store.updateHeader(
      title: result.title.isEmpty ? document.title : result.title,
      city: result.city,
      startDate: result.startDate.isEmpty ? null : result.startDate,
      endDate: result.endDate.isEmpty ? null : result.endDate,
      participantCount:
          participantCount != null && participantCount > 0
              ? participantCount
              : null,
    );
  }

  /// 시작일·종료일을 우리 범위 캘린더(여행 추가와 동일)로 한 번에 고른다.
  Future<void> _pickPlanDateRange(
    BuildContext context,
    TextEditingController start,
    TextEditingController end,
  ) async {
    final s = DateTime.tryParse(start.text.trim());
    final e = DateTime.tryParse(end.text.trim());
    final today = DateTime.now();
    final selected = await showTripCalendarSheet(
      context,
      initial: (s != null && e != null && !e.isBefore(s))
          ? DateTimeRange(start: s, end: e)
          : null,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 2, 12, 31),
    );
    if (selected == null) return;
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    start.text = fmt(selected.start);
    end.text = fmt(selected.end);
    start.selection = const TextSelection.collapsed(offset: 0);
    end.selection = const TextSelection.collapsed(offset: 0);
  }

  Future<void> _showExportDialog(TravelPlanStore store) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (routeContext) => StatefulBuilder(
              builder: (context, setRouteState) {
                final document = store.document;
                return Scaffold(
                  backgroundColor: AppColors.bg,
                  appBar: AppBar(
                    backgroundColor: AppColors.bg,
                    surfaceTintColor: Colors.transparent,
                    title: const Text(
                      'Google 스프레드시트 내보내기',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                        children: [
                          const _ExportIntroCard(),
                          const SizedBox(height: 22),
                          const _ExportSectionLabel(
                            title: '내보내기 미리보기',
                            subtitle: '상위 4개 행',
                          ),
                          const SizedBox(height: 10),
                          _ExportPreviewTable(
                            items:
                                ([...document.items]..sort(
                                  (a, b) => a.order.compareTo(b.order),
                                )).take(4).toList(),
                          ),
                          const SizedBox(height: 24),
                          const _ExportSectionLabel(title: '내보내기 옵션'),
                          const SizedBox(height: 10),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x0F1B3A5B),
                                    blurRadius: 14,
                                    offset: Offset(0, 4)),
                              ],
                            ),
                            child: const Column(
                              children: [
                                ListTile(
                                  leading: Icon(
                                    Icons.radio_button_checked_rounded,
                                    color: _plannerPurple,
                                  ),
                                  title: Text(
                                    '새 시트 생성',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text('새 Google 스프레드시트를 만듭니다.'),
                                ),
                                Divider(height: 1),
                                ListTile(
                                  enabled: false,
                                  leading: Icon(
                                    Icons.radio_button_unchecked_rounded,
                                  ),
                                  title: Text('기존 시트 덮어쓰기'),
                                  subtitle: Text('현재 버전에서는 지원하지 않습니다.'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _ExportSectionLabel(title: '파일 이름'),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: document.title,
                            readOnly: true,
                            decoration: const InputDecoration(
                              suffixText: '.xlsx',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          if (document.lastExportedAt != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              '마지막 내보내기: '
                              '${DateFormat('yyyy.MM.dd HH:mm').format(document.lastExportedAt!)}',
                              style: const TextStyle(
                                color: _plannerMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (document.spreadsheetUrl != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed:
                                    () => _openSpreadsheet(
                                      document.spreadsheetUrl!,
                                    ),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('마지막 스프레드시트 열기'),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 54,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _plannerPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed:
                                  _exporting
                                      ? null
                                      : () async {
                                        setRouteState(() => _exporting = true);
                                        try {
                                          final result = await _sheetsService
                                              .export(store.document);
                                          await store.markExported(
                                            spreadsheetId: result.spreadsheetId,
                                            spreadsheetUrl:
                                                result.spreadsheetUrl,
                                          );
                                          if (!mounted) return;
                                          await _openSpreadsheet(
                                            result.spreadsheetUrl,
                                          );
                                          if (routeContext.mounted) {
                                            Navigator.pop(routeContext);
                                          }
                                        } catch (error) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              this.context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '내보내기에 실패했습니다.\n$error',
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          _exporting = false;
                                          if (routeContext.mounted) {
                                            setRouteState(() {});
                                          }
                                        }
                                      },
                              icon: const Icon(
                                Icons.table_view_rounded,
                                color: Color(0xFF5DD18A),
                              ),
                              label: Text(
                                _exporting
                                    ? '내보내는 중...'
                                    : 'Google Sheets로 내보내기',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if (_exporting) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(
                              color: _plannerPurple,
                            ),
                          ],
                          const SizedBox(height: 12),
                          const _ExportNotice(),
                          if (_sheetsService.isConnected)
                            TextButton(
                              onPressed:
                                  _exporting
                                      ? null
                                      : () async {
                                        await _sheetsService.disconnect();
                                        setRouteState(() {});
                                      },
                              child: const Text('Google 계정 연결 해제'),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  Future<void> _openSpreadsheet(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('스프레드시트를 열지 못했습니다.')));
      }
    }
  }
}

// 계획표 강조색 — 디자인 시스템 하늘색(p500)으로 통일 (기존 보라 폐기, 8/14 규희).
const _plannerPurple = Color(0xFF0EA5E9);
const _plannerPurpleSoft = Color(0xFFF0F9FF);
const _plannerGrid = Color(0xFFE5E7EB);
const _plannerMuted = Color(0xFF667085);

class _MobilePlannerHeader extends StatelessWidget {
  const _MobilePlannerHeader({
    required this.store,
    required this.onEditHeader,
    required this.onExport,
  });

  final TravelPlanStore store;
  final VoidCallback onEditHeader;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final document = store.document;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0F1B3A5B),
                    blurRadius: 14,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: _plannerPurple,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      document.city.isEmpty ? '여행 도시 미정' : document.city,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.group_outlined,
                    size: 14,
                    color: _plannerPurple,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    document.participantCount == null
                        ? '인원 미정'
                        : '${document.participantCount}명',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.smart_display_outlined,
                    size: 14,
                    color: _plannerPurple,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '분석 장소 ${document.items.length}곳',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEditHeader,
                  style: FilledButton.styleFrom(
                    backgroundColor: _plannerPurpleSoft,
                    foregroundColor: const Color(0xFF0369A1),
                    elevation: 0,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(
                    document.startDate == null && document.endDate == null
                        ? '빈칸과 여행 정보 입력'
                        : _dateRange(document),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: onExport,
                style: FilledButton.styleFrom(
                  backgroundColor: _plannerPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 15),
                label: const Text('시트 내보내기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileSpreadsheet extends StatelessWidget {
  const _MobileSpreadsheet({
    required this.items,
    required this.selectedItemId,
    required this.onSelect,
    required this.onAdd,
  });

  final List<TravelPlanItem> items;
  final String? selectedItemId;
  final ValueChanged<TravelPlanItem> onSelect;
  final VoidCallback onAdd;

  static const _widths = <double>[
    34,
    46,
    80,
    60,
    60,
    118,
    72,
    104,
    86,
    94,
    124,
  ];
  static const _headers = <String>[
    '',
    'No',
    '날짜',
    '시작',
    '종료',
    '장소명',
    '유형',
    '먹은 음식',
    '메뉴 가격',
    '식당 가격대',
    '메모',
  ];

  @override
  Widget build(BuildContext context) {
    final rowCount = items.length < 10 ? 10 : items.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: _plannerGrid)),
      ),
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: const _PlannerScrollBehavior(),
            child: Scrollbar(
              thumbVisibility: true,
              notificationPredicate: (notification) => notification.depth == 0,
              child: SingleChildScrollView(
                key: const ValueKey('travel-plan-horizontal-scroll'),
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: _widths.fold<double>(0, (sum, width) => sum + width),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rowCount + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildLetterRow();
                      if (index == 1) return _buildHeaderRow();
                      final itemIndex = index - 2;
                      final item =
                          itemIndex < items.length ? items[itemIndex] : null;
                      return _buildDataRow(context, itemIndex, item);
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'youtube-plan-add-row',
              onPressed: onAdd,
              backgroundColor: _plannerPurple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterRow() {
    return Row(
      children: [
        for (var index = 0; index < _widths.length; index++)
          _GridCell(
            width: _widths[index],
            height: 28,
            text: index == 0 ? '' : String.fromCharCode(64 + index),
            background: const Color(0xFFF6F7F9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        for (var index = 0; index < _headers.length; index++)
          _GridCell(
            width: _widths[index],
            height: 38,
            text: _headers[index],
            background: index == 0 ? const Color(0xFFF6F7F9) : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
      ],
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    int rowIndex,
    TravelPlanItem? item,
  ) {
    final selected = item?.id == selectedItemId;
    final values =
        item == null
            ? List<String>.filled(_headers.length - 1, '')
            : <String>[
              '${item.order}',
              item.date ?? '',
              item.startTime ?? '',
              item.endTime ?? '',
              item.placeName,
              item.category.label,
              item.foodName ?? '',
              _menuPrice(item),
              _restaurantPrice(item),
              item.memo,
            ];
    return InkWell(
      key: item == null ? null : ValueKey('travel-plan-row-${item.id}'),
      onTap: item == null ? null : () => onSelect(item),
      child: Row(
        children: [
          _GridCell(
            width: _widths.first,
            height: 46,
            text: '${rowIndex + 1}',
            background: selected ? _plannerPurpleSoft : const Color(0xFFF6F7F9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          for (var index = 0; index < values.length; index++)
            _GridCell(
              width: _widths[index + 1],
              height: 46,
              text: values[index],
              background: selected ? _plannerPurpleSoft : Colors.white,
              selected: selected,
              fontSize: 10,
              fontWeight:
                  index == 0 || index == 4 ? FontWeight.w700 : FontWeight.w500,
            ),
        ],
      ),
    );
  }

  String _menuPrice(TravelPlanItem item) {
    final amount = item.menuPriceAmount;
    if (amount == null) return '';
    final currency = item.menuPriceCurrency?.trim();
    return currency == null || currency.isEmpty
        ? '$amount'
        : '$amount $currency';
  }

  String _restaurantPrice(TravelPlanItem item) {
    final min = item.restaurantPriceMin;
    final max = item.restaurantPriceMax;
    final currency = item.restaurantPriceCurrency?.trim();
    final parts = <String>[
      if (min != null) NumberFormat('#,##0').format(min),
      if (max != null) NumberFormat('#,##0').format(max),
    ];
    if (parts.isNotEmpty) {
      final range = parts.join('~');
      return currency == null || currency.isEmpty ? range : '$range $currency';
    }
    return priceLevelLabel(item.restaurantPriceLevel);
  }
}

class _PlannerScrollBehavior extends MaterialScrollBehavior {
  const _PlannerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.width,
    required this.height,
    required this.text,
    required this.background,
    required this.fontSize,
    required this.fontWeight,
    this.selected = false,
  });

  final double width;
  final double height;
  final String text;
  final Color background;
  final double fontSize;
  final FontWeight fontWeight;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(
            color: selected ? const Color(0xFF38BDF8) : _plannerGrid,
            width: selected ? 1.2 : 1,
          ),
          bottom: BorderSide(
            color: selected ? const Color(0xFF38BDF8) : _plannerGrid,
            width: selected ? 1.2 : 1,
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: text.isEmpty ? _plannerMuted : const Color(0xFF171A22),
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.15,
        ),
      ),
    );
  }
}

class _MobileBottomToolbar extends StatelessWidget {
  const _MobileBottomToolbar({
    required this.store,
    required this.onFilter,
    required this.onSort,
    required this.onMore,
  });

  final TravelPlanStore store;
  final VoidCallback onFilter;
  final VoidCallback onSort;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 18,
                offset: Offset(0, -4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomTool(
                icon: Icons.undo_rounded,
                label: '되돌리기',
                onTap: store.canUndo ? store.undo : null,
              ),
              _BottomTool(
                icon: Icons.redo_rounded,
                label: '다시 실행',
                onTap: store.canRedo ? store.redo : null,
              ),
              _BottomTool(
                icon: Icons.filter_alt_outlined,
                label: store.filter == TravelPlanFilter.all ? '필터' : '필터 적용',
                active: store.filter != TravelPlanFilter.all,
                onTap: onFilter,
              ),
              _BottomTool(
                icon: Icons.swap_vert_rounded,
                label: '정렬',
                active: store.sort != TravelPlanSort.custom,
                onTap: onSort,
              ),
              _BottomTool(
                icon: Icons.more_horiz_rounded,
                label: '더보기',
                onTap: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTool extends StatelessWidget {
  const _BottomTool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color =
        onTap == null
            ? const Color(0xFFCBD5E1)
            : active
            ? const Color(0xFF0284C7)
            : const Color(0xFF64748B);
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: active ? _plannerPurpleSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetMenuTitle extends StatelessWidget {
  const _SheetMenuTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A)),
      ),
    );
  }
}

class _ExportIntroCard extends StatelessWidget {
  const _ExportIntroCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _plannerGrid),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF20B96B),
                borderRadius: BorderRadius.all(Radius.circular(7)),
              ),
              child: SizedBox(
                width: 38,
                height: 46,
                child: Icon(
                  Icons.table_chart_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Google 스프레드시트로 내보내면\n언제 어디서나 계획표를 편집할 수 있어요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSectionLabel extends StatelessWidget {
  const _ExportSectionLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: title,
        style: const TextStyle(
          color: Color(0xFF171A22),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        children: [
          if (subtitle != null)
            TextSpan(
              text: '  ($subtitle)',
              style: const TextStyle(
                color: _plannerMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExportPreviewTable extends StatelessWidget {
  const _ExportPreviewTable({required this.items});

  final List<TravelPlanItem> items;

  static const _widths = <double>[42, 48, 84, 62, 62, 128];

  @override
  Widget build(BuildContext context) {
    final rowCount = items.length < 4 ? 4 : items.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _plannerGrid),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _widths.fold<double>(0, (sum, width) => sum + width),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(
                  const ['', 'A', 'B', 'C', 'D', 'E'],
                  background: const Color(0xFFF6F7F9),
                  height: 30,
                ),
                _row(
                  const ['', 'No', '날짜', '시작', '종료', '장소명'],
                  background: Colors.white,
                  bold: true,
                  height: 38,
                ),
                for (var index = 0; index < rowCount; index++)
                  _dataRow(index, index < items.length ? items[index] : null),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataRow(int index, TravelPlanItem? item) {
    return _row(
      [
        '${index + 1}',
        item == null ? '' : '${item.order}',
        item?.date ?? '',
        item?.startTime ?? '',
        item?.endTime ?? '',
        item?.placeName ?? '',
      ],
      background: Colors.white,
      height: 42,
    );
  }

  Widget _row(
    List<String> values, {
    required Color background,
    required double height,
    bool bold = false,
  }) {
    return Row(
      children: [
        for (var index = 0; index < values.length; index++)
          Container(
            width: _widths[index],
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: index == 0 ? const Color(0xFFF6F7F9) : background,
              border: const Border(
                right: BorderSide(color: _plannerGrid),
                bottom: BorderSide(color: _plannerGrid),
              ),
            ),
            child: Text(
              values[index],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExportNotice extends StatelessWidget {
  const _ExportNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text(
        '날짜나 시간이 비어 있는 셀은 내보내기 시에도 빈칸으로 유지됩니다.',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
            height: 1.4,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.store,
    required this.onEdit,
    required this.onExport,
  });

  final TravelPlanStore store;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final document = store.document;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextFormField(
                    initialValue: document.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      labelText: '여행 제목',
                      border: InputBorder.none,
                    ),
                    onFieldSubmitted:
                        (value) => store.updateHeader(title: value.trim()),
                  ),
                ),
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: document.city.isEmpty ? '여행 도시 미정' : document.city,
                ),
                _InfoChip(
                  icon: Icons.date_range_outlined,
                  label: _dateRange(document),
                ),
                _InfoChip(
                  icon: Icons.group_outlined,
                  label:
                      document.participantCount == null
                          ? '인원 미정'
                          : '${document.participantCount}명',
                ),
                _SaveStatusChip(status: store.saveStatus),
                IconButton.filledTonal(
                  onPressed: onEdit,
                  tooltip: '여행 정보 수정',
                  icon: const Icon(Icons.edit_outlined),
                ),
                FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.table_view_rounded, size: 18),
                  label: const Text('Google Sheets로 내보내기'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '영상에서 확인되지 않은 날짜·시간·음식·메뉴 가격은 빈칸으로 유지됩니다.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanToolbar extends StatelessWidget {
  const _PlanToolbar({required this.store});

  final TravelPlanStore store;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: travelPlanLabeledField('필터', DropdownButtonFormField<TravelPlanFilter>(
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: Colors.white,
                initialValue: store.filter,
                decoration: const InputDecoration(
                  
                  isDense: true,
                ),
                items: [
                  for (final value in TravelPlanFilter.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) store.setFilter(value);
                },
              )),
            ),
            SizedBox(
              width: 200,
              child: travelPlanLabeledField('정렬', DropdownButtonFormField<TravelPlanSort>(
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: Colors.white,
                initialValue: store.sort,
                decoration: const InputDecoration(
                  
                  isDense: true,
                ),
                items: [
                  for (final value in TravelPlanSort.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) store.setSort(value);
                },
              )),
            ),
            IconButton.filledTonal(
              tooltip: '실행 취소',
              onPressed: store.canUndo ? store.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton.filledTonal(
              tooltip: '다시 실행',
              onPressed: store.canRedo ? store.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopScheduleTable extends StatelessWidget {
  const _DesktopScheduleTable({required this.store, required this.onEdit});

  final TravelPlanStore store;
  final ValueChanged<TravelPlanItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final items = store.visibleItems;
    if (items.isEmpty) return const _EmptySchedule();
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 48,
            dataRowMinHeight: 58,
            dataRowMaxHeight: 76,
            columns: const [
              DataColumn(label: Text('순서')),
              DataColumn(label: Text('날짜/시간')),
              DataColumn(label: Text('장소')),
              DataColumn(label: Text('유형')),
              DataColumn(label: Text('할 일')),
              DataColumn(label: Text('음식')),
              DataColumn(label: Text('식당 가격대')),
              DataColumn(label: Text('이동')),
              DataColumn(label: Text('예약')),
              DataColumn(label: Text('상태')),
              DataColumn(label: Text('작업')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  selected: store.selectedItemId == item.id,
                  onSelectChanged: (_) {
                    store.selectItem(item.id);
                    onEdit(item);
                  },
                  cells: [
                    DataCell(Text('${item.order}')),
                    DataCell(
                      Text(
                        '${item.date ?? '날짜 미정'}\n'
                        '${item.startTime ?? '--:--'} ~ ${item.endTime ?? '--:--'}',
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          '${item.placeName}\n${item.address ?? ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(item.category.label)),
                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Text(
                          item.activity.isEmpty ? '-' : item.activity,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      _StatusText(
                        value: item.foodName ?? '미확인',
                        status: item.foodVerificationStatus.label,
                      ),
                    ),
                    DataCell(
                      Text(
                        priceLevelLabel(item.restaurantPriceLevel).isEmpty
                            ? '-'
                            : priceLevelLabel(item.restaurantPriceLevel),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.transportType == null
                            ? '-'
                            : '${item.transportType!.label} '
                                '${item.transportMinutes ?? ''}',
                      ),
                    ),
                    DataCell(Text(item.reservationStatus.label)),
                    DataCell(
                      Icon(
                        item.completed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color:
                            item.completed
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            tooltip: '위로',
                            onPressed: () => store.moveItem(item.id, -1),
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          ),
                          IconButton(
                            tooltip: '아래로',
                            onPressed: () => store.moveItem(item.id, 1),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                          IconButton(
                            tooltip: '복사',
                            onPressed: () => store.duplicateItem(item.id),
                            icon: const Icon(Icons.copy_outlined),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            onPressed: () => store.deleteItem(item.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.store, required this.height});

  final TravelPlanStore store;
  final double height;

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.fromEnvironment();
    final items = [...store.document.items]
      ..sort((a, b) => a.order.compareTo(b.order));
    final mappedItems =
        items
            .where(
              (item) =>
                  item.latitude != null &&
                  item.longitude != null &&
                  item.verificationStatus !=
                      TravelPlanVerificationStatus.excluded,
            )
            .toList();
    final markers = [
      for (final item in mappedItems)
        PlaceMapMarkerData(
          id: item.order,
          name: item.placeName,
          address: item.address ?? '',
          latitude: item.latitude!,
          longitude: item.longitude!,
          selected: true,
          regionLabel: item.category.label,
        ),
    ];
    final route = [
      for (final item in mappedItems)
        PlaceMapRoutePoint(
          id: item.order,
          latitude: item.latitude!,
          longitude: item.longitude!,
        ),
    ];
    final selected =
        items.where((item) => item.id == store.selectedItemId).firstOrNull;
    final map = PlaceMapView(
      markers: markers,
      emptyMessage: '좌표가 있는 일정이 없습니다.',
      kakaoEnabled: config.canUseKakaoMap,
      routeMarkers: route,
      connectSequentially: true,
      highlightedMarkerId: selected?.order,
      onMarkerTap: (markerId) {
        final item =
            items.where((entry) => entry.order == markerId).firstOrNull;
        if (item != null) store.selectItem(item.id);
      },
      initialCenterLatitude:
          mappedItems.isEmpty ? null : mappedItems.first.latitude,
      initialCenterLongitude:
          mappedItems.isEmpty ? null : mappedItems.first.longitude,
      height: height.isFinite ? height : 680,
    );
    if (!height.isFinite) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.all(8), child: map),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(8), child: map),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.conflicts});

  final List<TravelPlanConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                conflicts.map((item) => item.message).join('\n'),
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 17), label: Text(label));
  }
}

class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({required this.status});

  final TravelPlanSaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      TravelPlanSaveStatus.idle => (Icons.cloud_outlined, '저장 대기'),
      TravelPlanSaveStatus.saving => (Icons.sync_rounded, '저장 중'),
      TravelPlanSaveStatus.saved => (Icons.cloud_done_outlined, '자동 저장됨'),
      TravelPlanSaveStatus.failed => (Icons.cloud_off_outlined, '저장 실패'),
    };
    return Chip(avatar: Icon(icon, size: 17), label: Text(label));
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.value, required this.status});

  final String value;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value),
        Text(status, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '현재 조건에 맞는 일정이 없습니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

String _dateRange(TravelPlanDocument document) {
  if (document.startDate == null && document.endDate == null) return '날짜 미정';
  if (document.startDate == document.endDate) return document.startDate!;
  return '${document.startDate ?? '미정'} ~ ${document.endDate ?? '미정'}';
}

class _HeaderEditResult {
  const _HeaderEditResult({
    required this.title,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.participantCount,
  });

  final String title;
  final String city;
  final String startDate;
  final String endDate;
  final String participantCount;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
