import 'package:flutter/material.dart';

import '../../mock_ui/theme/app_colors.dart';
import '../../mock_ui/widgets/ui.dart';

/// 관리자 콘솔 공통 위젯 — 앱 디자인 시스템(색·그림자·Pill)을 쓰되 데스크톱 가독성 기준을 따로 둔다.
///
/// 타이포 규칙: 페이지 제목 24/800 · 카드 제목 17/800 · 본문 14/500(ink7) · 보조 13(ink5) · 식별자만 ink4.
/// 간격 규칙: 페이지 32 · 카드 24 · 카드 사이 24 · 표 행 52.

// ── 타이포 토큰 ──
const kText = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5);
const kTextStrong = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9, height: 1.4);
const kTextSub = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.4);
const kTextId = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink4, height: 1.4);
const kLabel = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink7);
const kCardTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink9, letterSpacing: -.4);

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.color = Colors.white});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.card),
        child: child,
      );
}

class CardTitle extends StatelessWidget {
  const CardTitle(this.title, {super.key, this.trailing, this.hint});
  final String title;
  final String? hint;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(title, style: kCardTitle),
          if (hint != null) ...[const SizedBox(width: 10), Flexible(child: Text(hint!, overflow: TextOverflow.ellipsis, style: kTextSub))],
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

class LinkText extends StatelessWidget {
  const LinkText(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.p600))),
      );
}

enum BtnVariant { sky, ghost, danger, dangerGhost }

class AdminButton extends StatelessWidget {
  const AdminButton(this.label, {super.key, this.onTap, this.variant = BtnVariant.sky, this.small = false, this.loading = false, this.icon});
  final String label;
  final VoidCallback? onTap;
  final BtnVariant variant;
  final bool small, loading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || loading;
    final (bg, fg, border) = switch (variant) {
      BtnVariant.sky => (AppColors.p500, Colors.white, null),
      BtnVariant.ghost => (Colors.white, AppColors.ink7, AppColors.line),
      BtnVariant.danger => (AppColors.danger, Colors.white, null),
      BtnVariant.dangerGhost => (AppColors.dangerTint, AppColors.danger, null),
    };
    final radius = BorderRadius.circular(small ? 10 : 12);
    return Opacity(
      opacity: disabled ? .5 : 1,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 18, vertical: small ? 8 : 12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: border == null ? null : Border.all(color: border),
              boxShadow: variant == BtnVariant.sky && !disabled ? const [BoxShadow(color: Color(0x470EA5E9), blurRadius: 18, offset: Offset(0, 8))] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (loading) ...[SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: fg)), const SizedBox(width: 8)]
              else if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontSize: small ? 13 : 14, fontWeight: FontWeight.w700, color: fg, height: 1.3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, this.unit, this.delta, this.deltaTone, this.danger = false, this.onTap});
  final String label, value;
  final String? unit;
  /// 아래 줄 — 예: ("▲ 3", "어제 1명"). 첫 요소는 색을 입힌다.
  final (String, String)? delta;
  final Color? deltaTone;
  final bool danger;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.ink9;
    final sub = danger ? AppColors.danger : AppColors.ink5;
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AdminCard(
          color: danger ? AppColors.dangerTint : Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sub)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(value, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: fg, letterSpacing: -1, height: 1.15)),
              if (unit != null) ...[const SizedBox(width: 5), Text(unit!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sub))],
            ]),
            const SizedBox(height: 10),
            if (delta != null)
              Row(children: [
                if (delta!.$1.isNotEmpty) ...[Text(delta!.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: deltaTone ?? sub)), const SizedBox(width: 6)],
                Text(delta!.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub)),
              ]),
          ]),
        ),
      ),
    );
  }
}

/// 상태 신호등 한 줄 — 제목 줄 + 설명 줄. 잘라내지 않고 줄바꿈한다.
class StatusLight extends StatelessWidget {
  const StatusLight({super.key, required this.tone, required this.label, required this.value});
  final PillTone tone; // success | warn | red | gray
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final (color, halo) = switch (tone) {
      PillTone.success => (AppColors.success, AppColors.successTint),
      PillTone.warn => (AppColors.warning, AppColors.warningTint),
      PillTone.red => (AppColors.danger, AppColors.dangerTint),
      _ => (AppColors.gray, AppColors.track),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 5), child: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: halo, spreadRadius: 4)]))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: kTextStrong),
            const SizedBox(height: 2),
            Text(value, style: kTextSub),
          ]),
        ),
      ]),
    );
  }
}

