import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../data/residence_options.dart';
import '../theme/app_colors.dart';

/// 소셜 가입 직후 거주지 입력 온보딩.
/// 디자인: halftrip-design/residence.html
class ResidenceScreen extends StatefulWidget {
  const ResidenceScreen({super.key});

  @override
  State<ResidenceScreen> createState() => _ResidenceScreenState();
}

class _ResidenceScreenState extends State<ResidenceScreen> {
  String? _province;
  String? _city;

  bool get _canSubmit => _province != null && _city != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('거주지 설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          // 온보딩 건너뛰기 — 기존(가입 시) 거주지를 유지하고 메인으로 진입.
          onPressed: () {
            final controller = AppScope.of(context);
            controller.completeResidenceSetup(
              controller.currentUser?.residence ?? '',
            );
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 22,
                      height: 1.3,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: AppColors.ink9,
                    ),
                    children: [
                      TextSpan(text: '어디에\n'),
                      TextSpan(
                        text: '살고 계신가요?',
                        style: TextStyle(color: AppColors.p600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '반값여행은 거주지와 같은·인접한 지역은 대상에서 제외돼요.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink5,
                  ),
                ),
                const SizedBox(height: 18),
                _PickField(
                  label: '시 / 도',
                  value: _province,
                  hintText: '시 / 도를 선택하세요',
                  onTap: () => _pickProvince(context),
                ),
                const SizedBox(height: 14),
                _PickField(
                  label: '시 / 군 / 구',
                  value: _city,
                  hintText: _province == null
                      ? '시 / 도를 먼저 선택하세요'
                      : '시 / 군 / 구를 선택하세요',
                  onTap: _province == null ? null : () => _pickCity(context),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.ink4),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '거주지는 마이페이지에서 언제든 바꿀 수 있어요.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        child: FilledButton(
          onPressed: _canSubmit
              ? () => AppScope.of(context)
                  .completeResidenceSetup('$_province $_city')
              : null,
          child: const Text('시작하기'),
        ),
      ),
    );
  }

  Future<void> _pickProvince(BuildContext context) async {
    final picked = await _showPicker(
      context,
      title: '시 / 도',
      options: residenceOptions.keys.toList(),
      selected: _province,
    );
    if (picked != null) {
      setState(() {
        _province = picked;
        _city = null;
      });
    }
  }

  Future<void> _pickCity(BuildContext context) async {
    final cities = residenceOptions[_province] ?? const <String>[];
    final picked = await _showPicker(
      context,
      title: '시 / 군 / 구',
      options: cities,
      selected: _city,
    );
    if (picked != null) {
      setState(() => _city = picked);
    }
  }

  Future<String?> _showPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String? selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                itemCount: options.length,
                itemBuilder: (_, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  return ListTile(
                    title: Text(
                      option,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.p600 : AppColors.ink9,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.p600)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickField extends StatelessWidget {
  const _PickField({
    required this.label,
    required this.value,
    required this.hintText,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String hintText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink7,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasValue ? value! : hintText,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight:
                            hasValue ? FontWeight.w600 : FontWeight.w500,
                        color: hasValue ? AppColors.ink9 : AppColors.ink4,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.ink4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
