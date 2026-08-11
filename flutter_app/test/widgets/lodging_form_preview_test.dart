import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_support_mvp/models/app_models.dart';
import 'package:travel_support_mvp/widgets/lodging_form_preview.dart';

void main() {
  testWidgets('layout edit mode moves and resizes a PDF field', (tester) async {
    const field = LodgingFormFieldItem(
      key: 'traveler_name',
      label: '신청자명',
      type: 'text',
      x: 100,
      y: 120,
      width: 180,
      height: 48,
      editable: true,
      multiline: false,
      helperText: '',
    );
    final updates = <LodgingFormFieldItem>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: LodgingFormPreview(
              formData: const LodgingFormData(
                tripId: 1,
                regionName: '완도',
                template: LodgingFormTemplateItem(
                  templateId: 1,
                  templateKey: 'wando',
                  templateName: 'stay_confirm_wando.pdf',
                  sourceFormat: 'PDF',
                  previewTitle: '숙박확인서',
                  previewSubtitle: '',
                  fields: [field],
                  notes: [],
                ),
                instance: LodgingFormInstanceItem(
                  instanceId: null,
                  status: 'DRAFT',
                  payload: {'traveler_name': '홍길동'},
                  lastSavedAt: null,
                  renderedPdfFileName: null,
                ),
                todos: [],
              ),
              onTapSignature: () {},
              templatePdfUrl: 'https://example.com/stay-confirm.pdf',
              layoutEditMode: true,
              selectedFieldKey: 'traveler_name',
              onSelectField: (_) {},
              onUpdateField: updates.add,
            ),
          ),
        ),
      ),
    );

    final moveDetector = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('lodging-field-traveler_name')),
    );
    moveDetector.onPanUpdate!(
      DragUpdateDetails(
        globalPosition: const Offset(160, 160),
        delta: const Offset(16, 10),
      ),
    );

    expect(updates, isNotEmpty);
    expect(updates.last.x, greaterThan(field.x + 60));
    expect(updates.last.y, greaterThan(field.y + 40));

    updates.clear();
    final resizeDetector = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('lodging-field-resize-traveler_name')),
    );
    resizeDetector.onPanUpdate!(
      DragUpdateDetails(
        globalPosition: const Offset(260, 190),
        delta: const Offset(16, 10),
      ),
    );

    expect(updates, isNotEmpty);
    expect(updates.last.width, greaterThan(field.width));
    expect(updates.last.height, greaterThan(field.height));
  });

  testWidgets('checkbox remains tappable when editable is false', (
    tester,
  ) async {
    const field = LodgingFormFieldItem(
      key: 'agreed_stay_proof',
      label: 'Stay proof confirmed',
      type: 'checkbox',
      x: 120,
      y: 160,
      width: 24,
      height: 24,
      editable: false,
      multiline: false,
      helperText: '',
    );
    LodgingFormFieldItem? tappedField;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: LodgingFormPreview(
              formData: const LodgingFormData(
                tripId: 1,
                regionName: 'Wando',
                template: LodgingFormTemplateItem(
                  templateId: 1,
                  templateKey: 'wando',
                  templateName: 'stay_confirm_wando.pdf',
                  sourceFormat: 'PDF',
                  previewTitle: 'Lodging confirmation',
                  previewSubtitle: '',
                  fields: [field],
                  notes: [],
                ),
                instance: LodgingFormInstanceItem(
                  instanceId: null,
                  status: 'DRAFT',
                  payload: {'agreed_stay_proof': false},
                  lastSavedAt: null,
                  renderedPdfFileName: null,
                ),
                todos: [],
              ),
              onTapSignature: () {},
              onTapField: (value) => tappedField = value,
              templatePdfUrl: 'https://example.com/stay-confirm.pdf',
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('lodging-field-tap-agreed_stay_proof')),
    );

    expect(tappedField?.key, field.key);
  });

  testWidgets('read-only repeated PDF value remains visible', (tester) async {
    const field = LodgingFormFieldItem(
      key: 'lodging_name_bottom',
      label: 'Repeated lodging name',
      type: 'text',
      x: 404,
      y: 586,
      width: 175,
      height: 27,
      editable: false,
      multiline: false,
      helperText: '',
    );
    LodgingFormFieldItem? tappedField;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: LodgingFormPreview(
              formData: const LodgingFormData(
                tripId: 2,
                regionName: 'Gangjin',
                template: LodgingFormTemplateItem(
                  templateId: 2,
                  templateKey: 'gangjin',
                  templateName: 'stay_confirm_gangjin.pdf',
                  sourceFormat: 'PDF',
                  previewTitle: 'Lodging confirmation',
                  previewSubtitle: '',
                  fields: [field],
                  notes: [],
                ),
                instance: LodgingFormInstanceItem(
                  instanceId: null,
                  status: 'DRAFT',
                  payload: {'lodging_name_bottom': 'Gangjin Stay'},
                  lastSavedAt: null,
                  renderedPdfFileName: null,
                ),
                todos: [],
              ),
              onTapSignature: () {},
              onTapField: (value) => tappedField = value,
              templatePdfUrl: 'https://example.com/stay-confirm.pdf',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Gangjin Stay'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('lodging-field-tap-lodging_name_bottom')),
    );
    expect(tappedField?.key, field.key);
  });

  testWidgets('two-page regional template uses a scrollable full height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 390,
              child: LodgingFormPreview(
                formData: const LodgingFormData(
                  tripId: 2,
                  regionName: 'Gangjin',
                  template: LodgingFormTemplateItem(
                    templateId: 2,
                    templateKey: 'gangjin',
                    templateName: 'stay_confirm_gangjin.pdf',
                    sourceFormat: 'PDF',
                    previewTitle: 'Lodging confirmation',
                    previewSubtitle: '',
                    fields: [],
                    notes: [],
                  ),
                  instance: LodgingFormInstanceItem(
                    instanceId: null,
                    status: 'DRAFT',
                    payload: {},
                    lastSavedAt: null,
                    renderedPdfFileName: null,
                  ),
                  todos: [],
                ),
                onTapSignature: () {},
                templatePdfUrl: 'https://example.com/stay-confirm.pdf',
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(LodgingFormPreview)).height,
      greaterThan(1000),
    );
  });

  testWidgets('signature payload is rendered as strokes', (tester) async {
    const field = LodgingFormFieldItem(
      key: 'host_signature',
      label: 'Host signature',
      type: 'signature',
      x: 545,
      y: 638,
      width: 90,
      height: 42,
      editable: true,
      multiline: false,
      helperText: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: LodgingFormPreview(
              formData: const LodgingFormData(
                tripId: 2,
                regionName: 'Gangjin',
                template: LodgingFormTemplateItem(
                  templateId: 2,
                  templateKey: 'gangjin',
                  templateName: 'stay_confirm_gangjin.pdf',
                  sourceFormat: 'PDF',
                  previewTitle: 'Lodging confirmation',
                  previewSubtitle: '',
                  fields: [field],
                  notes: [],
                ),
                instance: LodgingFormInstanceItem(
                  instanceId: null,
                  status: 'DRAFT',
                  payload: {
                    'host_signature': '[{"x":10,"y":20},{"x":40,"y":50},null]',
                  },
                  lastSavedAt: null,
                  renderedPdfFileName: null,
                ),
                todos: [],
              ),
              onTapSignature: () {},
              templatePdfUrl: 'https://example.com/stay-confirm.pdf',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('lodging-signature-strokes')), findsOne);
    expect(find.text('Signed'), findsNothing);
  });
}
