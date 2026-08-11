import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_support_mvp/mock_ui/screens/trip_picker_sheet.dart';
import 'package:travel_support_mvp/models/app_models.dart';

TripSummary _trip({
  required int id,
  required String regionName,
  required DateTime start,
  required DateTime end,
  String status = 'BEFORE',
  int travelerCount = 2,
  bool settlementApplied = false,
}) {
  return TripSummary(
    id: id,
    regionId: id,
    regionName: regionName,
    applicantName: '홍길동',
    startDate: start,
    endDate: end,
    travelerCount: travelerCount,
    status: status,
    totalSpentAmount: 0,
    refundConditionAmount: 0,
    settlementApplied: settlementApplied,
  );
}

/// 시트를 띄우고 선택 결과를 받아오는 하네스.
Future<TripSummary?> _openSheet(
  WidgetTester tester,
  List<TripSummary> trips,
) async {
  TripSummary? picked;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                picked = await pickTripSheet(context, trips: trips);
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('연결 가능한 여행을 목록으로 보여준다', (tester) async {
    await _openSheet(tester, [
      _trip(
        id: 1,
        regionName: '완도',
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 11),
      ),
      _trip(
        id: 2,
        regionName: '강진',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 3),
        travelerCount: 4,
      ),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('어느 여행에 연결할까요?'), findsOneWidget);
    expect(find.text('완도 1박2일'), findsOneWidget);
    expect(find.text('강진 2박3일'), findsOneWidget);
    expect(find.text('9.10 ~ 9.11 · 2명'), findsOneWidget);
    expect(find.text('10.1 ~ 10.3 · 4명'), findsOneWidget);
  });

  testWidgets('여행을 고르면 그 여행을 돌려준다', (tester) async {
    final trips = [
      _trip(
        id: 7,
        regionName: '완도',
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 11),
      ),
      _trip(
        id: 8,
        regionName: '강진',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 3),
      ),
    ];
    TripSummary? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await pickTripSheet(context, trips: trips);
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('강진 2박3일'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.id, 8);
    expect(picked!.regionName, '강진');
  });

  testWidgets('서버 상태에 맞는 단계 배지를 붙인다', (tester) async {
    await _openSheet(tester, [
      _trip(
        id: 1,
        regionName: '완도',
        start: DateTime(2026, 9, 10),
        end: DateTime(2026, 9, 11),
      ),
      _trip(
        id: 2,
        regionName: '강진',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 3),
        status: 'ONGOING',
      ),
      _trip(
        id: 3,
        regionName: '해남',
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 2),
        status: 'ENDED',
      ),
    ]);

    expect(find.text('여행 전'), findsOneWidget);
    expect(find.text('여행 중'), findsOneWidget);
    expect(find.text('정산 준비'), findsOneWidget);
  });
}
