import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'travel_plan_models.dart';

class GoogleSheetsExportResult {
  const GoogleSheetsExportResult({
    required this.spreadsheetId,
    required this.spreadsheetUrl,
  });

  final String spreadsheetId;
  final String spreadsheetUrl;
}

class GoogleSheetsExportService {
  GoogleSheetsExportService({
    required String oauthClientId,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _oauthClientId = oauthClientId.trim(),
       _googleSignIn = GoogleSignIn(
         clientId:
             kIsWeb && oauthClientId.trim().isNotEmpty
                 ? oauthClientId.trim()
                 : null,
         scopes: const ['https://www.googleapis.com/auth/spreadsheets'],
       );

  static const _apiBase = 'https://sheets.googleapis.com/v4/spreadsheets';

  final http.Client _client;
  final String _oauthClientId;
  final GoogleSignIn _googleSignIn;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  bool get isConnected => currentUser != null;

  Future<GoogleSignInAccount?> connect() async {
    if (kIsWeb && _oauthClientId.isEmpty) {
      throw Exception('웹에서 Google 계정을 연결하려면 GOOGLE_OAUTH_CLIENT_ID가 필요합니다.');
    }
    final existing = await _googleSignIn.signInSilently();
    return existing ?? _googleSignIn.signIn();
  }

  Future<void> disconnect() => _googleSignIn.disconnect();

  /// 계획을 Google 스프레드시트로 내보낸다.
  ///
  /// [targetSpreadsheetId]를 주면 그 문서를 덮어쓰고, 없으면 새로 만든다.
  /// 덮어쓸 문서가 지워졌거나 권한이 없으면 새로 만들어 폴백한다(내보내기 자체가
  /// 실패하는 것보다 낫다).
  Future<GoogleSheetsExportResult> export(
    TravelPlanDocument plan, {
    String? targetSpreadsheetId,
  }) async {
    final account = currentUser ?? await connect();
    if (account == null) {
      throw Exception('Google 계정 연결이 취소되었습니다.');
    }
    final authentication = await account.authentication;
    final accessToken = authentication.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Google Sheets 접근 권한을 확인하지 못했습니다.');
    }
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json; charset=utf-8',
    };

    final reuseId = targetSpreadsheetId?.trim() ?? '';
    if (reuseId.isNotEmpty) {
      final sheetIds = await _existingSheetIds(reuseId, headers);
      if (sheetIds != null) {
        // 행이 줄었을 때 옛 데이터가 남지 않게 먼저 비운다.
        await _clearValues(spreadsheetId: reuseId, headers: headers);
        await _writeValues(
          spreadsheetId: reuseId,
          headers: headers,
          plan: plan,
        );
        await _applyFormatting(
          spreadsheetId: reuseId,
          headers: headers,
          scheduleSheetId: sheetIds['전체 일정'] ?? 0,
          infoSheetId: sheetIds['여행 정보'] ?? 0,
          scheduleRowCount: plan.items.length + 1,
        );
        return GoogleSheetsExportResult(
          spreadsheetId: reuseId,
          spreadsheetUrl: 'https://docs.google.com/spreadsheets/d/$reuseId/edit',
        );
      }
    }

    final createResponse = await _client.post(
      Uri.parse(_apiBase),
      headers: headers,
      body: jsonEncode({
        'properties': {'title': _spreadsheetTitle(plan)},
        'sheets': [
          {
            'properties': {'title': '전체 일정'},
          },
          {
            'properties': {'title': '여행 정보'},
          },
        ],
      }),
    );
    final createJson = _decodeSuccess(createResponse, '스프레드시트 생성');
    final spreadsheetId = createJson['spreadsheetId'] as String? ?? '';
    if (spreadsheetId.isEmpty) {
      throw Exception('생성된 Google 스프레드시트 ID가 없습니다.');
    }

    final sheetIds = <String, int>{};
    for (final raw in (createJson['sheets'] as List<dynamic>? ?? const [])) {
      if (raw is! Map) continue;
      final properties = raw['properties'];
      if (properties is! Map) continue;
      final title = properties['title']?.toString();
      final sheetId = properties['sheetId'];
      if (title != null && sheetId is num) {
        sheetIds[title] = sheetId.toInt();
      }
    }

    await _writeValues(
      spreadsheetId: spreadsheetId,
      headers: headers,
      plan: plan,
    );
    await _applyFormatting(
      spreadsheetId: spreadsheetId,
      headers: headers,
      scheduleSheetId: sheetIds['전체 일정'] ?? 0,
      infoSheetId: sheetIds['여행 정보'] ?? 0,
      scheduleRowCount: plan.items.length + 1,
    );

    return GoogleSheetsExportResult(
      spreadsheetId: spreadsheetId,
      spreadsheetUrl:
          'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit',
    );
  }

