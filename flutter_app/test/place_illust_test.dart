import 'package:flutter_test/flutter_test.dart';
import 'package:travel_support_mvp/mock_ui/widgets/place_illust.dart';

void main() {
  group('placeIllustKeyOf', () {
    test('이름 끝의 유형어로 분류한다', () {
      expect(placeIllustKeyOf('월출산'), 'mountain');
      expect(placeIllustKeyOf('대흥사'), 'temple');
      expect(placeIllustKeyOf('고창읍성'), 'fortress');
      expect(placeIllustKeyOf('남계서원'), 'seowon');
      expect(placeIllustKeyOf('가우도'), 'island');
      expect(placeIllustKeyOf('거연정'), 'pavilion');
    });

    test('이름 가운데 있는 유형어도 잡는다', () {
      expect(placeIllustKeyOf('강진 고려청자박물관'), 'museum');
      expect(placeIllustKeyOf('고흥우주천문과학관'), 'science');
      expect(placeIllustKeyOf('가마미해수욕장'), 'beach');
      expect(placeIllustKeyOf('갈모봉자연휴양림'), 'forest');
      expect(placeIllustKeyOf('청산도슬로길 1코스'), 'trail');
    });

    test('괄호 뒤 지역명은 무시한다', () {
      expect(placeIllustKeyOf('백련사(강진)'), 'temple');
    });

    test('짧은 유형어는 접미사일 때만 인정한다', () {
      // '정상'의 '정'이 정자로, '철도'의 '도'가 섬으로 잡히면 안 된다.
      expect(placeIllustKeyOf('가지산 정상 표지석'), 'mountain');
      expect(placeIllustKeyOf('가로내철도문화공원'), 'park');
    });

    test('좁은 유형이 넓은 유형을 이긴다', () {
      // 조각공원은 공원이 아니라 미술관 쪽.
      expect(placeIllustKeyOf('땅끝조각공원'), 'gallery');
      // 생태공원은 공원이 아니라 습지 쪽.
      expect(placeIllustKeyOf('강진만생태공원'), 'lake');
    });

    test('Dart로 옮기며 빠졌던 유형어를 잡는다', () {
      // 운영 데이터에서 폴백으로 떨어지던 10곳 — 문학관 5곳이 가장 컸다.
      expect(placeIllustKeyOf('남해유배문학관'), 'museum');
      expect(placeIllustKeyOf('영광군 도심 속 열린 수장고'), 'museum');
      expect(placeIllustKeyOf('법성포 단오제 전수교육관'), 'experience');
      expect(placeIllustKeyOf('영천전투메모리얼파크'), 'memorial');
      expect(placeIllustKeyOf('대봉산휴양밸리'), 'forest');
      expect(placeIllustKeyOf('삼랑진역 급수탑'), 'heritage');
    });

    test('유형어가 없으면 null', () {
      expect(placeIllustKeyOf('돌할매'), isNull);
      expect(placeIllustKeyOf('합천운석충돌구'), isNull);
      expect(placeIllustKeyOf(''), isNull);
    });
  });
}
