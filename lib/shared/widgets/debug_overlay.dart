import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Set to true to enable the in-app debug console. Keep false in production.
const kDebugOverlayEnabled = false;

/// Simple in-app debug logger. Call [DebugLogger.log()] anywhere.
/// Wrap any widget with [DebugOverlay] to show a floating log console.
class DebugLogger extends ChangeNotifier {
  DebugLogger._();
  static final DebugLogger instance = DebugLogger._();

  final List<_LogEntry> _entries = [];
  // ignore: library_private_types_in_public_api
  List<_LogEntry> get entries => List.unmodifiable(_entries);

  static void log(String message) {
    if (!kDebugOverlayEnabled) return;
    final entry = _LogEntry(
      time: DateTime.now(),
      message: message,
    );
    instance._entries.add(entry);
    instance.notifyListeners();
    debugPrint('[DBG] $message');
  }

  static void clear() {
    instance._entries.clear();
    instance.notifyListeners();
  }
}

class _LogEntry {
  final DateTime time;
  final String message;
  _LogEntry({required this.time, required this.message});

  String get timeStr {
    final t = time;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';
  }
}

/// Wraps [child] and shows a floating draggable debug console on screen.
class DebugOverlay extends StatefulWidget {
  final Widget child;
  const DebugOverlay({super.key, required this.child});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _visible = true;
  bool _expanded = true;
  Offset _position = const Offset(0, 100);
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    DebugLogger.instance.addListener(_onLog);
  }

  @override
  void dispose() {
    DebugLogger.instance.removeListener(_onLog);
    _scroll.dispose();
    super.dispose();
  }

  void _onLog() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                _position = Offset(
                  (_position.dx + d.delta.dx).clamp(0, MediaQuery.of(context).size.width - 260),
                  (_position.dy + d.delta.dy).clamp(0, MediaQuery.of(context).size.height - 50),
                );
              }),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            const Text('DEBUG', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            const Spacer(),
                            _TitleBtn(
                              label: 'COPY',
                              onTap: () {
                                final all = DebugLogger.instance.entries
                                    .map((e) => '${e.timeStr}  ${e.message}')
                                    .join('\n');
                                Clipboard.setData(ClipboardData(text: all));
                              },
                            ),
                            const SizedBox(width: 4),
                            _TitleBtn(
                              label: 'CLR',
                              onTap: DebugLogger.clear,
                            ),
                            const SizedBox(width: 4),
                            _TitleBtn(
                              label: _expanded ? '▼' : '▲',
                              onTap: () => setState(() => _expanded = !_expanded),
                            ),
                            const SizedBox(width: 4),
                            _TitleBtn(
                              label: '✕',
                              onTap: () => setState(() => _visible = false),
                            ),
                          ],
                        ),
                      ),
                      // Log lines
                      if (_expanded)
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(6),
                            itemCount: DebugLogger.instance.entries.length,
                            itemBuilder: (_, i) {
                              final e = DebugLogger.instance.entries[i];
                              final isErr = e.message.toLowerCase().contains('error') ||
                                  e.message.toLowerCase().contains('exception') ||
                                  e.message.toLowerCase().contains('fail');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${e.timeStr} ',
                                        style: const TextStyle(color: Colors.grey, fontSize: 9, fontFamily: 'monospace'),
                                      ),
                                      TextSpan(
                                        text: e.message,
                                        style: TextStyle(
                                          color: isErr ? Colors.redAccent : Colors.greenAccent,
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TitleBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TitleBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label, style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontFamily: 'monospace')),
      ),
    );
  }
}