  /// 덮어쓸 문서의 시트 탭 id를 읽는다. 문서가 없거나(404) 권한이 없으면(403)
  /// null을 돌려줘 호출부가 새로 만들도록 한다. 탭이 지워졌으면 다시 만든다.
  Future<Map<String, int>?> _existingSheetIds(
    String spreadsheetId,
    Map<String, String> headers,
  ) async {
    final response = await _client.get(
      Uri.parse('$_apiBase/$spreadsheetId?fields=sheets.properties'),
      headers: headers,
    );
    if (response.statusCode == 404 || response.statusCode == 403) return null;
    final decoded = _decodeSuccess(response, '기존 스프레드시트 확인');

    final ids = <String, int>{};
    for (final raw in (decoded['sheets'] as List<dynamic>? ?? const [])) {
      if (raw is! Map) continue;
      final properties = raw['properties'];
      if (properties is! Map) continue;
      final title = properties['title']?.toString();
      final sheetId = properties['sheetId'];
      if (title != null && sheetId is num) ids[title] = sheetId.toInt();
    }

    final missing =
        ['전체 일정', '여행 정보'].where((title) => !ids.containsKey(title)).toList();
    if (missing.isEmpty) return ids;

    final addResponse = await _client.post(
      Uri.parse('$_apiBase/$spreadsheetId:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'requests': [
          for (final title in missing)
            {
              'addSheet': {
                'properties': {'title': title},
              },
            },
        ],
      }),
    );
    final added = _decodeSuccess(addResponse, '시트 탭 추가');
    for (final raw in (added['replies'] as List<dynamic>? ?? const [])) {
      final properties = (raw is Map ? raw['addSheet'] : null) is Map
          ? ((raw as Map)['addSheet'] as Map)['properties']
          : null;
      if (properties is! Map) continue;
      final title = properties['title']?.toString();
      final sheetId = properties['sheetId'];
      if (title != null && sheetId is num) ids[title] = sheetId.toInt();
    }
    return ids;
  }

  /// 덮어쓰기 전 기존 값을 비운다 — 이번 계획의 행이 더 적으면 옛 행이 남는다.
  Future<void> _clearValues({
    required String spreadsheetId,
    required Map<String, String> headers,
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBase/$spreadsheetId/values:batchClear'),
      headers: headers,
      body: jsonEncode({
        'ranges': ["'전체 일정'!A1:AA10000", "'여행 정보'!A1:B100"],
      }),
    );
    _decodeSuccess(response, '기존 시트 비우기');
  }

  Future<void> _writeValues({
    required String spreadsheetId,
    required Map<String, String> headers,
    required TravelPlanDocument plan,
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBase/$spreadsheetId/values:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'valueInputOption': 'USER_ENTERED',
        'data': [
          {
            'range': "'전체 일정'!A1:AA${plan.items.length + 1}",
            'majorDimension': 'ROWS',
            'values': [
              _scheduleHeaders,
              ...([...plan.items]
                ..sort((a, b) => a.order.compareTo(b.order))).map(_scheduleRow),
            ],
          },
          {
            'range': "'여행 정보'!A1:B10",
            'majorDimension': 'ROWS',
            'values': _infoRows(plan),
          },
        ],
      }),
    );
    _decodeSuccess(response, '여행 계획 데이터 내보내기');
  }

  Future<void> _applyFormatting({
    required String spreadsheetId,
    required Map<String, String> headers,
    required int scheduleSheetId,
    required int infoSheetId,
    required int scheduleRowCount,
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBase/$spreadsheetId:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'requests': [
          {
            'updateSheetProperties': {
              'properties': {
                'sheetId': scheduleSheetId,
                'gridProperties': {'frozenRowCount': 1},
              },
              'fields': 'gridProperties.frozenRowCount',
            },
          },
          {
            'repeatCell': {
              'range': {
                'sheetId': scheduleSheetId,
                'startRowIndex': 0,
                'endRowIndex': 1,
              },
              'cell': {
                'userEnteredFormat': {
                  'backgroundColor': {'red': 0.88, 'green': 0.93, 'blue': 1.0},
                  'textFormat': {'bold': true},
                  'horizontalAlignment': 'CENTER',
                },
              },
              'fields':
                  'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)',
            },
          },
          {
            'setBasicFilter': {
              'filter': {
                'range': {
                  'sheetId': scheduleSheetId,
                  'startRowIndex': 0,
                  'endRowIndex': scheduleRowCount,
                  'startColumnIndex': 0,
                  'endColumnIndex': _scheduleHeaders.length,
                },
              },
            },
          },
          _columnWidthRequest(scheduleSheetId, 5, 7, 220),
          _columnWidthRequest(scheduleSheetId, 8, 10, 220),
          _columnWidthRequest(scheduleSheetId, 22, 23, 260),
          {
            'repeatCell': {
              'range': {
                'sheetId': scheduleSheetId,
                'startRowIndex': 1,
                'startColumnIndex': 2,
                'endColumnIndex': 3,
              },
              'cell': {
                'userEnteredFormat': {
                  'numberFormat': {'type': 'DATE', 'pattern': 'yyyy-mm-dd'},
                },
              },
              'fields': 'userEnteredFormat.numberFormat',
            },
          },
          {
            'repeatCell': {
              'range': {
                'sheetId': scheduleSheetId,
                'startRowIndex': 1,
                'startColumnIndex': 3,
                'endColumnIndex': 5,
              },
              'cell': {
                'userEnteredFormat': {
                  'numberFormat': {'type': 'TIME', 'pattern': 'hh:mm'},
                },
              },
              'fields': 'userEnteredFormat.numberFormat',
            },
          },
          {
            'repeatCell': {
              'range': {
                'sheetId': scheduleSheetId,
                'startRowIndex': 1,
                'startColumnIndex': 23,
                'endColumnIndex': 24,
              },
              'cell': {
                'userEnteredFormat': {'wrapStrategy': 'WRAP'},
              },
              'fields': 'userEnteredFormat.wrapStrategy',
            },
          },
          {
            'updateDimensionProperties': {
              'range': {
                'sheetId': scheduleSheetId,
                'dimension': 'COLUMNS',
                'startIndex': 0,
                'endIndex': 1,
              },
              'properties': {'hiddenByUser': true},
              'fields': 'hiddenByUser',
            },
          },
          {
            'repeatCell': {
              'range': {
                'sheetId': infoSheetId,
                'startColumnIndex': 0,
                'endColumnIndex': 1,
              },
              'cell': {
                'userEnteredFormat': {
                  'textFormat': {'bold': true},
                },
              },
              'fields': 'userEnteredFormat.textFormat.bold',
            },
          },
          _columnWidthRequest(infoSheetId, 0, 1, 170),
          _columnWidthRequest(infoSheetId, 1, 2, 520),
        ],
      }),
    );
    _decodeSuccess(response, '스프레드시트 서식 적용');
  }

  Map<String, dynamic> _decodeSuccess(http.Response response, String action) {
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map
              ? ((decoded['error'] as Map?)?['message']?.toString() ??
                  decoded['message']?.toString())
              : null;
      throw Exception(
        '$action 실패 (${response.statusCode})${message == null ? '' : ': $message'}',
      );
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  static String _spreadsheetTitle(TravelPlanDocument plan) {
    final title = plan.title.trim().isEmpty ? '유튜브 여행 계획' : plan.title;
    return '$title - ${DateTime.now().toIso8601String().substring(0, 10)}';
  }

  static List<Object?> _scheduleRow(TravelPlanItem item) => [
    item.id,
    item.order,
    item.date ?? '',
    item.startTime ?? '',
    item.endTime ?? '',
    item.placeName,
    item.address ?? '',
    item.category.label,
    item.activity,
    item.foodName ?? '',
    item.foodVerificationStatus.label,
    item.menuPriceAmount ?? '',
    item.menuPriceCurrency ?? '',
    item.menuPriceSource == 'NONE' ? '' : item.menuPriceSource,
    priceLevelLabel(item.restaurantPriceLevel),
    item.restaurantPriceMin ?? '',
    item.restaurantPriceMax ?? '',
    item.restaurantPriceCurrency ?? '',
    restaurantPriceSourceLabel(item.restaurantPriceSource),
    item.transportType?.label ?? '',
    item.transportMinutes ?? '',
    item.reservationStatus.label,
    item.memo,
    item.videoTimestampSeconds ?? '',
    item.videoEndTimestampSeconds ?? '',
    item.placeId ?? '',
    item.verificationStatus.name.toUpperCase(),
  ];

  static List<List<Object?>> _infoRows(TravelPlanDocument plan) => [
    ['여행 제목', plan.title],
    ['여행 도시', plan.city],
    ['시작일', plan.startDate ?? ''],
    ['종료일', plan.endDate ?? ''],
    ['여행 인원', plan.participantCount ?? ''],
    ['원본 유튜브 URL', plan.youtubeUrl],
    ['영상 제목', plan.videoTitle],
    ['내보낸 날짜', DateTime.now().toIso8601String()],
    [
      '식당 가격대 안내',
      '식당 가격대는 Google 장소 정보를 기반으로 한 참고 범위이며 특정 메뉴 가격이나 정확한 1인 식사비가 아닙니다.',
    ],
  ];

  static Map<String, dynamic> _columnWidthRequest(
    int sheetId,
    int start,
    int end,
    int width,
  ) => {
    'updateDimensionProperties': {
      'range': {
        'sheetId': sheetId,
        'dimension': 'COLUMNS',
        'startIndex': start,
        'endIndex': end,
      },
      'properties': {'pixelSize': width},
      'fields': 'pixelSize',
    },
  };
}

