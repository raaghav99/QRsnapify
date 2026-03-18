import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/scan_result.dart';
import '../../app/theme.dart';
import 'pdf_fetch_loader.dart';

class QrResultSheet extends ConsumerWidget {
  final ScanResult result;
  final bool autoSaved;

  const QrResultSheet(
      {super.key, required this.result, this.autoSaved = false});

  IconData _typeIcon(QRType type) => switch (type) {
        QRType.url => Iconsax.link,
        QRType.email => Iconsax.message,
        QRType.phone => Iconsax.call,
        QRType.wifi => Iconsax.wifi,
        QRType.text => Iconsax.document_text,
      };

  String _typeLabel(QRType type) => switch (type) {
        QRType.url => 'Website URL',
        QRType.email => 'Email Address',
        QRType.phone => 'Phone Number',
        QRType.wifi => 'WiFi Network',
        QRType.text => 'Plain Text',
      };

  // ── WiFi content parser ──────────────────────────────────────────────────
  Map<String, String> _parseWifi(String raw) {
    final ssid = RegExp(r'S:([^;]*)').firstMatch(raw)?.group(1) ?? raw;
    final password = RegExp(r'P:([^;]*)').firstMatch(raw)?.group(1) ?? '';
    final security = RegExp(r'T:([^;]*)').firstMatch(raw)?.group(1) ?? '';
    return {'ssid': ssid, 'password': password, 'security': security};
  }

