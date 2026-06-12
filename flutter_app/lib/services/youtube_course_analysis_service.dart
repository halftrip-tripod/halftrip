import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

class YoutubeCourseAnalysisResult {
  const YoutubeCourseAnalysisResult({
    required this.videoId,
    required this.title,
    required this.summary,
    required this.keywords,
    required this.transcriptPlaceNames,
    required this.frameOnlyPlaceNames,
    required this.suggestedPlaceNames,
    required this.transcriptExcerpt,
    required this.usedTranscript,
    required this.usedThumbnailOcr,
    required this.usedFrameOcr,
    required this.frameCount,
    required this.warnings,
  });

  final String videoId;
  final String? title;
  final String summary;
  final List<String> keywords;
  final List<String> transcriptPlaceNames;
  final List<String> frameOnlyPlaceNames;
  final List<String> suggestedPlaceNames;
  final String? transcriptExcerpt;
  final bool usedTranscript;
  final bool usedThumbnailOcr;
  final bool usedFrameOcr;
  final int frameCount;
  final List<String> warnings;

  factory YoutubeCourseAnalysisResult.fromJson(Map<String, dynamic> json) {
    return YoutubeCourseAnalysisResult(
      videoId: json['video_id'] as String? ?? '',
      title: json['title'] as String?,
      summary: json['summary'] as String? ?? '',
      keywords: ((json['keywords'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      transcriptPlaceNames:
          ((json['transcript_place_names'] as List<dynamic>?) ?? const [])
              .map((item) => item.toString())
              .toList(),
      frameOnlyPlaceNames:
          ((json['frame_only_place_names'] as List<dynamic>?) ?? const [])
              .map((item) => item.toString())
              .toList(),
      suggestedPlaceNames:
          ((json['suggested_place_names'] as List<dynamic>?) ?? const [])
              .map((item) => item.toString())
              .toList(),
      transcriptExcerpt: json['transcript_excerpt'] as String?,
      usedTranscript: json['used_transcript'] as bool? ?? false,
      usedThumbnailOcr: json['used_thumbnail_ocr'] as bool? ?? false,
      usedFrameOcr: json['used_frame_ocr'] as bool? ?? false,
      frameCount: json['frame_count'] as int? ?? 0,
      warnings: ((json['warnings'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class YoutubeCourseAnalysisService {
  YoutubeCourseAnalysisService(this._config);

  final AppConfig _config;

  Future<YoutubeCourseAnalysisResult> analyze({
    required String url,
    required String regionName,
  }) async {
    final baseUri = Uri.parse(_config.fastApiBaseUrl);
    final mergedPath =
        '${baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path}/api/v1/videos/youtube/analyze';
    final uri = baseUri.replace(path: mergedPath);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'url': url,
        'region_name': regionName,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('YouTube 분석 실패: ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] == false) {
      throw Exception(decoded['message'] ?? 'YouTube 분석에 실패했습니다.');
    }
    return YoutubeCourseAnalysisResult.fromJson(
      decoded['data'] as Map<String, dynamic>,
    );
  }
}
