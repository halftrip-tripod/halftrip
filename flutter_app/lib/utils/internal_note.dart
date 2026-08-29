/// 시드·마이그레이션의 description 컬럼에는 개발용 메모가 그대로 들어 있다.
/// (예: "TODO: 실제 온라인몰 연동 예정", "완도 반값여행 지정관광지 sample data")
/// 이 값을 화면에 그대로 뿌리면 사용자와 심사위원이 내부 메모를 보게 된다.
/// 데이터가 정리될 때까지 화면 단에서 거른다.
library;

const _internalMarkers = <String>[
  'TODO',
  'SAMPLE_SEED',
  'sample data',
  'sample seed', // 온라인몰 description('sample seed online mall link')

  '연동 예정',
  '확인 예정',
  '정리 중',
];

/// 사용자에게 보여도 되는 설명이면 그대로, 내부 메모면 null을 준다.
String? userFacingNote(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  for (final marker in _internalMarkers) {
    if (text.toLowerCase().contains(marker.toLowerCase())) return null;
  }
  return text;
}