const _scheduleHeaders = [
  '일정 ID',
  '순서',
  '날짜',
  '시작 시간',
  '종료 시간',
  '장소명',
  '주소',
  '일정 유형',
  '할 일',
  '먹은 음식',
  '음식 확인 상태',
  '메뉴 가격',
  '메뉴 가격 통화',
  '메뉴 가격 출처',
  '식당 가격 수준',
  '식당 최소 가격',
  '식당 최대 가격',
  '식당 가격 통화',
  '식당 가격 정보 출처',
  '이동 방법',
  '이동 시간',
  '예약 여부',
  '메모',
  '영상 시작 위치',
  '영상 종료 위치',
  'Google Place ID',
  '상태',
];

String priceLevelLabel(String? value) {
  return switch (value?.toUpperCase()) {
    'PRICE_LEVEL_FREE' => '무료',
    'PRICE_LEVEL_INEXPENSIVE' => '저렴',
    'PRICE_LEVEL_MODERATE' => '보통',
    'PRICE_LEVEL_EXPENSIVE' => '비쌈',
    'PRICE_LEVEL_VERY_EXPENSIVE' => '매우 비쌈',
    _ => value ?? '',
  };
}

String restaurantPriceSourceLabel(RestaurantPriceSource value) {
  return switch (value) {
    RestaurantPriceSource.googlePriceRange => 'Google 가격 범위',
    RestaurantPriceSource.googlePriceLevel => 'Google 가격 수준',
    RestaurantPriceSource.video => '영상',
    RestaurantPriceSource.user => '사용자 입력',
    RestaurantPriceSource.none => '',
  };
}
