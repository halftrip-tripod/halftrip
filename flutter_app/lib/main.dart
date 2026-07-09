// 하프트립 — 현재는 목업 UI(halftrip-mockup 1:1)를 그대로 실행한다.
// 백엔드 연동 시 화면별로 mock_ui의 AppState 호출부를 repository로 교체하고,
// 기존 API 부트스트랩은 main_api.dart에 보존되어 있다.
import 'mock_ui/main.dart' as mock_ui;

void main() => mock_ui.main();
