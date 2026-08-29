import 'package:flutter/material.dart';

import '../../models/app_models.dart' show SavedCourseStop;

/// 지역 접수 상태.
enum RegionStatus { open, soon, closed }

class Region {
  Region({
    required this.name,
    required this.province,
    required this.emoji,
    required this.status,
    required this.condition,
    required this.dday,
    this.ddayWarn = false,
    this.mintBenefit = false,
    this.openLabel,
    bool favorite = false,
  }) : favorite = ValueNotifier(favorite);

  final String name;
  final String province;
  final String emoji;
  final RegionStatus status;
  final String condition; // 환급 조건 한 줄
  final int dday;
  final bool ddayWarn;
  final bool mintBenefit; // 디민증 중복혜택
  final String? openLabel; // 오픈예정 문구
  final ValueNotifier<bool> favorite;
}

enum CourseSource { ai, youtube, manual }

class CourseStop {
  CourseStop({
    required this.day,
    required this.time,
    required this.emoji,
    required this.name,
    required this.tag,
    this.refund = false,
    this.stay = false,
    this.latitude,
    this.longitude,
    this.address,
    this.placeId,
  });

  final int day;
  String time;
  final String emoji;
  final String name;
  final String tag; // 관광지/맛집/숙소/카페 …
  final bool refund;
  final bool stay;
  // AI 코스 생성 결과(실서버 후보)일 때만 채워짐 — 지도·구글 상세정보 조회에 사용.
  final double? latitude;
  final double? longitude;
  final String? address;
  final int? placeId;
}

class Course {
  Course({
    required this.emoji,
    required this.region,
    required this.province,
    required this.title,
    required this.source,
    required this.durationLabel,
    required this.placeCount,
    required this.refundOk,
    required this.savedAgo,
    this.stops = const [],
  });

  final String emoji;
  String region; // 수정 가능
  final String province;
  String title;
  final CourseSource source;
  final String durationLabel;
  final int placeCount;
  final bool refundOk;
  final String savedAgo;
  final List<CourseStop> stops;
}

/// 여행 단계 (여행 전 → 여행 중 → 정산 → 환급대기 → 완료).
enum TripStage { before, during, settle, review, done }

class Trip {
  Trip({
    required this.emoji,
    required this.name,
    required this.region,
    required this.dateLabel,
    required this.people,
    required this.stage,
    this.ddayLabel = '',
    this.nights = 1,
    this.course,
    this.backendId,
    this.startDate,
  });

  final String emoji;
  final String name;
  String region; // 수정 가능
  final String dateLabel;
  final int people;
  TripStage stage;
  String ddayLabel;
  final int nights;

  /// 이 여행의 확정 코스 — 없으면 여행 상세에서 코스 만들기로 유도.
  Course? course;

  /// 실서버 여행 id — 여행 상세에서 프록시로 만들 때 채워져,
  /// 코스함 가져오기 등 실스토어 연결(selectCourseForTrip)에 쓴다.
  final int? backendId;

  /// 실제 여행 시작일 — 코스 일정의 DAY별 날짜 라벨에 쓴다. 없으면 날짜 없이 DAY만.
  final DateTime? startDate;
}

enum PostTag { review, course, ask, info }

class Post {
  Post({
    required this.avatarEmoji,
    required this.avatarBg,
    required this.nick,
    required this.region,
    required this.timeAgo,
    required this.tag,
    required this.text,
    this.verified = false,
    this.photos = const [],
    this.courseName,
    this.courseMeta,
    this.courseStops = const [],
    required this.likes,
    required this.comments,
    required this.saves,
    this.likedByMe = false,
    this.savedByMe = false,
    this.mine = false,
    this.private = false,
    this.title,
    this.serverId,
    this.edited = false,
  });

  /// 실서버 게시글 id — 서버 연동 모드에서만 채워짐 (mock 시드는 null).
  int? serverId;

  /// 내용 수정 여부 — "수정됨" 표시.
  bool edited;

  final String avatarEmoji;
  final Color avatarBg;
  final String nick;
  String region; // 수정 가능
  final String timeAgo;
  PostTag tag; // 수정 가능
  String text; // 수정 가능
  bool verified; // 서버 검증(다녀온 여행) 결과로 갱신될 수 있음
  final List<String> photos; // 이모지 플레이스홀더
  String? courseName; // 수정 가능
  String? courseMeta; // 수정 가능
  List<SavedCourseStop> courseStops; // 첨부 코스 정차지 스냅샷 — 지도·코스함 저장용
  int likes;
  int comments; // 댓글 작성 시 갱신
  int saves;
  bool likedByMe;
  bool savedByMe;
  final bool mine;
  bool private; // 나만보기 → 공개 전환 가능
  String? title; // 수정 가능 // 작성한 글 목록용 제목
}

enum NotifTone { sky, coral, amber, gray }

class NotifItem {
  NotifItem({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.timeAgo,
    this.unread = false,
  });

  final IconData icon;
  final NotifTone tone;
  final String title;
  final String body;
  final String timeAgo;
  bool unread;
}

class Receipt {
  Receipt({required this.name, required this.category, required this.amount});
  final String name;
  final String category;
  final int amount; // 원
}
