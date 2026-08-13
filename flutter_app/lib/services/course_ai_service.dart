import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// AI 코스 생성 결과의 한 스톱(장소 이름·순서·이유).
class AiCourseStop {
  const AiCourseStop({
    required this.name,
    required this.day,
    required this.order,
    required this.reason,
    required this.eligibleForRefund,
  });

  final String name;
  final int day;
  final int order;
  final String reason;
  final bool eligibleForRefund;

  factory AiCourseStop.fromJson(Map<String, dynamic> json) {
    return AiCourseStop(
      name: json['name'] as String? ?? '',
      day: (json['day'] as num?)?.toInt() ?? 1,
      order: (json['order'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      eligibleForRefund: json['eligibleForRefund'] as bool? ?? false,
    );
  }
}

class AiCourseResult {
  const AiCourseResult({required this.summary, required this.stops});

  final String summary;
  final List<AiCourseStop> stops;
}

/// FastAPI `/api/v1/courses/ai-generate` 를 직접 호출해 LLM 코스를 받아온다.
/// (YoutubeCourseAnalysisService와 동일한 직접 호출 패턴.)
class CourseAiService {
  CourseAiService(this._config);

  final AppConfig _config;

  Future<AiCourseResult> generate({
    required String regionName,
    required int nights,
    required int people,
    required List<String> themePriority,
    required List<Map<String, dynamic>> candidates,
  }) async {
    final baseUri = Uri.parse(_config.fastApiBaseUrl);
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final uri = baseUri.replace(path: '$basePath/api/v1/courses/ai-generate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'region_name': regionName,
        'nights': nights,
        'people': people,
        'theme_priority': themePriority,
        'candidates': candidates,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI 코스 생성 실패: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] == false) {
      throw Exception(decoded['message'] ?? 'AI 코스 생성에 실패했습니다.');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final stops = ((data['stops'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AiCourseStop.fromJson)
        .toList();
    return AiCourseResult(
      summary: data['summary'] as String? ?? '',
      stops: stops,
    );
  }
}
