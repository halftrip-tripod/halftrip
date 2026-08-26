import 'package:flutter/material.dart';

class PdfEmbedView extends StatelessWidget {
  const PdfEmbedView({
    super.key,
    required this.url,
    this.height = 640,
    this.pageCount = 1,
    this.authToken,
  });

  final String url;
  final double height;
  final int pageCount;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Text(
        '이 플랫폼에서는 PDF 내장 미리보기를 지원하지 않습니다.\n$url',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
