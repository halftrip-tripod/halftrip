import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// 체크박스 정본 — 실화면·목업 공용이라 디자인 시스템(lib/widgets/ui/)에 둔다.
export '../../widgets/ui/app_checkbox.dart';

/// 한국어 안내문을 어절 단위로 줄바꿈시킨다 — "기준이에/요"처럼 어절 중간에서
/// 끊기지 않게, 어절 안 음절 사이에 WORD JOINER(U+2060)를 끼운다. (CSS word-break:
/// keep-all에 해당하는 Flutter 대응)
String keepWords(String text) =>
    text.split(' ').map((w) => w.split('').join('\u2060')).join(' ');

/// 흰 카드 (라운드 24 · 테두리 없음 · card 그림자).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color = Colors.white,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

enum PillTone { sky, gray, red, mint, yt, gold, live, warn, success }

/// 상태 배지 (pill).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = PillTone.sky, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.sky => (AppColors.p100, AppColors.p700),
      PillTone.gray => (AppColors.track, AppColors.ink5),
      PillTone.red => (AppColors.dangerTint, AppColors.danger),
      PillTone.mint => (AppColors.mintTint, AppColors.mintDeep),
      PillTone.yt => (AppColors.coralTint, const Color(0xFFE0322B)),
      PillTone.gold => (const Color(0xFFFBF1D5), const Color(0xFFA9790C)),
      PillTone.live => (const Color(0xFFE7F7EE), const Color(0xFF1B8E4B)),
      PillTone.warn => (AppColors.warningTint, const Color(0xFFB8731B)),
      PillTone.success => (AppColors.successTint, const Color(0xFF177D43)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

/// 세그먼트 필터 (트랙 배경 위 흰 칩).
class SegChips extends StatelessWidget {
  const SegChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: i == selected
                        ? const [BoxShadow(color: Color(0x140F172A), blurRadius: 10, offset: Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                        color: i == selected ? AppColors.ink9 : AppColors.ink5,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 가로 스크롤 카테고리 칩.
class CatChips extends StatelessWidget {
  const CatChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == selected ? AppColors.p500 : Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: i == selected
                  ? const [BoxShadow(color: Color(0x400EA5E9), blurRadius: 10, offset: Offset(0, 4))]
                  : AppShadows.soft,
            ),
            child: Text(labels[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: i == selected ? Colors.white : AppColors.ink5,
                )),
          ),
        ),
      ),
    );
  }
}

/// 진행률 게이지 (라벨 + 트랙).
class ProgressGauge extends StatelessWidget {
  const ProgressGauge({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    this.green = false,
  });

  final String label;
  final String value;
  final double progress;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink7)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink9)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.track,
            color: green ? AppColors.success : AppColors.p500,
          ),
        ),
      ],
    );
  }
}

/// 섹션 타이틀 (18 / w900).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -.5)),
      if (trailing != null) ...[const Spacer(), trailing!],
    ]);
  }
}

/// ℹ️ 안내 문구 행.
class NoteRow extends StatelessWidget {
  const NoteRow(this.text, {super.key, this.icon = Icons.info_outline_rounded});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: AppColors.p600),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink5, height: 1.5)),
      ),
    ]);
  }
}

/// 하단 고정 CTA 바 (그라데이션 페이드).
class CtaBar extends StatelessWidget {
  const CtaBar({super.key, required this.children, this.note});
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) {
    // DetailScaffold가 이 바를 Stack+Align으로 화면 맨 아래에 얹기 때문에
    // 시스템 내비게이션 바(3버튼 모드는 특히 두껍다) 아래로 깔려 버튼이 가려진다.
    // 제스처 내비 기기에선 고정 여백 26이 우연히 가려 줘서 기종마다 증상이 갈렸다.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 26, 20, 26 + bottomInset),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00F7FAFD), AppColors.bg],
          stops: [0, .4],
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (note != null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.p500),
            const SizedBox(width: 6),
            Flexible(
              child: Text(note!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink5)),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        Row(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            children[i],
          ],
        ]),
      ]),
    );
  }
}

