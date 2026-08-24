import 'package:flutter/material.dart';

/// 한국관광공사 OpenAPI 데이터 출처 표기.
///
/// 공모전 필수 준수사항(6-2): 공사 데이터가 노출되는 화면에는 아래 문구를
/// **텍스트로만** 표기해야 한다 — 공사 CI/BI 로고 이미지·"TourAPI" 단독 표기 불가.
class TourApiAttribution extends StatelessWidget {
  const TourApiAttribution({
    super.key,
    this.label,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// 무엇의 출처인지 앞에 붙는 수식어 (예: '장소 정보' → "장소 정보 출처: ⓒ한국관광공사").
  /// 규정 필수 문구 "출처: ⓒ한국관광공사"는 항상 온전히 포함된다.
  final String? label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final prefix = label == null ? '' : '$label ';
    return Padding(
      padding: padding,
      child: Text(
        '$prefix출처: ⓒ한국관광공사',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9AA3AF),
        ),
      ),
    );
  }
}
