import 'package:flutter/material.dart';

import 'travel_plan_models.dart';

Future<TravelPlanItem?> showTravelPlanItemEditor(
  BuildContext context,
  TravelPlanItem item, {
  VoidCallback? onDelete,
}) {
  final compact = MediaQuery.sizeOf(context).width < 700;
  if (compact) {
    return showModalBottomSheet<TravelPlanItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => _TravelPlanItemEditor(
            item: item,
            compact: true,
            onDelete: onDelete,
          ),
    );
  }
  return showDialog<TravelPlanItem>(
    context: context,
    builder:
        (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
            child: _TravelPlanItemEditor(
              item: item,
              compact: false,
              onDelete: onDelete,
            ),
          ),
        ),
  );
}

class _TravelPlanItemEditor extends StatefulWidget {
  const _TravelPlanItemEditor({
    required this.item,
    required this.compact,
    required this.onDelete,
  });

  final TravelPlanItem item;
  final bool compact;
  final VoidCallback? onDelete;

  @override
  State<_TravelPlanItemEditor> createState() => _TravelPlanItemEditorState();
}

class _TravelPlanItemEditorState extends State<_TravelPlanItemEditor> {
  late final TextEditingController _placeName;
  late final TextEditingController _address;
  late final TextEditingController _activity;
  late final TextEditingController _date;
  late final TextEditingController _startTime;
  late final TextEditingController _endTime;
  late final TextEditingController _participantCount;
  late final TextEditingController _transportMinutes;
  late final TextEditingController _foodName;
  late final TextEditingController _foodDescription;
  late final TextEditingController _menuPrice;
  late final TextEditingController _menuCurrency;
  late final TextEditingController _memo;
  late TravelCategory _category;
  late ReservationStatus _reservationStatus;
  late FoodVerificationStatus _foodStatus;
  late TravelPlanVerificationStatus _verificationStatus;
  TransportType? _transportType;
  late bool _completed;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _placeName = TextEditingController(text: item.placeName);
    _address = TextEditingController(text: item.address ?? '');
    _activity = TextEditingController(text: item.activity);
    _date = TextEditingController(text: item.date ?? '');
    _startTime = TextEditingController(text: item.startTime ?? '');
    _endTime = TextEditingController(text: item.endTime ?? '');
    _participantCount = TextEditingController(
      text: item.participantCount?.toString() ?? '',
    );
    _transportMinutes = TextEditingController(
      text: item.transportMinutes?.toString() ?? '',
    );
    _foodName = TextEditingController(text: item.foodName ?? '');
    _foodDescription = TextEditingController(text: item.foodDescription ?? '');
    _menuPrice = TextEditingController(
      text: item.menuPriceAmount?.toString() ?? '',
    );
    _menuCurrency = TextEditingController(text: item.menuPriceCurrency ?? '');
    _memo = TextEditingController(text: item.memo);
    _category = item.category;
    _reservationStatus = item.reservationStatus;
    _foodStatus = item.foodVerificationStatus;
    _verificationStatus = item.verificationStatus;
    _transportType = item.transportType;
    _completed = item.completed;
  }

  @override
  void dispose() {
    for (final controller in [
      _placeName,
      _address,
      _activity,
      _date,
      _startTime,
      _endTime,
      _participantCount,
      _transportMinutes,
      _foodName,
      _foodDescription,
      _menuPrice,
      _menuCurrency,
      _memo,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius:
          widget.compact
              ? const BorderRadius.vertical(top: Radius.circular(28))
              : BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '행 편집',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                22,
                18,
                22,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                _Section(
                  title: '장소와 일정',
                  children: [
                    _TextField(controller: _placeName, label: '장소명'),
                    _TextField(controller: _address, label: '주소'),
                    DropdownButtonFormField<TravelCategory>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: '일정 유형'),
                      items: [
                        for (final value in TravelCategory.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
                    ),
                    _TextField(
                      controller: _activity,
                      label: '할 일',
                      maxLines: 2,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerField(
                            controller: _date,
                            label: '날짜',
                            icon: Icons.calendar_today_rounded,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TextField(
                            controller: _participantCount,
                            label: '동행 인원',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerField(
                            controller: _startTime,
                            label: '시작 시간',
                            icon: Icons.schedule_rounded,
                            onTap: () => _pickTime(_startTime),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PickerField(
                            controller: _endTime,
                            label: '종료 시간',
                            icon: Icons.schedule_rounded,
                            onTap: () => _pickTime(_endTime),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _Section(
                  title: '음식 정보',
                  description:
                      widget.item.isFoodPlace
                          ? '영상에서 확인되지 않은 값은 비워 두세요.'
                          : '식당 또는 카페 일정에서 사용하는 정보입니다.',
                  children: [
                    _TextField(controller: _foodName, label: '먹은 음식'),
                    _TextField(
                      controller: _foodDescription,
                      label: '음식 설명 또는 근거',
                      maxLines: 2,
                    ),
                    DropdownButtonFormField<FoodVerificationStatus>(
                      initialValue: _foodStatus,
                      decoration: const InputDecoration(labelText: '음식 확인 상태'),
                      items: [
                        for (final value in FoodVerificationStatus.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _foodStatus = value);
                        }
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _TextField(
                            controller: _menuPrice,
                            label: '메뉴 가격',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TextField(
                            controller: _menuCurrency,
                            label: '통화',
                            hintText: 'KRW',
                          ),
                        ),
                      ],
                    ),
                    if (widget.item.restaurantPriceLevel != null ||
                        widget.item.restaurantPriceMin != null ||
                        widget.item.restaurantPriceMax != null)
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Google 식당 가격대: '
                            '${widget.item.restaurantPriceLevel ?? ''}'
                            '${widget.item.restaurantPriceMin == null ? '' : ' / ${widget.item.restaurantPriceMin}'}'
                            '${widget.item.restaurantPriceMax == null ? '' : ' ~ ${widget.item.restaurantPriceMax}'}'
                            '${widget.item.restaurantPriceCurrency == null ? '' : ' ${widget.item.restaurantPriceCurrency}'}\n'
                            '특정 메뉴 가격이나 정확한 1인 식사비가 아닌 참고 정보입니다.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                  ],
                ),
                _Section(
                  title: '이동과 상태',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<TransportType?>(
                            initialValue: _transportType,
                            decoration: const InputDecoration(
                              labelText: '이동 방법',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('미정'),
                              ),
                              for (final value in TransportType.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                            ],
                            onChanged:
                                (value) =>
                                    setState(() => _transportType = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TextField(
                            controller: _transportMinutes,
                            label: '이동 시간(분)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<ReservationStatus>(
                      initialValue: _reservationStatus,
                      decoration: const InputDecoration(labelText: '예약 여부'),
                      items: [
                        for (final value in ReservationStatus.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _reservationStatus = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<TravelPlanVerificationStatus>(
                      initialValue: _verificationStatus,
                      decoration: const InputDecoration(labelText: '일정 상태'),
                      items: const [
                        DropdownMenuItem(
                          value: TravelPlanVerificationStatus.unconfirmed,
                          child: Text('확인 필요'),
                        ),
                        DropdownMenuItem(
                          value: TravelPlanVerificationStatus.confirmed,
                          child: Text('확인 완료'),
                        ),
                        DropdownMenuItem(
                          value: TravelPlanVerificationStatus.excluded,
                          child: Text('제외'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _verificationStatus = value);
                        }
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('일정 완료'),
                      value: _completed,
                      onChanged: (value) => setState(() => _completed = value),
                    ),
                    _TextField(controller: _memo, label: '메모', maxLines: 4),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
              child: Row(
                children: [
                  if (widget.onDelete != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD94747),
                            side: const BorderSide(color: Color(0xFFE8A4A4)),
                          ),
                          onPressed: () {
                            widget.onDelete?.call();
                            Navigator.pop(context);
                          },
                          child: const Text('행 삭제'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5B3FE4),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _submit,
                        child: const Text('저장'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      _date.text = _dateText(selected);
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial =
        parts.length == 2
            ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts[1]) ?? 0,
            )
            : TimeOfDay.now();
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected != null) {
      controller.text =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    }
  }

  void _submit() {
    final foodName = _nullIfEmpty(_foodName.text);
    final foodDescription = _nullIfEmpty(_foodDescription.text);
    final menuPrice = num.tryParse(_menuPrice.text.trim());
    Navigator.pop(
      context,
      widget.item.copyWith(
        placeName:
            _placeName.text.trim().isEmpty
                ? '이름 없는 일정'
                : _placeName.text.trim(),
        address: _nullIfEmpty(_address.text),
        category: _category,
        activity: _activity.text.trim(),
        date: _nullIfEmpty(_date.text),
        startTime: _nullIfEmpty(_startTime.text),
        endTime: _nullIfEmpty(_endTime.text),
        participantCount: int.tryParse(_participantCount.text.trim()),
        transportType: _transportType,
        transportMinutes: int.tryParse(_transportMinutes.text.trim()),
        reservationStatus: _reservationStatus,
        foodName: foodName,
        foodDescription: foodDescription,
        foodVerificationStatus: _foodStatus,
        menuPriceAmount: menuPrice,
        menuPriceCurrency:
            menuPrice == null ? null : _nullIfEmpty(_menuCurrency.text),
        menuPriceSource: menuPrice == null ? 'NONE' : 'USER',
        memo: _memo.text.trim(),
        verificationStatus: _verificationStatus,
        completed: _completed,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hintText),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Icon(icon, size: 18),
      ),
    );
  }
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _dateText(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
