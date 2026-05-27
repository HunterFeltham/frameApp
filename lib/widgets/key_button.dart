import 'package:flutter/material.dart';
import '../models/jam_key.dart';

/// Amber/orange — used for concert key text throughout the app.
const Color kConcertColor = Color(0xFFFF9500);

/// Cyan — used for alto sax written key text throughout the app.
const Color kAltoColor = Color(0xFF00D4FF);

/// Large, high-contrast tap target showing a concert key / alto key pair.
///
/// Designed for one-handed use in a dimly lit jam room:
///   • Minimum touch target: entire button cell
///   • Two-tone text (orange = concert, cyan = alto) readable at arm's length
///   • Animated border glow when selected
class KeyButton extends StatelessWidget {
  final JamKey jamKey;
  final bool isSelected;
  final VoidCallback onTap;

  const KeyButton({
    super.key,
    required this.jamKey,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF252550) : const Color(0xFF1C1C3A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kConcertColor : const Color(0xFF38385A),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kConcertColor.withOpacity(0.30),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : const [],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Concert ${jamKey.concertKey}',
                    style: const TextStyle(
                      color: kConcertColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Alto ${jamKey.altoKey}',
                    style: const TextStyle(
                      color: kAltoColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
