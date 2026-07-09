import 'package:flutter/material.dart';

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
  });

  final int day;
  String time;
  final String emoji;
  final String name;
  final String tag; // 관광지/맛집/숙소/카페 …
  final bool refund;
  final bool stay;
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
  final String region;
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
  });

  final String emoji;
  final String name;
  final String region;
  final String dateLabel;
  final int people;
  TripStage stage;
  String ddayLabel;
  final int nights;

  /// 이 여행의 확정 코스 — 없으면 여행 상세에서 코스 만들기로 유도.
  Course? course;
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
    required this.likes,
    required this.comments,
    required this.saves,
    this.likedByMe = false,
    this.savedByMe = false,
    this.mine = false,
    this.private = false,
    this.title,
  });

  final String avatarEmoji;
  final Color avatarBg;
  final String nick;
  final String region;
  final String timeAgo;
  final PostTag tag;
  final String text;
  final bool verified;
  final List<String> photos; // 이모지 플레이스홀더
  final String? courseName;
  final String? courseMeta;
  int likes;
  final int comments;
  int saves;
  bool likedByMe;
  bool savedByMe;
  final bool mine;
  final bool private;
  final String? title; // 작성한 글 목록용 제목
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
