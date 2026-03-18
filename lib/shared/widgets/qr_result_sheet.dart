import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/scan_result.dart';
import '../../app/theme.dart';
import '../services/webview_pdf_service.dart';

class QrResultSheet extends ConsumerStatefulWidget {
  final ScanResult result;
  final bool autoSaved;

  const QrResultSheet(
      {super.key, required this.result, this.autoSaved = false});

  @override
  ConsumerState<QrResultSheet> createState() => _QrResultSheetState();
}

class _QrResultSheetState extends ConsumerState<QrResultSheet> {
  String? _savedPdfPath;

  ScanResult get result => widget.result;
  bool get autoSaved => widget.autoSaved;

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
  // WiFi QR format: WIFI:T:WPA;S:myNet;P:myPass;;
  // Special chars (;, \, ", ,) are escaped with backslash in SSID/password
  Map<String, String> _parseWifi(String raw) {
    // Matches field value allowing backslash-escaped characters
    String? extract(String key) =>
        RegExp('$key:((?:[^;\\\\]|\\\\.)*)').firstMatch(raw)?.group(1)?.replaceAllMapped(
          RegExp(r'\\(.)'),
          (m) => m.group(1)!, // unescape \; \\ \" etc.
        );
    return {
      'ssid': extract('S') ?? raw,
      'password': extract('P') ?? '',
      'security': extract('T') ?? '',
    };
  }

  // ── Launch phone/email actions ───────────────────────────────────────────
  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
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

  // ── Check & Save as PDF (hidden WebView approach) ──────────────────────────
  Future<void> _checkAndSavePdf(BuildContext context, String urlStr) async {
    if (!context.mounted) return;
    final filePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => WebViewPdfCapturePage(url: urlStr)),
    );
    if (filePath != null && mounted) {
      setState(() => _savedPdfPath = filePath);
      final openResult = await OpenFilex.open(filePath);
      if (openResult.type == ResultType.noAppToOpen && mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('No PDF viewer found')),
        );
      }
    }
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
  Widget build(BuildContext context) {
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
              // URL → Save PDF / Open PDF toggle
              // Other → Print (system print dialog with styled content)
              Expanded(
                child: _ActionButton(
                  icon: isUrl
                      ? (_savedPdfPath != null
                          ? Icons.open_in_new_rounded
                          : Icons.picture_as_pdf_rounded)
                      : Icons.print_rounded,
                  label: isUrl
                      ? (_savedPdfPath != null ? 'Open PDF' : 'Save PDF')
                      : 'Print',
                  onTap: () {
                    if (isUrl && _savedPdfPath != null) {
                      OpenFilex.open(_savedPdfPath!).then((result) {
                        if (result.type == ResultType.noAppToOpen && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No PDF viewer found')),
                          );
                        }
                      });
                    } else {
                      _savePdf(context);
                    }
                  },
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