/// 메인 CTA 버튼.
///
/// [loading]이면 탭을 막고 스피너를 보여 준다 — 저장·등록처럼 서버를 기다리는 동작에서
/// 연타로 같은 요청이 여러 번 나가는 걸 막는다. 라벨은 호출부가 '저장 중…'처럼 바꿔 준다.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label,
      {super.key, this.onTap, this.icon, this.disabled = false, this.loading = false});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool disabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: disabled || loading ? null : onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: disabled ? AppColors.track : AppColors.p500,
            borderRadius: BorderRadius.circular(18),
            boxShadow: disabled
                ? null
                : const [BoxShadow(color: Color(0x470EA5E9), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              ),
              const SizedBox(width: 9),
            ] else if (icon != null) ...[
              Icon(icon, size: 19, color: disabled ? AppColors.ink4 : Colors.white),
              const SizedBox(width: 7),
            ],
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: disabled ? AppColors.ink4 : Colors.white,
                )),
          ]),
        ),
      ),
    );
  }
}

/// 시트용 세컨더리 버튼 — 흰 시트 위에서도 보이게 테두리 + 중앙 정렬. Row 안에서 Expanded.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surf,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line, width: 1.5),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink7)),
        ),
      ),
    );
  }
}

/// 고스트 버튼 (흰 배경 · soft 그림자).
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, this.label, this.icon, this.onTap, this.active = false});
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: EdgeInsets.symmetric(horizontal: label != null ? 18 : 17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.soft,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null)
            Icon(icon, size: 22, color: active ? AppColors.warning : (label != null ? AppColors.p600 : AppColors.ink5)),
          if (icon != null && label != null) const SizedBox(width: 7),
          if (label != null)
            Text(label!,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink7)),
        ]),
      ),
    );
  }
}

/// 카드 내부 아웃라인 버튼 (surf 배경).
class OutlineButton extends StatelessWidget {
  const OutlineButton(this.label, {super.key, this.icon, this.trailingIcon, this.onTap});
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.p600),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink7)),
          if (trailingIcon != null) ...[
            const SizedBox(width: 6),
            Icon(trailingIcon, size: 15, color: AppColors.ink4),
          ],
        ]),
      ),
    );
  }
}

/// surf 배경 리스트 행 (아이콘/이모지 + 제목 + 부제 + 우측).
class SurfRow extends StatelessWidget {
  const SurfRow({
    super.key,
    this.emoji,
    this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.tinted = false,
  });

  final String? emoji;
  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool tinted; // p50 배경 강조

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tinted ? AppColors.p50 : AppColors.surf,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              boxShadow: AppShadows.soft,
            ),
            child: emoji != null
                ? Text(emoji!, style: const TextStyle(fontSize: 18))
                : Icon(icon, size: 20, color: AppColors.p600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink9)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.ink5)),
            ]),
          ),
          trailing ??
              Icon(Icons.chevron_right_rounded,
                  color: tinted ? AppColors.p600 : AppColors.ink4),
        ]),
      ),
    );
  }
}

/// 메뉴 그룹 (mypage 스타일 흰 카드).
class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Column(children: children),
    );
  }
}

class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.ink9;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.ink5),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
          ),
          if (value != null)
            Text(value!,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink5)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink4),
          ],
        ]),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.ink5),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink9)),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

/// 이모지 사각 썸네일.
class EmojiBox extends StatelessWidget {
  const EmojiBox(this.emoji,
      {super.key, this.size = 44, this.fontSize = 22, this.color = AppColors.p50, this.radius = 14});
  final String emoji;
  final double size;
  final double fontSize;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
      child: Text(emoji, style: TextStyle(fontSize: fontSize)),
    );
  }
}

