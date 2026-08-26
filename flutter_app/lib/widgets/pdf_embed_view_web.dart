import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PdfEmbedView extends StatefulWidget {
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

  /// 보호된 PDF(채워진 숙박확인서 등)를 열 때 실어 보낼 세션 토큰.
  /// 공개 서식(template-pdf)에는 없어도 되지만 있어도 무방하다.
  final String? authToken;

  @override
  State<PdfEmbedView> createState() => _PdfEmbedViewState();
}

class _PdfEmbedViewState extends State<PdfEmbedView> {
  static int _nextViewId = 0;

  String? _blobUrl;
  String? _viewType;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void didUpdateWidget(covariant PdfEmbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _releaseBlobUrl();
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _viewType = null;
    });

    try {
      final token = widget.authToken;
      final response = await http.get(
        Uri.parse(widget.url),
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _PdfLoadException(response.statusCode);
      }

      final blob = html.Blob(<Object>[response.bodyBytes], 'application/pdf');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final viewType = 'pdf-embed-web-${_nextViewId++}';

      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        return html.IFrameElement()
          ..src = '$blobUrl#toolbar=0&navpanes=0&scrollbar=0&view=FitH'
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.pointerEvents = 'none';
      });

      if (!mounted) {
        html.Url.revokeObjectUrl(blobUrl);
        return;
      }

      _releaseBlobUrl();
      setState(() {
        _blobUrl = blobUrl;
        _viewType = viewType;
        _loading = false;
      });
    } on _PdfLoadException catch (error) {
      _showError('PDF를 불러오지 못했습니다. (HTTP ${error.statusCode})');
    } catch (_) {
      _showError('PDF를 불러오지 못했습니다. 서버 연결을 확인해 주세요.');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _viewType = null;
      _errorMessage = message;
    });
  }

  void _releaseBlobUrl() {
    final blobUrl = _blobUrl;
    if (blobUrl != null) {
      html.Url.revokeObjectUrl(blobUrl);
      _blobUrl = null;
    }
  }

  @override
  void dispose() {
    _releaseBlobUrl();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF475569)),
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType!);
  }
}

class _PdfLoadException implements Exception {
  const _PdfLoadException(this.statusCode);

  final int statusCode;
}
