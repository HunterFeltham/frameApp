import 'package:flutter/material.dart';
import '../models/jam_key.dart';
import '../services/frame_service.dart';
import 'key_button.dart' show kConcertColor, kAltoColor;

/// Expandable card shown at the bottom of the screen when a key is selected.
///
/// Displays:
///   • Concert key and alto key labels in two-tone text
///   • Full major scale notes
///   • Major pentatonic notes
///   • Send-to-Frame icon button (disabled when disconnected)
///   • Copy-to-clipboard icon button
///   • Subtle "Not sent: Frame disconnected" hint when applicable
class SelectedKeyCard extends StatelessWidget {
  final JamKey jamKey;
  final FrameService frameService;
  final VoidCallback onSendToFrame;
  final VoidCallback onCopy;

  const SelectedKeyCard({
    super.key,
    required this.jamKey,
    required this.frameService,
    required this.onSendToFrame,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF18183A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF38386A), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF303055), height: 1),
            const SizedBox(height: 12),
            _label('Major scale (alto written):'),
            const SizedBox(height: 5),
            _notesText(jamKey.altoMajorNotesDisplay, size: 22, color: Colors.white),
            const SizedBox(height: 14),
            _label('Major pentatonic:'),
            const SizedBox(height: 5),
            _notesText(
              jamKey.altoPentatonicDisplay,
              size: 20,
              color: Colors.greenAccent.shade200,
            ),
            if (frameService.lastSendFailed) ...[
              const SizedBox(height: 10),
              Text(
                'Not sent: Frame disconnected',
                style: TextStyle(
                  color: Colors.redAccent.withOpacity(0.75),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                jamKey.concertLabel,
                style: const TextStyle(
                  color: kConcertColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                jamKey.altoLabel,
                style: const TextStyle(
                  color: kAltoColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            // Send to Frame
            IconButton(
              onPressed: frameService.isConnected ? onSendToFrame : null,
              icon: const Icon(Icons.remove_red_eye),
              color: frameService.isConnected
                  ? Colors.cyanAccent
                  : Colors.grey.shade700,
              iconSize: 28,
              tooltip: frameService.isConnected ? 'Send to Frame' : 'Frame not connected',
              splashRadius: 24,
            ),
            // Copy to clipboard
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              color: Colors.white60,
              iconSize: 24,
              tooltip: 'Copy notes to clipboard',
              splashRadius: 22,
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _notesText(String notes, {required double size, required Color color}) =>
      Text(
        notes,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
          height: 1.2,
        ),
      );
}
