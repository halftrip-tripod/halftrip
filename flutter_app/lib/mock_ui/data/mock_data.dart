import 'package:flutter/material.dart';

import 'models.dart';

/// 강진 기본 코스 일정 (course-sim.html).
List<CourseStop> gangjinStops() => [
      CourseStop(day: 1, time: '10:00', emoji: '🏯', name: '다산초당', tag: '관광지', refund: true),
      CourseStop(day: 1, time: '12:30', emoji: '🍲', name: '강진만 회타운', tag: '맛집'),
      CourseStop(day: 1, time: '14:30', emoji: '🌉', name: '가우도 출렁다리', tag: '관광지', refund: true),
      CourseStop(day: 1, time: '18:00', emoji: '🏠', name: '다산 한옥스테이', tag: '숙소', refund: true, stay: true),
      CourseStop(day: 2, time: '09:30', emoji: '🏺', name: '고려청자박물관', tag: '관광지'),
      CourseStop(day: 2, time: '12:00', emoji: '🍖', name: '병영 설성식당', tag: '맛집'),
      CourseStop(day: 2, time: '14:30', emoji: '🌾', name: '강진만 생태공원', tag: '관광지'),
    ];

List<Region> buildRegions() => [
      Region(
        name: '평창', province: '강원특별자치도', emoji: '🏔️',
        status: RegionStatus.open, condition: '관광지 2곳 인증 · 제로페이 결제',
        dday: 2, ddayWarn: true,
      ),
      Region(
        name: '강진', province: '전라남도', emoji: '🍲',
        status: RegionStatus.open, condition: '관광지 2곳 인증 · 숙박 필수',
        dday: 5, mintBenefit: true, favorite: true,
      ),
      Region(
        name: '영월', province: '강원특별자치도', emoji: '🌊',
        status: RegionStatus.soon, condition: '관광지 2곳 인증',
        dday: 3, openLabel: '6월 16일 오픈 예정',
      ),
      Region(
        name: '거창', province: '경상남도', emoji: '🌿',
        status: RegionStatus.soon, condition: '관광지 2곳 인증',
        dday: 7, openLabel: '6월 20일 오픈 예정',
      ),
      Region(
        name: '고창', province: '전라북도', emoji: '⛰️',
        status: RegionStatus.soon, condition: '관광지 2곳 인증',
        dday: 11, openLabel: '6월 24일 오픈 예정',
      ),
      Region(
        name: '완도', province: '전라남도', emoji: '🐙',
        status: RegionStatus.open, condition: '관광지 2곳 인증',
        dday: 9, favorite: true,
      ),
      Region(
        name: '제천', province: '충청북도', emoji: '⛰️',
        status: RegionStatus.open, condition: '관광지 2곳 인증',
        dday: 12,
      ),
    ];

List<Course> buildCourses() => [
      Course(
        emoji: '🍲', region: '강진', province: '전라남도',
        title: '강진 환급 보장 코스', source: CourseSource.ai,
        durationLabel: '1박 2일', placeCount: 7, refundOk: true,
        savedAgo: '3일 전 저장', stops: gangjinStops(),
      ),
      Course(
        emoji: '🍲', region: '강진', province: '전라남도',
        title: '강진 유튜브 추천 코스', source: CourseSource.youtube,
        durationLabel: '1박 2일', placeCount: 6, refundOk: true,
        savedAgo: '5일 전 저장', stops: gangjinStops(),
      ),
      Course(
        emoji: '🌊', region: '영월', province: '강원특별자치도',
        title: '영월 동강 감성 당일 코스', source: CourseSource.manual,
        durationLabel: '당일치기', placeCount: 4, refundOk: false,
        savedAgo: '2주 전 저장', stops: gangjinStops(),
      ),
      Course(
        emoji: '🏔️', region: '평창', province: '강원특별자치도',
        title: '평창 겨울 힐링 코스', source: CourseSource.ai,
        durationLabel: '1박 2일', placeCount: 5, refundOk: true,
        savedAgo: '지난달 저장', stops: gangjinStops(),
      ),
      Course(
        emoji: '⛰️', region: '제천', province: '충청북도',
        title: '제천 환급 보장 코스', source: CourseSource.ai,
        durationLabel: '1박 2일', placeCount: 5, refundOk: true,
        savedAgo: '지난달 저장', stops: gangjinStops(),
      ),
    ];

List<Trip> buildTrips() => [
      Trip(
        emoji: '🍲', name: '강진 1박2일', region: '강진',
        dateLabel: '6.14 ~ 6.15 · 2명', people: 2,
        stage: TripStage.before, ddayLabel: '출발 D-3',
      ),
      Trip(
        emoji: '🏔️', name: '평창 1박2일', region: '평창',
        dateLabel: '오늘 여행 중 · 인증·소비 기록 중', people: 2,
        stage: TripStage.during, ddayLabel: 'Day 1 / 2',
      ),
      Trip(
        emoji: '🌊', name: '영월 1박2일', region: '영월',
        dateLabel: '6.01 ~ 6.02 · 여행 종료', people: 2,
        stage: TripStage.settle, ddayLabel: '정산 마감 D-5',
      ),
      Trip(
        emoji: '⛰️', name: '제천 1박2일', region: '제천',
        dateLabel: '5.10 ~ 5.11 · 2명', people: 2,
        stage: TripStage.done, ddayLabel: '환급 완료',
      ),
    ];

