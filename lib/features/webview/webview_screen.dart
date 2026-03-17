import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../app/theme.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final bool autoSavePdf;
  const WebViewScreen({super.key, required this.url, this.autoSavePdf = false});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String _currentUrl = '';
  String _pageTitle = '';
  bool _isSavingPdf = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (url) => setState(() => _currentUrl = url),
        onPageFinished: (url) async {
          final rawTitle = await _controller
              .runJavaScriptReturningResult('document.title');
          // runJavaScriptReturningResult returns JSON-encoded value
          final title = jsonDecode(rawTitle.toString()) as String? ?? '';
          setState(() {
            _currentUrl = url;
            _pageTitle = title;
          });
          // Auto-save PDF if requested
          if (widget.autoSavePdf && mounted) {
            Future.delayed(const Duration(milliseconds: 500), _savePdf);
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _savePdf() async {
    setState(() => _isSavingPdf = true);
    try {
      final rawHtml = await _controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      // runJavaScriptReturningResult returns JSON-encoded string
      final html = jsonDecode(rawHtml.toString()) as String;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => Printing.convertHtml(
          format: format,
          html: html,
          baseUrl: Uri.tryParse(_currentUrl)?.toString(),
        ),
        name: 'QRSnap_page.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save page as PDF')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPdf = false);
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(_currentUrl);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pageTitle.isNotEmpty)
              Text(_pageTitle,
                  style: AppTextStyles.body(context)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
            else
              Text('Loading…', style: AppTextStyles.body(context)),
            Text(
              _currentUrl,
              style:
                  AppTextStyles.caption(context).copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
          ),
          _isSavingPdf
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.primary),
                  tooltip: 'Save as PDF',
                  onPressed: _savePdf,
                ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  backgroundColor: Colors.transparent,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
