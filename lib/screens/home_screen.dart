import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/key_data.dart';
import '../models/jam_key.dart';
import '../services/frame_service.dart';
import '../widgets/key_button.dart';
import '../widgets/selected_key_card.dart';

/// Main screen of Alto Jam Key Helper.
///
/// Layout (top → bottom):
///   AppBar         – title + Frame connection status bar
///   Key grid       – 3-column grid of 12 concert/alto key buttons
///   Selected card  – large note display, Frame send, clipboard copy
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  JamKey? _selectedKey;

  void _onKeyTap(JamKey key) {
    setState(() => _selectedKey = key);
    // Auto-send to Frame on tap if connected (fire-and-forget; errors surfaced
    // via FrameService.lastSendFailed, not an exception here).
    context.read<FrameService>().sendText(key.frameDisplayText);
  }

  @override
  Widget build(BuildContext context) {
    final frame = context.watch<FrameService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D20),
        elevation: 0,
        title: const Text(
          'Alto Jam Key Helper',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 19,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _ConnectionBar(frame: frame),
        ),
      ),
      body: Column(
        children: [
          // Key grid – fills available space
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.15,
              ),
              itemCount: kJamKeys.length,
              itemBuilder: (ctx, i) {
                final key = kJamKeys[i];
                return KeyButton(
                  jamKey: key,
                  isSelected: _selectedKey?.concertKey == key.concertKey,
                  onTap: () => _onKeyTap(key),
                );
              },
            ),
          ),

          // Selected key card – visible only after a key is tapped
          if (_selectedKey != null)
            SelectedKeyCard(
              key: ValueKey(_selectedKey!.concertKey),
              jamKey: _selectedKey!,
              frameService: frame,
              onSendToFrame: () => frame.sendText(_selectedKey!.frameDisplayText),
              onCopy: () => _copyToClipboard(_selectedKey!),
            ),
        ],
      ),
    );
  }

  void _copyToClipboard(JamKey key) {
    final text = '${key.concertLabel} → ${key.altoLabel}\n'
        '${key.altoMajorNotesDisplay}\n'
        'Pentatonic: ${key.altoPentatonicDisplay}';
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notes copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Connection status bar ──────────────────────────────────────────────────────

class _ConnectionBar extends StatelessWidget {
  final FrameService frame;
  const _ConnectionBar({required this.frame});

  @override
  Widget build(BuildContext context) {
    final Color dot = switch (frame.status) {
      FrameConnectionStatus.connected => Colors.greenAccent,
      FrameConnectionStatus.connecting => Colors.orangeAccent,
      FrameConnectionStatus.disconnected => Colors.redAccent.shade100,
    };

    final String label =
        frame.lastError != null && frame.status == FrameConnectionStatus.disconnected
            ? frame.lastError!
            : frame.statusLabel;

    return Container(
      color: const Color(0xFF0D0D20),
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
      child: Row(
        children: [
          // Pulsing status dot
          _StatusDot(color: dot, pulsing: frame.status == FrameConnectionStatus.connecting),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: dot,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _ConnectButton(frame: frame),
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulsing;
  const _StatusDot({required this.color, required this.pulsing});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final FrameService frame;
  const _ConnectButton({required this.frame});

  @override
  Widget build(BuildContext context) {
    if (frame.status == FrameConnectionStatus.connecting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
      );
    }
    return TextButton(
      onPressed: frame.isConnected ? frame.disconnect : frame.connect,
      style: TextButton.styleFrom(
        foregroundColor: frame.isConnected ? Colors.redAccent : Colors.greenAccent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      child: Text(frame.isConnected ? 'Disconnect' : 'Connect Frame'),
    );
  }
}