List<Post> buildPosts() => [
      Post(
        avatarEmoji: '🦊', avatarBg: const Color(0xFFFFE9D6),
        nick: '여행하는민트', verified: true,
        region: '강진', timeAgo: '3일 전', tag: PostTag.review,
        title: '강진 여행 후기',
        text: '가우도 출렁다리 노을 진짜 최고였어요. 다산초당이랑 묶어서 도는 동선 강추! 환급까지 받으니 거의 공짜 여행 ㅎㅎ',
        photos: ['assets/region_hero/gangjin.jpg', 'assets/region_hero/wando.jpg'],
        courseName: '강진 환급 보장 코스', courseMeta: '1박 2일 · 7곳 · 환급 조건 충족',
        likes: 42, comments: 3, saves: 18, savedByMe: true,
      ),
      Post(
        avatarEmoji: '🐻', avatarBg: const Color(0xFFE0F2FE),
        nick: '영월초보',
        region: '영월', timeAgo: '5시간 전', tag: PostTag.course,
        title: '영월 코스 평가 받아요',
        text: '첫 반값여행 영월 1박2일 코스 짜봤는데 동선 어때요? 빠진 데 있을까요? 🙏',
        courseName: '영월 동강 감성 코스', courseMeta: '1박 2일 · 5곳 · 환급 조건 충족',
        likes: 12, comments: 15, saves: 26, savedByMe: true,
      ),
      Post(
        avatarEmoji: '🐧', avatarBg: const Color(0xFFE0F2FE),
        nick: '강진가고파',
        region: '강진', timeAgo: '어제', tag: PostTag.ask,
        title: '가우도 주차 질문',
        text: '6월 말 강진 가는데 가우도 주차 어디가 편한가요? 주말이라 자리 걱정되네요 🚗',
        likes: 3, comments: 9, saves: 4,
      ),
      Post(
        avatarEmoji: '🐰', avatarBg: const Color(0xFFE4F6F2),
        nick: '먹보여행', verified: true,
        region: '평창', timeAgo: '2일 전', tag: PostTag.info,
        title: '평창 한우 맛집 정리',
        text: '평창 양떼목장 근처 한우 맛집 3곳 가성비 순으로 정리했어요 🐮 환급 결제 되는 곳만 골랐음!',
        photos: ['assets/region_hero/pyeongchang.jpg', 'assets/region_hero/hoengseong.jpg'],
        courseName: '평창 목장 먹방 코스', courseMeta: '1박 2일 · 6곳 · 환급 조건 충족',
        likes: 30, comments: 5, saves: 15, savedByMe: true,
      ),
    ];

List<NotifItem> buildNotifications() => [
      NotifItem(
        icon: Icons.flag_outlined, tone: NotifTone.sky,
        title: '강진 반값여행 접수 시작 🎉',
        body: '관심 등록한 강진의 6월 반값여행 접수가 열렸어요. 지금 신청해보세요.',
        timeAgo: '10분 전', unread: true,
      ),
      NotifItem(
        icon: Icons.route_outlined, tone: NotifTone.sky,
        title: '유튜브 코스가 완성됐어요',
        body: '강진 유튜브 추천 코스를 내 코스함에 저장했어요. 확인해보세요.',
        timeAgo: '1시간 전', unread: true,
      ),
      NotifItem(
        icon: Icons.favorite_outline, tone: NotifTone.coral,
        title: '여행하는민트님 외 4명이 좋아해요',
        body: '내 글 "강진 여행 후기"에 좋아요가 달렸어요.',
        timeAgo: '3시간 전', unread: true,
      ),
      NotifItem(
        icon: Icons.schedule_outlined, tone: NotifTone.amber,
        title: '영월 정산 신청 마감 D-3',
        body: '여행 종료 다음날부터 7일 이내에 정산을 신청하세요.',
        timeAgo: '어제',
      ),
      NotifItem(
        icon: Icons.chat_bubble_outline_rounded, tone: NotifTone.sky,
        title: '강진가고파님이 댓글을 남겼어요',
        body: '가우도 주차는 어디 하셨어요?',
        timeAgo: '2일 전',
      ),
      NotifItem(
        icon: Icons.schedule_outlined, tone: NotifTone.amber,
        title: '완도 접수 마감 D-1',
        body: '관심 등록한 완도 반값여행 접수가 곧 마감돼요.',
        timeAgo: '3일 전',
      ),
      NotifItem(
        icon: Icons.card_giftcard_rounded, tone: NotifTone.gray,
        title: '디지털 관광주민증 혜택 추가',
        body: '강진 가맹점에 디민증 추가 할인 혜택이 생겼어요.',
        timeAgo: '1주 전',
      ),
    ];

List<Receipt> buildReceipts() => [
      Receipt(name: '다산 한옥스테이', category: '숙박', amount: 60000),
      Receipt(name: '병영 설성식당', category: '한식', amount: 32000),
      Receipt(name: '가우도 카페', category: '카페', amount: 14500),
    ];

/// 아바타 프리셋 (프로필 편집).
const avatarPresets = [
  ('🐳', Color(0xFFE0F2FE)),
  ('🦊', Color(0xFFFFE9D6)),
  ('🐻', Color(0xFFE0F2FE)),
  ('🐧', Color(0xFFF0F9FF)),
  ('🐰', Color(0xFFE4F6F2)),
  ('🐯', Color(0xFFFFF3E2)),
  ('🐼', Color(0xFFEFF3F8)),
  ('🦁', Color(0xFFFDEAEA)),
];

const nicknamePool = [
  '여행하는민트42', '반값러버', '동선장인', '주말탈출러',
  '환급헌터', '한옥스테이어', '노을수집가', '로컬미식가',
];

// 거주지 선택 옵션은 lib/data/residence_options.dart(전국 17개 시도 실데이터)로 일원화했다.
// 목업 시절 축약본(6개 시도)이 여기 있어서 온보딩에 없는 지역 사용자는 가입이 막혔다.