/// 세그먼트 필터 (트랙 위 흰 칩).
class SegFilter extends StatelessWidget {
  const SegFilter({super.key, required this.options, required this.value, required this.onChanged});
  final List<(String, String)> options; // (key, label)
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (k, l) in options)
            InkWell(
              onTap: () => onChanged(k),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: k == value ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: k == value ? AppShadows.soft : null),
                child: Text(l, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: k == value ? AppColors.ink9 : AppColors.ink5)),
              ),
            ),
        ]),
      );
}

InputDecoration _inputDecoration({String? hint, Widget? prefix, bool enabled = true}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.ink4, fontWeight: FontWeight.w500),
      prefixIcon: prefix,
      isDense: true,
      filled: true,
      fillColor: enabled ? Colors.white : AppColors.surf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.p400, width: 1.5)),
    );

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({super.key, required this.controller, required this.hint, required this.onSubmitted, this.width = 300});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink9),
          decoration: _inputDecoration(hint: hint, prefix: const Icon(Icons.search_rounded, size: 19, color: AppColors.ink4)),
        ),
      );
}

/// 폼 입력 — 라벨(13/600) + 필드(15) + 도움말(12.5).
class AdminField extends StatelessWidget {
  const AdminField({super.key, required this.label, required this.controller, this.hint, this.help, this.required = false, this.maxLines = 1, this.keyboardType, this.enabled = true});
  final String label;
  final TextEditingController controller;
  final String? hint, help;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: kLabel),
          if (required) ...[const SizedBox(width: 5), const Text('필수', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger))],
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink9),
          decoration: _inputDecoration(hint: hint, enabled: enabled),
        ),
        if (help != null) ...[const SizedBox(height: 6), Text(help!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.4))],
      ]);
}

/// 가로 라디오 (1일/7일/30일/영구, 접수중/준비중/마감 …).
class RadioRow extends StatelessWidget {
  const RadioRow({super.key, required this.options, required this.value, required this.onChanged});
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(options[i].$1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: options[i].$1 == value ? AppColors.p50 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: options[i].$1 == value ? AppColors.p200 : AppColors.line),
                ),
                child: Text(options[i].$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: options[i].$1 == value ? AppColors.p700 : AppColors.ink5)),
              ),
            ),
          ),
        ],
      ]);
}

class AdminToggle extends StatelessWidget {
  const AdminToggle({super.key, required this.label, this.hint, required this.value, required this.onChanged});
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9)),
              if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: kTextSub)],
            ]),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ]),
      );
}

/// 드로어 섹션 — 제목 + 하단 헤어라인 + 내용.
class DrawerSection extends StatelessWidget {
  const DrawerSection(this.title, {super.key, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink5)),
        ),
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]],
      ]);
}

/// 키-값 목록 — 키(ink5) / 값(ink9 600), 14px.
class KvGrid extends StatelessWidget {
  const KvGrid(this.rows, {super.key, this.keyWidth = 128});
  final List<(String, Widget)> rows;
  final double keyWidth;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: keyWidth, child: Text(rows[i].$1, style: kTextSub)),
              Expanded(child: DefaultTextStyle(style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink9, height: 1.5), child: rows[i].$2)),
            ]),
          ),
      ]);
}

class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key, this.icon = Icons.lock_outline_rounded, this.title});
  final String text;
  final String? title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(color: AppColors.p50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.p100)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: AppColors.p600)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              if (title != null) TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink9)),
              TextSpan(text: text),
            ]), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.5)),
          ),
        ]),
      );
}

/// 인용 박스 — 신고된 본문 미리보기.
class QuoteBox extends StatelessWidget {
  const QuoteBox({super.key, this.title, required this.body, this.meta});
  final String? title, meta;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null && title!.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(title!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9))),
          SelectableText(body, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink7, height: 1.6)),
          if (meta != null && meta!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(meta!, style: kTextSub)),
        ]),
      );
}

/// 페이저 — "1–20 / 1,284  ‹ 1 / 65 ›".
class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.pageCount, required this.total, required this.size, required this.onChanged, this.unit = '건'});
  final int page, pageCount, total, size;
  final String unit;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * size + 1;
    final to = ((page + 1) * size).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('$from–$to / ${fmtNumber(total)}$unit', style: kTextSub),
        const SizedBox(width: 12),
        IconButton(onPressed: page > 0 ? () => onChanged(page - 1) : null, icon: const Icon(Icons.chevron_left_rounded, size: 22), visualDensity: VisualDensity.compact),
        Text('${page + 1} / ${pageCount.clamp(1, 1 << 30)}', style: kTextStrong),
        IconButton(onPressed: page + 1 < pageCount ? () => onChanged(page + 1) : null, icon: const Icon(Icons.chevron_right_rounded, size: 22), visualDensity: VisualDensity.compact),
      ]),
    );
  }
}

