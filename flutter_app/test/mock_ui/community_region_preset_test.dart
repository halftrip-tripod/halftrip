import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_support_mvp/mock_ui/screens/community.dart';
import 'package:travel_support_mvp/mock_ui/state/app_state.dart';

/// "인기 코스 보러 가기" 진입 프리셋 — 커뮤니티 탭이 지역·종류 필터가
/// 적용된 상태로 열리는지 검증한다.
void main() {
  testWidgets('지역 프리셋이 있으면 해당 지역 필터로 열린다', (tester) async {
    AppState.I.communityRegion.value = '강진';

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CommunityTab())));
    await tester.pump();

    // 지역 칩이 '지역 전체'가 아니라 '강진'으로 표시되어야 한다.
    expect(find.text('강진'), findsWidgets);
    expect(find.text('지역 전체'), findsNothing);
    // 1회성 요청은 소비 후 비워진다.
    expect(AppState.I.communityRegion.value, isNull);
  });

  testWidgets('종류 프리셋(코스)이 있으면 코스 필터로 열린다', (tester) async {
    AppState.I.communityRegion.value = '영월';
    AppState.I.communityFilter.value = '코스';

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CommunityTab())));
    await tester.pump();

    expect(find.text('지역 전체'), findsNothing);
    expect(AppState.I.communityFilter.value, isNull);
  });

  testWidgets('탭이 이미 떠 있는 상태에서 온 프리셋도 적용된다 (실앱 경로)', (tester) async {
    // 실앱은 셸 IndexedStack의 const 자식이라 탭이 먼저 마운트되고,
    // "인기 코스 보러 가기"는 그 뒤에 프리셋을 건다 — 이 순서를 재현.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CommunityTab())));
    await tester.pump();
    expect(find.text('지역 전체'), findsOneWidget);

    AppState.I.communityRegion.value = '강진';
    await tester.pump();

    expect(find.text('지역 전체'), findsNothing);
    expect(AppState.I.communityRegion.value, isNull);
  });
}

// 참고: CommunityFeedScreen(courseOnly)는 코스 글·코스 첨부 글만 인기순으로 보여준다.
