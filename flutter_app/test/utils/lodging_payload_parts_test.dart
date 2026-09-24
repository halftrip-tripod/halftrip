import 'package:flutter_test/flutter_test.dart';
import 'package:travel_support_mvp/utils/lodging_payload_parts.dart';

void main() {
  const payload = <String, dynamic>{
    'traveler_phone_number': '010-7245-0350',
    'phone_number': '01012345678',
    'trip_date_range': '2026-05-01 ~ 2026-05-03',
    'payment_date': '2026-05-01',
    'agreed_personal_info': true,
  };

  test('전화번호 조각은 원래 번호에서 자른다', () {
    expect(derivePayloadPart('traveler_phone_mid', payload), '7245');
    expect(derivePayloadPart('traveler_phone_last', payload), '0350');
    expect(derivePayloadPart('phone_number_mid', payload), '1234');
    expect(derivePayloadPart('traveler_phone_tail', payload), '7245-0350');
  });

  test('날짜 조각은 원래 날짜·기간에서 자른다', () {
    expect(derivePayloadPart('payment_date_month', payload), '5');
    expect(derivePayloadPart('trip_date_range_start_day', payload), '1');
    expect(derivePayloadPart('trip_date_range_end_day', payload), '3');
    expect(derivePayloadPart('confirmation_date_month', payload), '');
  });

  test('저장된 값이 있으면 그대로 쓴다', () {
    expect(initialTextValue('traveler_phone_mid', {...payload, 'traveler_phone_mid': '9999'}), '9999');
    expect(initialCheckboxValue('agreed_personal_info_yes', payload), isTrue);
    expect(initialCheckboxValue('agreed_personal_info_no', payload), isFalse);
  });

  test('숙박기간은 양식 예시 형식으로 줄인다', () {
    expect(compactRange('2026-10-03 ~ 2026-10-05'), '10.3 ~ 10.5(2박)');
    expect(initialTextValue('trip_date_range', payload), '5.1 ~ 5.3(2박)');
    expect(compactRange('5.1 ~ 5.2(1박)'), '5.1 ~ 5.2(1박)');
  });
}
