/// 양식에 미리 인쇄된 칸("010 -  -", "2026년  월  일", "2026.  .  . ~")을 채우는 조각 값.
///
/// 좌표 양식은 이런 칸을 조각 키(traveler_phone_mid, payment_date_month,
/// trip_date_range_start_day …)로 받는다. 서버는 여행 정보로 원래 키(traveler_phone_number,
/// trip_date_range …)만 미리 채우므로, 조각이 비어 있으면 원래 키에서 잘라 보여 준다.
/// FastAPI `lodging_payload_parts.py` 와 같은 규칙 — 화면과 PDF가 같은 값을 쓴다.
library;

const _phoneBases = {
  'traveler_phone': 'traveler_phone_number',
  'phone_number': 'phone_number',
  'applicant_phone': 'traveler_phone_number',
};

final _datePattern = RegExp(
  r'(?:(\d{4})\s*[-./년]\s*)?(\d{1,2})\s*[-./월]\s*(\d{1,2})',
);

List<String> _phoneParts(Object? value) {
  final digits = (value ?? '').toString().replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11) {
    return [digits.substring(0, 3), digits.substring(3, 7), digits.substring(7)];
  }
  if (digits.length == 10) {
    return [digits.substring(0, 3), digits.substring(3, 6), digits.substring(6)];
  }
  return const ['', '', ''];
}

List<String> _dateParts(Object? value) {
  final match = _datePattern.firstMatch((value ?? '').toString());
  if (match == null) return const ['', '', ''];
  return [
    match.group(1) ?? '',
    int.parse(match.group(2)!).toString(),
    int.parse(match.group(3)!).toString(),
  ];
}

/// 조각 키의 값을 원래 키에서 만든다. 조각 키가 아니거나 원래 값이 없으면 ''.
String derivePayloadPart(String key, Map<String, dynamic> payload) {
  for (final entry in _phoneBases.entries) {
    final prefix = '${entry.key}_';
    if (key.startsWith(prefix) && key != entry.value) {
      final parts = _phoneParts(payload[entry.value]);
      final suffix = key.substring(prefix.length);
      if (suffix.startsWith('mid')) return parts[1];
      if (suffix.startsWith('last')) return parts[2];
      if (suffix.startsWith('tail')) {
        return parts[1].isEmpty ? '' : '${parts[1]}-${parts[2]}';
      }
    }
  }

  const suffixes = ['_year', '_month', '_day'];
  for (var index = 0; index < suffixes.length; index++) {
    final suffix = suffixes[index];
    if (!key.endsWith(suffix)) continue;
    final base = key.substring(0, key.length - suffix.length);
    Object? source;
    if (base.startsWith('trip_date_range_')) {
      final side = base.substring('trip_date_range_'.length);
      final ranges = (payload['trip_date_range'] ?? '')
          .toString()
          .split(RegExp(r'\s*~\s*'));
      source = side == 'start'
          ? ranges.first
          : (ranges.length > 1 ? ranges[1] : '');
    } else {
      source = payload[base];
    }
    return _dateParts(source)[index];
  }
  return '';
}

/// 글자 칸의 처음 값 — 저장된 값이 없으면 원래 키에서 만든 조각.
String initialTextValue(String key, Map<String, dynamic> payload) {
  final value = payload[key]?.toString() ?? '';
  return value.trim().isEmpty ? derivePayloadPart(key, payload) : value;
}

/// 체크 칸의 처음 값 — 동의 "예" 칸은 서버가 채운 한 값(agreed_personal_info)을 따른다.
bool initialCheckboxValue(String key, Map<String, dynamic> payload) {
  final value = payload[key];
  if (value is bool) return value;
  if (value == null && key.endsWith('_yes')) {
    return payload[key.substring(0, key.length - '_yes'.length)] == true;
  }
  return value == true || value == 'true';
}