/// 커뮤니티 글 사진 한 장.
///
/// 세 가지 형태를 다 받는다 — 초기 시드가 이모지였고, 번들 이미지가 그다음,
/// 지금은 서버(Supabase)에 올린 URL이 들어온다. 셋을 호출부마다 분기하면
/// 화면별로 어긋나서 여기 한 곳에 모았다.
class PostPhoto extends StatelessWidget {
  const PostPhoto(this.source,
      {super.key,
      this.width,
      this.height = 74,
      this.aspectRatio,
      this.radius = 18,
      this.fontSize = 30,
      this.color = AppColors.surf});
  final String source;

  /// null이면 부모 폭을 채운다(Expanded 안에서 쓰는 경우).
  final double? width;
  final double height;

  /// 지정하면 폭에 맞춰 이 비율로 그린다(목록·상세 모두 1:1로 맞출 때).
  /// width·height보다 우선한다.
  final double? aspectRatio;
  final double radius;
  final double fontSize;
  final Color color;

  bool get _isNetwork => source.startsWith('http://') || source.startsWith('https://');

  Widget _placeholder(String text) => Container(
        width: aspectRatio != null ? double.infinity : (width ?? height),
        height: aspectRatio != null ? double.infinity : height,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
        child: Text(text, style: TextStyle(fontSize: fontSize)),
      );

  Widget _fit(Widget child) =>
      aspectRatio == null ? child : AspectRatio(aspectRatio: aspectRatio!, child: child);

  @override
  Widget build(BuildContext context) {
    if (!_isNetwork && !source.startsWith('assets/')) {
      return _fit(_placeholder(source));
    }
    final double w = aspectRatio != null ? double.infinity : (width ?? double.infinity);
    final double h = aspectRatio != null ? double.infinity : height;
    final Widget image = _isNetwork
        ? Image.network(source,
            width: w,
            height: h,
            fit: BoxFit.cover,
            // 네트워크가 느리거나 끊겨도 글 자체는 읽히게 둔다.
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _placeholder(''),
            errorBuilder: (context, error, stack) => _placeholder('📷'))
        : Image.asset(source, width: w, height: h, fit: BoxFit.cover);
    return _fit(ClipRRect(borderRadius: BorderRadius.circular(radius), child: image));
  }
}

/// 사진 전체화면 뷰어 — 커뮤니티 글 상세에서 사진을 탭하면 열린다.
///
/// 여러 장이면 좌우로 넘기고, 핀치로 확대할 수 있다. 배경 아무 데나 탭하면 닫힌다.
void openPhotoViewer(BuildContext context, List<String> photos, int initialIndex) {
  final shown = [
    for (final p in photos)
      if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('assets/')) p,
  ];
  if (shown.isEmpty) return;
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black87,
    pageBuilder: (_, __, ___) =>
        _PhotoViewer(photos: shown, initialIndex: initialIndex.clamp(0, shown.length - 1)),
  ));
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});
  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _image(String source) => source.startsWith('assets/')
      ? Image.asset(source, fit: BoxFit.contain)
      : Image.network(source,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70),
                  ),
                ),
          errorBuilder: (context, error, stack) => const Center(
                child: Text('📷', style: TextStyle(fontSize: 44)),
              ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // 사진 바깥을 탭하면 닫는다. 확대 제스처와 겹치지 않게 뒤에 깔아 둔다.
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(child: _image(widget.photos[i])),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < widget.photos.length; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index ? Colors.white : Colors.white38,
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// D-day 칩 (ok/warn).
class DdayChip extends StatelessWidget {
  const DdayChip(this.label, {super.key, this.warn = false});
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: warn ? AppColors.dangerTint : AppColors.p100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule_rounded, size: 14, color: warn ? AppColors.danger : AppColors.p700),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: warn ? AppColors.danger : AppColors.p700)),
      ]),
    );
  }
}

