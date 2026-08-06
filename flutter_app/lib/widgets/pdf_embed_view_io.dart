import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

class PdfEmbedView extends StatefulWidget {
  const PdfEmbedView({
    super.key,
    required this.url,
    this.height = 640,
    this.pageCount = 1,
  });

  final String url;
  final double height;
  final int pageCount;

  @override
  State<PdfEmbedView> createState() => _PdfEmbedViewState();
}

class _PdfEmbedViewState extends State<PdfEmbedView> {
  String? _cacheKey;
  Future<_RenderedPdfDocument>? _pageFuture;

  Future<_RenderedPdfDocument> _getPageFuture({
    required String url,
    required int renderWidth,
    required int renderHeight,
    required int pageCount,
  }) {
    final cacheKey = '$url|$renderWidth|$renderHeight|$pageCount';
    if (_cacheKey != cacheKey || _pageFuture == null) {
      _cacheKey = cacheKey;
      _pageFuture = _renderPages(
        url: url,
        renderWidth: renderWidth,
        renderHeight: renderHeight,
        pageCount: pageCount,
      );
    }
    return _pageFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : widget.height / 1.414;
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final renderWidth = _clampedPixelSize(logicalWidth * pixelRatio);
        final renderHeight = _clampedPixelSize(widget.height * pixelRatio);

        return Container(
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: FutureBuilder<_RenderedPdfDocument>(
            future: _getPageFuture(
              url: widget.url,
              renderWidth: renderWidth,
              renderHeight: renderHeight,
              pageCount: widget.pageCount,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _PdfLoadingView();
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _PdfErrorView(
                  message:
                      snapshot.error?.toString() ??
                      'PDF preview failed to load.',
                );
              }

              return Column(
                children:
                    snapshot.data!.pages
                        .map(
                          (bytes) => Expanded(
                            child: Image.memory(
                              bytes,
                              width: double.infinity,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
        );
      },
    );
  }

  int _clampedPixelSize(double value) {
    return value.round().clamp(720, 2200).toInt();
  }

  Future<_RenderedPdfDocument> _renderPages({
    required String url,
    required int renderWidth,
    required int renderHeight,
    required int pageCount,
  }) async {
    final response = await http.get(_developmentFriendlyUri(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('PDF download failed: HTTP ${response.statusCode}');
    }

    final document = await PdfDocument.openData(response.bodyBytes);
    final pages = <Uint8List>[];
    try {
      final pagesToRender = pageCount.clamp(1, document.pagesCount);
      final pageRenderHeight = renderHeight / pagesToRender;
      for (var pageNumber = 1; pageNumber <= pagesToRender; pageNumber++) {
        final page = await document.getPage(pageNumber);
        try {
          final pageImage = await page.render(
            width: renderWidth.toDouble(),
            height: pageRenderHeight,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (pageImage == null) {
            throw Exception('PDF page render returned empty image.');
          }
          pages.add(pageImage.bytes);
        } finally {
          await page.close();
        }
      }
      return _RenderedPdfDocument(pages);
    } finally {
      await document.close();
    }
  }

  Uri _developmentFriendlyUri(String url) {
    final uri = Uri.parse(url);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isLocalhost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (isAndroid && isLocalhost) {
      return uri.replace(host: '10.0.2.2');
    }
    return uri;
  }
}

class _RenderedPdfDocument {
  const _RenderedPdfDocument(this.pages);

  final List<Uint8List> pages;
}

class _PdfLoadingView extends StatelessWidget {
  const _PdfLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _PdfErrorView extends StatelessWidget {
  const _PdfErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFFB91C1C),
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
