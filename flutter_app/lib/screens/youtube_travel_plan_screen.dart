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
    this.job,
    this.course,
    this.tripDetail,
    this.onDocumentSaved,
  }) : assert(job != null || course != null, 'job 또는 course 중 하나는 필요');

  /// 유튜브 분석 결과에서 열 때.
  final YoutubeCourseJobItem? job;

  /// 코스함 코스에서 열 때 (직접·AI·유튜브 공통) — job 없이 코스 스톱으로 계획표 생성.
  final SavedCourse? course;
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

  /// 내보내기 방식 — true면 마지막에 만든 시트를 덮어쓴다(기본은 새 시트 생성).
  bool _exportOverwrite = false;
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
      final store = widget.job != null
          ? await TravelPlanStore.load(
              job: widget.job!,
              tripDetail: widget.tripDetail,
              onSaved: widget.onDocumentSaved,
            )
          : await TravelPlanStore.loadForCourse(
              widget.course!,
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
            TextButton(
              onPressed: store.saveNow,
              child: const Text('저장',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.p600)),
            ),
          const SizedBox(width: 4),
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
          // 더보기에 남은 항목이 지도뿐이라 버튼을 '지도'로 바꾸고 바로 연다.
          onMore: () => _showMobileMap(store),
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

  /// 덮어쓰기 확인 — 구글 시트에서 직접 고친 내용은 이 계획표 값으로 대체된다.
  Future<bool> _confirmOverwrite(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기존 시트를 덮어쓸까요?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
          '마지막에 내보낸 스프레드시트의 내용이 지금 계획표로 바뀌어요.\n'
          '시트에서 직접 고친 내용이 있으면 사라집니다.',
          style: TextStyle(fontSize: 13.5, height: 1.5, color: _plannerMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _plannerPurple),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('덮어쓰기'),
          ),
        ],
      ),
    );
    return ok ?? false;
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
                          _ExportOptionCard(
                            overwrite: _exportOverwrite,
                            // 이전에 내보낸 시트가 있어야 덮어쓸 대상이 생긴다.
                            lastSpreadsheetId: document.spreadsheetId,
                            onChanged: (value) =>
                                setRouteState(() => _exportOverwrite = value),
                          ),
                          const SizedBox(height: 20),
                          const _ExportSectionLabel(title: '파일 이름'),
                          const SizedBox(height: 8),
                          _ExportFileNameField(title: document.title),
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
                                        final reuseId =
                                            store.document.spreadsheetId;
                                        final overwrite = _exportOverwrite &&
                                            reuseId != null &&
                                            reuseId.isNotEmpty;
                                        // 시트에서 손으로 고친 내용이 지워질 수 있어 먼저 확인받는다.
                                        if (overwrite &&
                                            !await _confirmOverwrite(
                                                routeContext)) {
                                          return;
                                        }
                                        setRouteState(() => _exporting = true);
                                        try {
                                          final result = await _sheetsService
                                              .export(store.document,
                                                  targetSpreadsheetId:
                                                      overwrite ? reuseId : null);
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
                  Icon(
                    // 유튜브 분석 문서만 영상 아이콘 — 코스에서 연 계획표는 장소 아이콘.
                    document.youtubeUrl.isNotEmpty
                        ? Icons.smart_display_outlined
                        : Icons.place_outlined,
                    size: 14,
                    color: _plannerPurple,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${document.youtubeUrl.isNotEmpty ? '분석 장소' : '장소'} ${document.items.length}곳',
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
                    // 날짜를 채우면 버튼 라벨이 여행 기간으로 바뀐다.
                    document.startDate == null && document.endDate == null
                        ? '여행 정보 입력'
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

  static final _dayMemo = RegExp(r'^DAY\s*\d+$');

  /// 항목이 속한 그룹 라벨 — 날짜가 있으면 날짜, 없으면 "DAY n" 메모(코스에서 온 골격).
  static String? _groupOf(TravelPlanItem item) {
    final date = item.date;
    if (date != null && date.isNotEmpty) return date;
    final memo = item.memo.trim();
    if (_dayMemo.hasMatch(memo)) return memo;
    return null;
  }

  /// DAY 그룹행으로 승격된 메모는 셀에서 비운다(중복 방지).
  static String _memoOf(TravelPlanItem item) =>
      _dayMemo.hasMatch(item.memo.trim()) ? '' : item.memo;

  @override
  Widget build(BuildContext context) {
    final columns = <_PlanColumn>[
      _PlanColumn('No', 40, (i) => '${i.order}',
          color: _plannerPurple, weight: FontWeight.w900),
      _PlanColumn('날짜', 78, (i) => i.date ?? ''),
      _PlanColumn('시작', 56, (i) => i.startTime ?? ''),
      _PlanColumn('종료', 56, (i) => i.endTime ?? ''),
      _PlanColumn('장소명', 132, (i) => i.placeName,
          weight: FontWeight.w800, align: TextAlign.left),
      _PlanColumn('유형', 62, (i) => i.category.label, categoryTint: true),
      _PlanColumn('먹은 음식', 112, (i) => i.foodName ?? ''),
      _PlanColumn('메뉴 가격', 88, _menuPrice),
      _PlanColumn('식당 가격대', 96, _restaurantPrice),
      _PlanColumn('메모', 140, _memoOf, align: TextAlign.left),
    ];
    final tableWidth =
        columns.fold<double>(0, (sum, c) => sum + c.width);

    // 현재 표시 순서 기준으로 날짜/DAY가 바뀌는 지점에 그룹 구분행 삽입.
    final rows = <Widget>[];
    String? lastGroup;
    for (final item in items) {
      final group = _groupOf(item);
      if (group != null && group != lastGroup) {
        rows.add(_buildGroupRow(group, tableWidth));
        lastGroup = group;
      }
      rows.add(_buildDataRow(context, item, columns));
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: const _PlannerScrollBehavior(),
            child: Scrollbar(
              thumbVisibility: true,
              notificationPredicate: (notification) => notification.depth == 0,
              // 헤더 행은 세로 스크롤 밖(Column 첫 칸)에 둬서 고정한다 —
              // 아래로 내려도 지금 보는 값이 어느 항목인지 알 수 있게.
              // 가로 스크롤은 헤더와 본문이 같이 움직여야 칸이 어긋나지 않는다.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  key: const ValueKey('travel-plan-horizontal-scroll'),
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: tableWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderRow(columns),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 76),
                            children: rows,
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildHeaderRow(List<_PlanColumn> columns) {
    return Row(
      children: [
        for (final column in columns)
          Container(
            width: column.width,
            height: 40,
            alignment: column.align == TextAlign.left
                ? Alignment.centerLeft
                : Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5FE),
              border: Border(
                  bottom: BorderSide(color: Color(0xFFD3EBFB))),
            ),
            child: Text(column.header,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0369A1))),
          ),
      ],
    );
  }

  Widget _buildGroupRow(String label, double width) {
    return Container(
      width: width,
      height: 30,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: .2)),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    TravelPlanItem item,
    List<_PlanColumn> columns,
  ) {
    final selected = item.id == selectedItemId;
    return InkWell(
      key: ValueKey('travel-plan-row-${item.id}'),
      onTap: () => onSelect(item),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? _plannerPurpleSoft : Colors.white,
          border: Border(
            bottom: const BorderSide(color: Color(0xFFEEF2F7)),
            left: selected
                ? const BorderSide(color: _plannerPurple, width: 2.4)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            for (final column in columns)
              Container(
                width: column.width,
                height: 50,
                alignment: column.align == TextAlign.left
                    ? Alignment.centerLeft
                    : Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  column.valueOf(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: column.align,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: column.weight,
                    color: column.colorFor(item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _menuPrice(TravelPlanItem item) {
    final amount = item.menuPriceAmount;
    if (amount == null) return '';
    final currency = item.menuPriceCurrency?.trim();
    return currency == null || currency.isEmpty
        ? '$amount'
        : '$amount $currency';
  }

  static String _restaurantPrice(TravelPlanItem item) {
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

/// 계획표 컬럼 정의 — 헤더·너비·값·정렬·강조.
class _PlanColumn {
  const _PlanColumn(
    this.header,
    this.width,
    this.valueOf, {
    this.weight = FontWeight.w500,
    this.color,
    this.align = TextAlign.center,
    this.categoryTint = false,
  });

  final String header;
  final double width;
  final String Function(TravelPlanItem) valueOf;
  final FontWeight weight;
  final Color? color;
  final TextAlign align;

  /// 유형 컬럼 — 맛집·카페는 주황, 나머지는 하늘색 텍스트.
  final bool categoryTint;

  Color colorFor(TravelPlanItem item) {
    if (categoryTint) {
      final isFood = item.category == TravelCategory.food ||
          item.category == TravelCategory.cafe;
      return isFood ? const Color(0xFFB8731B) : const Color(0xFF0369A1);
    }
    if (valueOf(item).isEmpty) return _plannerMuted;
    return color ?? const Color(0xFF171A22);
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
                icon: Icons.map_outlined,
                label: '지도',
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

/// 내보내기 방식 선택 — 머티리얼 ListTile 기본 룩 대신 앱 카드 톤(흰 카드·라운드·
/// 하늘 선택 표시)으로. 지금은 '새 시트 생성'만 지원한다.
class _ExportOptionCard extends StatelessWidget {
  const _ExportOptionCard({
    required this.overwrite,
    required this.lastSpreadsheetId,
    required this.onChanged,
  });

  final bool overwrite;

  /// 마지막으로 내보낸 시트 id — 없으면 덮어쓸 대상이 없어 선택할 수 없다.
  final String? lastSpreadsheetId;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final canOverwrite = (lastSpreadsheetId ?? '').isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B3A5B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        _ExportOptionRow(
          icon: Icons.add_circle_outline_rounded,
          title: '새 시트 생성',
          description: '새 Google 스프레드시트를 만들어요',
          selected: !overwrite || !canOverwrite,
          onTap: () => onChanged(false),
        ),
        const SizedBox(height: 8),
        _ExportOptionRow(
          icon: Icons.upload_file_rounded,
          title: '기존 시트 덮어쓰기',
          description: canOverwrite
              ? '마지막에 내보낸 시트를 최신 내용으로 갱신해요'
              : '먼저 한 번 내보내면 선택할 수 있어요',
          selected: overwrite && canOverwrite,
          onTap: canOverwrite ? () => onChanged(true) : null,
          badge: canOverwrite ? null : '내보내기 기록 없음',
        ),
      ]),
    );
  }
}

class _ExportOptionRow extends StatelessWidget {
  const _ExportOptionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;

  /// null이면 고를 수 없는 옵션(회색 처리).
  final VoidCallback? onTap;

  /// 왜 못 고르는지 알리는 회색 배지.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? _plannerPurpleSoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? _plannerPurple : _plannerGrid,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _plannerPurple : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon,
              size: 19, color: selected ? Colors.white : const Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: disabled ? const Color(0xFF94A3B8) : const Color(0xFF171A22))),
              if (badge != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w800, color: _plannerMuted)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(description,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: disabled ? const Color(0xFFB3BDCC) : _plannerMuted)),
          ]),
        ),
        if (selected)
          const Icon(Icons.check_circle_rounded, size: 20, color: _plannerPurple),
      ]),
      ),
    );
  }
}

/// 내보낼 파일 이름 — 계획표 제목을 따라간다(읽기 전용).
/// 머티리얼 기본 입력 필드가 앱 톤과 겉돌아, 카드형 표시로 바꿨다.
class _ExportFileNameField extends StatelessWidget {
  const _ExportFileNameField({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _plannerGrid),
        ),
        child: Row(children: [
          const Icon(Icons.description_outlined, size: 18, color: _plannerMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF171A22))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _plannerPurpleSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('.xlsx',
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0369A1))),
          ),
        ]),
      ),
      const SizedBox(height: 7),
      const Text('계획표 제목을 바꾸면 파일 이름도 함께 바뀌어요.',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _plannerMuted)),
    ]);
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