String fmtNumber(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// 데스크톱 표 — 행 52 · 헤더 13/600 ink5 · 본문 14. 가로로 넘치면 표 안에서만 스크롤.
class AdminTable extends StatelessWidget {
  const AdminTable({super.key, required this.columns, required this.rows, this.emptyText = '표시할 항목이 없어요.'});
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyText;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 44), child: Center(child: Text(emptyText, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink5))));
    }
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: c.maxWidth),
          child: DataTableTheme(
            data: DataTableThemeData(
              headingRowHeight: 40,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              columnSpacing: 22,
              horizontalMargin: 14,
              dividerThickness: 1,
              headingTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink5),
              dataTextStyle: kText,
              dataRowColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.p50 : s.contains(WidgetState.hovered) ? AppColors.surf : null),
            ),
            child: DataTable(columns: columns, rows: rows, showCheckboxColumn: false),
          ),
        ),
      ),
    );
  }
}

// ── 셀 헬퍼 ──
Text cellId(Object? v) => Text('$v', style: kTextId);
Text cellBold(String v) => Text(v, style: kTextStrong);
Text cellMuted(String v) => Text(v, style: kTextSub);
Widget cellNum(String v, {bool danger = false}) => Align(alignment: Alignment.centerRight, child: Text(v, style: TextStyle(fontSize: 14, fontWeight: danger ? FontWeight.w700 : FontWeight.w500, color: danger ? AppColors.danger : AppColors.ink7, fontFeatures: const [FontFeature.tabularFigures()])));
Widget cellEllipsis(String v, {double width = 340}) => SizedBox(width: width, child: Text(v, overflow: TextOverflow.ellipsis, maxLines: 1, style: kText));

/// 두 줄 셀 — 굵은 첫 줄 + 작은 보조 줄.
Widget cellTwo(String main, String sub, {bool strong = true, Color? mainColor}) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(main, style: strong ? kTextStrong.copyWith(color: mainColor) : kText.copyWith(color: mainColor)),
      Text(sub, style: kTextSub.copyWith(fontSize: 12.5)),
    ]);

Pill statusPill(String code) => switch (code) {
      'APPLYING' => const Pill('접수중', tone: PillTone.success),
      'CLOSED' => const Pill('마감', tone: PillTone.gray),
      _ => const Pill('준비중', tone: PillTone.warn),
    };

/// 우측 드로어 — 표 행 클릭 상세·편집. 결과는 pop 값으로 돌려준다.
Future<T?> showSideDrawer<T>(BuildContext context, {required Widget Function(BuildContext) builder, double width = 520}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: AppColors.ink9.withValues(alpha: .35),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (c, a, b) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(width: width, height: double.infinity, child: Material(color: Colors.white, elevation: 24, child: builder(c))),
    ),
    transitionBuilder: (c, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// 드로어 뼈대 — 헤더(제목 20) / 스크롤 본문(섹션 간 24) / 하단 버튼.
class DrawerFrame extends StatelessWidget {
  const DrawerFrame({super.key, required this.title, this.leading, this.subtitle, required this.sections, required this.footer});
  final String title;
  final Widget? leading, subtitle;
  final List<Widget> sections;
  final List<Widget> footer;
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 22, 18, 20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink9, letterSpacing: -.4))),
            if (subtitle != null) ...[const SizedBox(width: 10), subtitle!],
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.ink4)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(28, 24, 28, 28), children: [
            for (var i = 0; i < sections.length; i++) ...[if (i > 0) const SizedBox(height: 24), sections[i]],
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
          child: Row(children: [
            for (var i = 0; i < footer.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: footer[i])],
          ]),
        ),
      ]);
}

void showAdminToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), backgroundColor: error ? AppColors.danger : AppColors.ink9, width: 460, behavior: SnackBarBehavior.floating));
}

/// 로딩·오류·내용 3상태 — 페이지마다 반복되는 뼈대.
class AsyncBody extends StatelessWidget {
  const AsyncBody({super.key, required this.loading, required this.error, required this.onRetry, required this.child});
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(64), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.ink4, size: 36),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center, style: kText),
            const SizedBox(height: 16),
            AdminButton('다시 시도', onTap: onRetry, variant: BtnVariant.ghost, small: true),
          ]),
        ),
      );
    }
    return child;
  }
}