/// 환급 조건 충족/경고 배너 (fitbanner).
class FitBanner extends StatelessWidget {
  const FitBanner({super.key, required this.title, required this.subtitle, this.warn = false});
  final String title;
  final String subtitle;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final accent = warn ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: warn ? const Color(0xFFFFF6E9) : AppColors.successTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
          child: Icon(warn ? Icons.error_outline_rounded : Icons.check_rounded,
              size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: warn ? const Color(0xFF9A6800) : const Color(0xFF177D43))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: warn ? const Color(0xFFB8862B) : const Color(0xFF2E9B5F))),
          ]),
        ),
      ]),
    );
  }
}

/// 코스 동선 지도 플레이스홀더 (핀 번호 + DAY 범례).
class CourseMapCard extends StatelessWidget {
  const CourseMapCard({super.key, this.day1 = 4, this.day2 = 3, this.showLegend = true});
  final int day1;
  final int day2;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    // 핀 좌표 (0~1 상대 좌표, course-sim.html 기반)
    const pts = [
      Offset(.23, .32), Offset(.44, .23), Offset(.68, .41), Offset(.8, .70),
      Offset(.59, .81), Offset(.35, .77), Offset(.18, .60),
    ];
    final total = (day1 + day2).clamp(0, pts.length);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 340 / 196,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: _CourseMapPainter(pts.sublist(0, total), day1),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (showLegend)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legendDot(AppColors.p500, 'DAY 1'),
              const SizedBox(width: 16),
              _legendDot(AppColors.p400, 'DAY 2'),
            ]),
          ),
      ]),
    );
  }

  Widget _legendDot(Color c, String label) => Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink5)),
      ]);
}

class _CourseMapPainter extends CustomPainter {
  _CourseMapPainter(this.points, this.day1Count);
  final List<Offset> points;
  final int day1Count;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEDF4FA);
    canvas.drawRect(Offset.zero & size, bg);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * .17, size.height * .86), width: size.width * .5, height: size.height * .47),
        Paint()..color = const Color(0xFFD9E9F6));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * .85, size.height * .2), width: size.width * .4, height: size.height * .43),
        Paint()..color = const Color(0xFFE4EFE3));

    Offset at(int i) => Offset(points[i].dx * size.width, points[i].dy * size.height);

    void drawRoute(int from, int to, Color color) {
      final p = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(at(from).dx, at(from).dy);
      for (var i = from + 1; i <= to; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(path, p);
    }

    final d1End = (day1Count - 1).clamp(0, points.length - 1);
    if (d1End > 0) drawRoute(0, d1End, AppColors.p500);
    if (points.length - 1 > d1End) {
      // 숙박 연결 점선
      final dash = Paint()
        ..color = const Color(0xFF9DB4C8)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final a = at(d1End), b = at(d1End + 1);
      const seg = 8.0;
      final dist = (b - a).distance;
      final dir = (b - a) / dist;
      for (double t = 0; t < dist; t += seg) {
        canvas.drawCircle(a + dir * t, 1.3, dash);
      }
      drawRoute(d1End + 1, points.length - 1, AppColors.p400);
    }

    for (var i = 0; i < points.length; i++) {
      final c = i <= d1End ? AppColors.p500 : AppColors.p400;
      canvas.drawCircle(at(i), 14, Paint()..color = Colors.white);
      canvas.drawCircle(at(i), 12, Paint()..color = c);
      final tp = TextPainter(
        text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
                fontFamily: 'Pretendard', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at(i) - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CourseMapPainter old) =>
      old.points != points || old.day1Count != day1Count;
}

/// 목업 스낵바.
/// 환급 조건 원문의 첫 구절이 그 지역의 인증 요건이다.
/// 지역마다 방식이 달라("관광지 2곳 방문" / "지정관광지 1곳" / "전통시장 소비")
/// 화면에 "지정관광지 2곳 인증"으로 고정해두면 절반은 틀린 안내가 된다.
///   "관광지 1곳 방문 + 개인5만/팀10만 이상 · 청년 70%" → "관광지 1곳 방문"
String? refundProofRequirement(String? conditionText) {
  final text = (conditionText ?? '').trim();
  if (text.isEmpty) return null;
  var head = text.split('·').first.split('+').first.trim();
  head = head.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(); // 괄호 부연은 뺀다
  return head.isEmpty ? null : head;
}

void showMock(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 완료 안내 토스트 — 삭제·저장처럼 끝난 동작을 한 줄로 알린다. showMock과 같은 스낵바지만
/// 이름으로 의도를 드러낸다(목업 안내가 아니라 실제 결과).
void showToast(BuildContext context, String message) => showMock(context, message);

/// 디자인 시스템 다이얼로그 껍데기 — 라운드 22 흰 카드, 제목 + 본문 + 버튼 한 줄.
Widget _appDialogFrame({
  required String title,
  required Widget body,
  required List<Widget> buttons,
}) {
  return Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.ink9, letterSpacing: -0.4)),
        const SizedBox(height: 10),
        body,
        const SizedBox(height: 18),
        Row(children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            buttons[i],
          ],
        ]),
      ]),
    ),
  );
}

