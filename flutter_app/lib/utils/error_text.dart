/// 예외·서버 응답 원문을 사용자에게 보여줄 한 줄 문구로 바꾼다.
///
/// 화면(에러 페이지)·팝업·스낵바·컨트롤러가 전부 이 함수를 거쳐, 소켓 오류 원문이나
/// 502 HTML 페이지가 그대로 노출되는 일이 없게 한다.
String describeError(Object? error) {
  if (error == null) return '잠시 후 다시 시도해 주세요.';
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  if (text.isEmpty) return '잠시 후 다시 시도해 주세요.';
  if (text.contains('SocketException') ||
      text.contains('reset by peer') ||
      text.contains('ClientException') ||
      text.contains('Connection closed') ||
      text.contains('Failed host lookup')) {
    return '서버에 잠시 연결할 수 없어요. 네트워크를 확인하거나 잠시 후 다시 시도해 주세요.';
  }
  if (text.contains('TimeoutException')) return '서버 응답이 늦어요. 잠시 후 다시 시도해 주세요.';
  // HTML 오류 페이지(Render 502 등)·스택트레이스처럼 긴 원문은 통째로 가린다.
  if (text.contains('<html') || text.contains('<!DOCTYPE') || text.startsWith('<') || text.length > 160) {
    final prefix = RegExp(r'^[^<:]{2,20}: ').firstMatch(text)?.group(0) ?? '';
    return '$prefix서버 오류가 발생했어요. 잠시 후 다시 시도해 주세요.';
  }
  return text;
}