  // ── Launch phone/email actions ───────────────────────────────────────────
  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri);
  }

  // ── Internal Security Check (VirusTotal-like) ────────────────────────────
  Future<Map<String, dynamic>> _securityCheck(String url) async {
    final lowerUrl = url.toLowerCase();
    final warnings = <String>[];
    bool isSafe = true;

    // Check 1: HTTPS vs HTTP
    if (lowerUrl.startsWith('http://')) {
      warnings.add('⚠️ Not encrypted (HTTP)');
      isSafe = false;
    }

    // Check 2: Suspicious shortened URLs
    if (lowerUrl.contains('bit.ly') || lowerUrl.contains('tinyurl') ||
        lowerUrl.contains('bitly') || lowerUrl.contains('bit.') ||
        lowerUrl.contains('short.link') || lowerUrl.contains('ow.ly')) {
      warnings.add('⚠️ Shortened URL (can hide true destination)');
    }

    // Check 3: Suspicious TLDs
    if (lowerUrl.endsWith('.tk') || lowerUrl.endsWith('.ml') ||
        lowerUrl.endsWith('.ga') || lowerUrl.endsWith('.cf')) {
      warnings.add('⚠️ Uncommon domain extension');
    }

    // Check 4: Very new domains (< 1 month old, heuristic)
    if (!lowerUrl.contains('www.') && lowerUrl.split('.').length == 2) {
      // Simple domain without subdomain might be new
      final domain = lowerUrl.split('://').last.split('/').first;
      if (!_isKnownDomain(domain)) {
        warnings.add('ℹ️ New or less common domain');
      }
    }

    // Check 5: IP-based URLs (often malicious)
    if (RegExp(r'://([\d]{1,3}\.){3}[\d]{1,3}').hasMatch(url)) {
      warnings.add('⚠️ Direct IP address (unusual)');
      isSafe = false;
    }

    // Check 6: Suspicious keywords
    final maliciousKeywords = [
      'free-money', 'click-here', 'verify-account', 'confirm-password',
      'update-payment', 'suspended', 'urgent-action', 'claim-prize',
      'congratulations-won', 'bank-login', 'paypal-login', 'amazon-login'
    ];
    if (maliciousKeywords.any((kw) => lowerUrl.contains(kw))) {
      warnings.add('⚠️ Suspicious keywords detected');
      isSafe = false;
    }

    // Check 7: Homograph attacks (lookalike domains)
    if (_isHomographAttack(lowerUrl)) {
      warnings.add('⚠️ Domain looks like popular site');
      isSafe = false;
    }

    final isActuallySafe = isSafe && warnings.isEmpty;
    return {
      'isSafe': isActuallySafe,
      'warnings': warnings,
      'severity': isActuallySafe ? 'safe' : 'warning',
    };
  }

  bool _isKnownDomain(String domain) {
    // Common safe domains
    final knownDomains = [
      'google.com', 'facebook.com', 'youtube.com', 'github.com',
      'stackoverflow.com', 'reddit.com', 'twitter.com', 'linkedin.com',
      'wikipedia.org', 'amazon.com', 'ebay.com', 'microsoft.com',
      'apple.com', 'gmail.com', 'outlook.com', 'flutter.dev',
      'dart.dev', 'firebase.google.com'
    ];
    return knownDomains.contains(domain);
  }

  bool _isHomographAttack(String url) {
    // Check for domain lookalikes
    final lowerUrl = url.toLowerCase();
    final lookalikes = [
      ('paypa1.com', 'paypal.com'),
      ('amazo n.com', 'amazon.com'),
      ('goggle.com', 'google.com'),
    ];
    return lookalikes.any((pair) => lowerUrl.contains(pair.$1));
  }

  // ── Shared security warning widget ───────────────────────────────────────
  Widget _buildSecurityContent(
      BuildContext context, List<String> warnings, bool isSafe, String urlStr) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(w,
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.start),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('No threats detected',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.success)),
                    ),
                  ],
                ),
              ),
            ),
          const Text('URL:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgColor(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.textSubColor(context).withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              urlStr,
              style: const TextStyle(fontSize: 11),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Show open-URL dialog (security check → open in browser) ──────────────
  Future<void> _showOpenUrlDialog(BuildContext context, String urlStr) async {
    if (!context.mounted) return;

    final securityResult = await _securityCheck(urlStr);
    final warnings = securityResult['warnings'] as List<String>;
    final isSafe = securityResult['isSafe'] as bool;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSafe ? Icons.shield_rounded : Icons.warning_rounded,
              color: isSafe ? AppColors.success : AppColors.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(isSafe ? 'Safe to open' : 'Security warnings'),
            ),
          ],
        ),
        content: _buildSecurityContent(context, warnings, isSafe, urlStr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl(context, urlStr);
            },
            child: const Text('Open',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── Show PDF-save dialog (security check → save PDF) ─────────────────────
  Future<void> _showUrlDialog(BuildContext context, String urlStr) async {
    if (!context.mounted) return;

    final securityResult = await _securityCheck(urlStr);
    final warnings = securityResult['warnings'] as List<String>;
    final isSafe = securityResult['isSafe'] as bool;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSafe ? Icons.shield_rounded : Icons.warning_rounded,
              color: isSafe ? AppColors.success : AppColors.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(isSafe ? 'Safe to proceed' : 'Security warnings'),
            ),
          ],
        ),
        content: _buildSecurityContent(context, warnings, isSafe, urlStr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkAndSavePdf(context, urlStr);
            },
            child: const Text('Save PDF',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── Check & Save as PDF (without opening browser) ─────────────────────────
  Future<void> _checkAndSavePdf(BuildContext context, String urlStr) async {
    if (!context.mounted) return;

    PdfFetchLoader.show(context);
    debugPrint('[PDF] === Starting PDF save for: $urlStr ===');

    try {
      // Stage 1: Connect
      PdfFetchLoader.updateProgress(0.05, stage: 'Connecting');
      debugPrint('[PDF] Stage 1: Connecting...');

      final uri = Uri.parse(urlStr);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..badCertificateCallback = (_, __, ___) => false;

      final request = await client.getUrl(uri);
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/91.0.4472.120 Mobile Safari/537.36',
      );
      request.headers.set('Accept', 'text/html,application/xhtml+xml');
      request.headers.set('Accept-Language', 'en-US,en;q=0.9');
      debugPrint('[PDF] Request sent, waiting for response...');

      // Stage 2: Download with live progress
      PdfFetchLoader.updateProgress(0.1, stage: 'Waiting for server');
      final response = await request.close();
      debugPrint('[PDF] Response: ${response.statusCode}');

      final contentLength = response.headers.contentLength;
      debugPrint('[PDF] Content-Length: $contentLength');

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        // Live download progress: 10% to 50%
        if (contentLength > 0) {
          final dlProgress = 0.1 + (bytes.length / contentLength) * 0.4;
          final kb = (bytes.length / 1024).toStringAsFixed(0);
          final totalKb = (contentLength / 1024).toStringAsFixed(0);
          PdfFetchLoader.updateProgress(
              dlProgress.clamp(0.1, 0.5), stage: 'Downloading ${kb}KB / ${totalKb}KB');
        } else {
          final kb = (bytes.length / 1024).toStringAsFixed(0);
          PdfFetchLoader.updateProgress(0.3, stage: 'Downloading ${kb}KB');
        }
      }
      client.close();
      debugPrint('[PDF] Downloaded ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(1)}KB)');

      // Stage 3: Decode HTML
      PdfFetchLoader.updateProgress(0.55, stage: 'Processing');
      debugPrint('[PDF] Stage 3: Decoding HTML...');

      String html;
      final contentType = response.headers.contentType;
      final charset = contentType?.charset ?? 'utf-8';
      debugPrint('[PDF] charset: $charset');
      try {
        html = charset.toLowerCase() == 'utf-8' || charset.toLowerCase() == 'utf8'
            ? utf8.decode(bytes, allowMalformed: true)
            : latin1.decode(bytes);
      } catch (_) {
        html = utf8.decode(bytes, allowMalformed: true);
      }
      debugPrint('[PDF] HTML: ${html.length} chars');

      // JS-check
      final isJsOnly = html.contains('<noscript') ||
          (html.contains('<body') &&
              html.indexOf('<body') > html.lastIndexOf('</body>') - 200);
      debugPrint('[PDF] JS-only: $isJsOnly');
      if (isJsOnly && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This page may require JavaScript — PDF might be incomplete'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Stage 4: Convert to PDF with timeout
      if (!context.mounted) {
        debugPrint('[PDF] Context unmounted, aborting');
        PdfFetchLoader.dismiss(context);
        return;
      }
      PdfFetchLoader.updateProgress(0.6, stage: 'Rendering PDF');
      debugPrint('[PDF] Stage 4: Printing.convertHtml starting...');

      Uint8List? pdfBytes;
      try {
        pdfBytes = await Printing.convertHtml(
          format: PdfPageFormat.a4,
          html: html,
          baseUrl: uri.toString(),
        ).timeout(const Duration(seconds: 20));
        debugPrint('[PDF] convertHtml done: ${pdfBytes.length} bytes');
      } catch (e) {
        debugPrint('[PDF] convertHtml failed/timed out: $e');
        debugPrint('[PDF] Falling back to text-based PDF...');
        // Fallback: create a simple text PDF with the page content
        pdfBytes = await _buildFallbackPdf(urlStr, html);
        debugPrint('[PDF] Fallback PDF: ${pdfBytes.length} bytes');
      }

      // Stage 5: Save
      PdfFetchLoader.updateProgress(0.9, stage: 'Saving');
      debugPrint('[PDF] Stage 5: Writing file...');

      final dir = await getTemporaryDirectory();
      final fileName = 'QRSnap_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      debugPrint('[PDF] Saved: ${file.path}');

      // Done — show result, then share
      if (context.mounted) {
        await PdfFetchLoader.showResult(context,
            result: PdfFetchResult.success, filePath: fileName);
        debugPrint('[PDF] Opening share sheet...');
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'QRSnap saved page',
        );
        debugPrint('[PDF] === Complete ===');
      }
    } on SocketException catch (e) {
      debugPrint('[PDF] SocketException: $e');
      if (context.mounted) {
        await PdfFetchLoader.showResult(context,
            result: PdfFetchResult.networkError);
      }
    } catch (e, stack) {
      debugPrint('[PDF] FATAL: $e');
      debugPrint('[PDF] Stack: $stack');
      if (context.mounted) {
        await PdfFetchLoader.showResult(context,
            result: PdfFetchResult.timeout);
      }
    }
  }

  // ── Fallback: text-based PDF when convertHtml fails ─────────────────────────
  Future<Uint8List> _buildFallbackPdf(String url, String html) async {
    // Strip HTML tags to extract readable text
    final text = html
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final doc = pw.Document();
    // Split into chunks that fit on pages (~3000 chars per page)
    final chunks = <String>[];
    for (var i = 0; i < text.length; i += 3000) {
      chunks.add(text.substring(i, i + 3000 > text.length ? text.length : i + 3000));
    }
    if (chunks.isEmpty) chunks.add('(Empty page)');

    for (var i = 0; i < chunks.length && i < 20; i++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (i == 0) ...[
              pw.Text(url,
                  style: pw.TextStyle(
                      fontSize: 10, color: PdfColors.blue800,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),
            ],
            pw.Text(chunks[i], style: const pw.TextStyle(fontSize: 10)),
            pw.Spacer(),
            pw.Text('Page ${i + 1} — QRSnap',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ));
    }
    return doc.save();
  }

  // ── Open URL in external browser (system chooser) ───────────────────────
  Future<void> _openUrl(BuildContext context, String urlStr) async {
    if (!context.mounted) return;
    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Save as PDF ──────────────────────────────────────────────────────────
  Future<void> _savePdf(BuildContext context) async {
    if (result.type == QRType.url) {
      // For URLs: show security dialog first
      var urlStr = result.content;
      if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
        urlStr = 'https://$urlStr';
      }
      await _showUrlDialog(context, urlStr);
      return;
    }

    // For all other types: generate a styled content PDF directly
    try {
      final doc = pw.Document();
      final typeStr = _typeLabel(result.type);

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Type badge
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo400,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(
                typeStr,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            // Content
            pw.Text(
              result.content,
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 6),
            pw.Text(
              'Generated by QRSnap',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ));

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'QRSnap_${result.type.name}.pdf',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate PDF')),
        );
      }
    }
  }

  // ── WiFi structured display ──────────────────────────────────────────────
  Widget _buildWifiPreview(BuildContext context) {
    final wifi = _parseWifi(result.content);
    final rows = <Widget>[];

    void addRow(String label, String value) {
      if (value.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: AppTextStyles.caption(context)
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(value,
                  style: AppTextStyles.body(context),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ));
    }

    addRow('Network', wifi['ssid'] ?? '');
    addRow('Password', wifi['password'] ?? '');
    if ((wifi['security'] ?? '').isNotEmpty && wifi['security'] != 'nopass') {
      addRow('Security', wifi['security'] ?? '');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.isEmpty
          ? [Text(result.content, style: AppTextStyles.body(context))]
          : rows,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isUrl = result.type == QRType.url;

    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg,
          AppSpacing.xl, AppSpacing.xxl + bottomPadding),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    AppColors.textSubColor(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(AppSpacing.lg),
          // Type header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.chipRadius,
                ),
                child: Icon(_typeIcon(result.type),
                    color: AppColors.primary, size: 20),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Text(_typeLabel(result.type),
                    style: AppTextStyles.subheading(context)),
              ),
              if (autoSaved)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Saved',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const Gap(AppSpacing.md),
          // Content preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgColor(context),
              borderRadius: AppRadius.chipRadius,
            ),
            child: result.type == QRType.wifi
                ? _buildWifiPreview(context)
                : Text(
                    result.content,
                    style: AppTextStyles.body(context),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const Gap(AppSpacing.lg),
          // Action buttons
          Row(
            children: [
              // Copy — always
              Expanded(
                child: _ActionButton(
                  icon: Iconsax.copy,
                  label: 'Copy',
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: result.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ),
              // Open — URL only (security check → open in WebView)
              if (isUrl) ...[
                const Gap(AppSpacing.sm),
                Expanded(
                  child: _ActionButton(
                    icon: Iconsax.export,
                    label: 'Open',
                    onTap: () {
                      var urlStr = result.content;
                      if (!urlStr.startsWith('http://') &&
                          !urlStr.startsWith('https://')) {
                        urlStr = 'https://$urlStr';
                      }
                      _showOpenUrlDialog(context, urlStr);
                    },
                  ),
                ),
              ],
              // Call — phone only
              if (result.type == QRType.phone) ...[
                const Gap(AppSpacing.sm),
                Expanded(
                  child: _ActionButton(
                    icon: Iconsax.call,
                    label: 'Call',
                    onTap: () {
                      var tel = result.content;
                      if (!tel.startsWith('tel:')) tel = 'tel:$tel';
                      _launchUrl(tel);
                    },
                  ),
                ),
              ],
              // Email — email only
              if (result.type == QRType.email) ...[
                const Gap(AppSpacing.sm),
                Expanded(
                  child: _ActionButton(
                    icon: Iconsax.message,
                    label: 'Email',
                    onTap: () {
                      var mail = result.content;
                      if (!mail.startsWith('mailto:')) mail = 'mailto:$mail';
                      _launchUrl(mail);
                    },
                  ),
                ),
              ],
              const Gap(AppSpacing.sm),
              // Share — always
              Expanded(
                child: _ActionButton(
                  icon: Iconsax.send_2,
                  label: 'Share',
                  onTap: () => Share.share(result.content),
                ),
              ),
              const Gap(AppSpacing.sm),
              // URL → Save PDF (download + convert, no browser)
              // Other → Print (system print dialog with styled content)
              Expanded(
                child: _ActionButton(
                  icon: isUrl ? Icons.picture_as_pdf_rounded : Icons.print_rounded,
                  label: isUrl ? 'Save PDF' : 'Print',
                  onTap: () => _savePdf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.buttonRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgColor(context),
          borderRadius: AppRadius.buttonRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const Gap(4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSubColor(context))),
          ],
        ),
      ),
    );
  }
}