/// 확인 다이얼로그 — "정말 삭제할까요?" 류. true면 진행.
/// [danger]면 확인 버튼을 빨간 계열로 그려 되돌릴 수 없는 동작임을 알린다.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (c) => _appDialogFrame(
      title: title,
      body: message == null
          ? const SizedBox.shrink()
          : Text(message,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink5, height: 1.5)),
      buttons: [
        SecondaryButton(cancelLabel, onTap: () => Navigator.pop(c, false)),
        if (danger)
          _DangerButton(confirmLabel, onTap: () => Navigator.pop(c, true))
        else
          PrimaryButton(confirmLabel, onTap: () => Navigator.pop(c, true)),
      ],
    ),
  );
  return result ?? false;
}

/// 한 줄 입력 다이얼로그 — 코스 이름 바꾸기 등. 비우거나 취소하면 null.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String hint = '',
  String confirmLabel = '저장',
}) async {
  final ctl = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (c) => _appDialogFrame(
      title: title,
      body: TextField(
        controller: ctl,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(c, v.trim()),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink9),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.ink4),
          filled: true,
          fillColor: AppColors.surf,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      buttons: [
        SecondaryButton('취소', onTap: () => Navigator.pop(c)),
        PrimaryButton(confirmLabel, onTap: () => Navigator.pop(c, ctl.text.trim())),
      ],
    ),
  );
  ctl.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
}

/// 위험 동작 확인 버튼 — PrimaryButton과 같은 크기, 색만 코랄.
class _DangerButton extends StatelessWidget {
  const _DangerButton(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.coralDeep,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    );
  }
}

/// 공통 바텀시트 래퍼 (라운드 28 · 그랩바).
Future<T?> showAppSheet<T>(BuildContext context, {required Widget child, bool scrollable = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (scrollable) Flexible(child: child) else child,
        ]),
      ),
    ),
  );
}

/// 옵션 리스트 선택 시트.
Future<String?> pickOption(BuildContext context,
    {required String title, required List<String> options}) {
  return showAppSheet<String>(
    context,
    scrollable: true,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink9)),
        ),
      ),
      Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (c, i) => ListTile(
            title: Text(options[i],
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink9)),
            onTap: () => Navigator.of(c).pop(options[i]),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ]),
  );
}

/// 상단 뒤로가기 앱바가 있는 상세 스캐폴드.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.children,
    this.cta,
    this.actions,
    this.closeIcon = false,
    this.padding = const EdgeInsets.fromLTRB(14, 4, 14, 120),
  });

  final String title;
  final List<Widget> children;
  final Widget? cta;
  final List<Widget>? actions;
  final bool closeIcon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(closeIcon ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: Stack(children: [
        ListView(padding: padding, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ]),
        if (cta != null) Align(alignment: Alignment.bottomCenter, child: cta!),
      ]),
    );
  }
}
