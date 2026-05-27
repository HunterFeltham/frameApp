// Unit tests for key mappings, scale notes, pentatonic notes, and Frame text.
// No physical Frame hardware required.

import 'package:flutter_test/flutter_test.dart';
import 'package:alto_jam_key_helper/data/key_data.dart';
import 'package:alto_jam_key_helper/models/jam_key.dart';

void main() {
  // ── Concert-to-alto mapping ───────────────────────────────────────────────

  group('Concert-to-alto key mappings', () {
    test('All 12 keys are present', () {
      expect(kJamKeys.length, 12);
    });

    final expectedMappings = {
      'C': 'A',
      'G': 'E',
      'D': 'B',
      'A': 'F#',
      'E': 'C#',
      'F': 'D',
      'Bb': 'G',
      'Eb': 'C',
      'Ab': 'F',
      'Db': 'Bb',
      'Gb': 'Eb',
      'B': 'G#',
    };

    for (final entry in expectedMappings.entries) {
      test('Concert ${entry.key} → Alto ${entry.value}', () {
        expect(_key(entry.key).altoKey, entry.value);
      });
    }
  });

  // ── Alto major scale notes ────────────────────────────────────────────────

  group('Alto major scale notes', () {
    test('Every key has exactly 8 notes (7 unique + octave repeat)', () {
      for (final k in kJamKeys) {
        expect(k.altoMajorNotes.length, 8,
            reason: 'Alto ${k.altoKey} major should have 8 notes');
      }
    });

    test('First and last note of each scale are the same pitch class', () {
      for (final k in kJamKeys) {
        expect(
          k.altoMajorNotes.first,
          k.altoMajorNotes.last,
          reason: 'Alto ${k.altoKey}: first note should equal last (octave)',
        );
      }
    });

    test('Alto A major: A B C# D E F# G# A', () {
      expect(_key('C').altoMajorNotes, ['A', 'B', 'C#', 'D', 'E', 'F#', 'G#', 'A']);
    });

    test('Alto C major: C D E F G A B C', () {
      expect(_key('Eb').altoMajorNotes, ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C']);
    });

    test('Alto E major: E F# G# A B C# D# E', () {
      expect(_key('G').altoMajorNotes, ['E', 'F#', 'G#', 'A', 'B', 'C#', 'D#', 'E']);
    });

    test('Alto D major: D E F# G A B C# D', () {
      expect(_key('F').altoMajorNotes, ['D', 'E', 'F#', 'G', 'A', 'B', 'C#', 'D']);
    });

    test('Alto G# major contains Fx (F double-sharp)', () {
      expect(_key('B').altoMajorNotes.contains('Fx'), isTrue);
    });

    test('Alto Bb major: Bb C D Eb F G A Bb', () {
      expect(_key('Db').altoMajorNotes, ['Bb', 'C', 'D', 'Eb', 'F', 'G', 'A', 'Bb']);
    });

    test('Alto Eb major: Eb F G Ab Bb C D Eb', () {
      expect(_key('Gb').altoMajorNotes, ['Eb', 'F', 'G', 'Ab', 'Bb', 'C', 'D', 'Eb']);
    });
  });

  // ── Pentatonic note lists ─────────────────────────────────────────────────

  group('Major pentatonic notes', () {
    test('Every key has exactly 5 pentatonic notes', () {
      for (final k in kJamKeys) {
        expect(k.altoPentatonicNotes.length, 5,
            reason: 'Alto ${k.altoKey} pentatonic should have 5 notes');
      }
    });

    test('Alto A pentatonic: A B C# E F#', () {
      expect(_key('C').altoPentatonicNotes, ['A', 'B', 'C#', 'E', 'F#']);
    });

    test('Alto E pentatonic: E F# G# B C#', () {
      expect(_key('G').altoPentatonicNotes, ['E', 'F#', 'G#', 'B', 'C#']);
    });

    test('Alto C pentatonic: C D E G A', () {
      expect(_key('Eb').altoPentatonicNotes, ['C', 'D', 'E', 'G', 'A']);
    });

    test('Alto G# pentatonic: G# A# B# D# E#', () {
      expect(_key('B').altoPentatonicNotes, ['G#', 'A#', 'B#', 'D#', 'E#']);
    });

    // Pentatonic notes must be a subset of the major scale (first 7 notes).
    test('Pentatonic notes are drawn from the major scale', () {
      for (final k in kJamKeys) {
        final scaleSet = k.altoMajorNotes.sublist(0, 7).toSet();
        for (final note in k.altoPentatonicNotes) {
          expect(scaleSet.contains(note), isTrue,
              reason:
                  'Pentatonic note $note for Alto ${k.altoKey} not in major scale');
        }
      }
    });
  });

  // ── Frame display text formatting ─────────────────────────────────────────

  group('Frame display text formatting', () {
    test('Frame text has exactly 3 lines', () {
      for (final k in kJamKeys) {
        final lines = k.frameDisplayText.split('\n');
        expect(lines.length, 3,
            reason: 'Frame text for Concert ${k.concertKey} should have 3 lines');
      }
    });

    test('Line 1 contains both concert key and arrow and alto key', () {
      final k = _key('C');
      final line1 = k.frameDisplayText.split('\n')[0];
      expect(line1, contains('Concert C'));
      expect(line1, contains('->'));
      expect(line1, contains('Alto A'));
    });

    test('Line 2 contains the 7-note (no octave repeat) scale', () {
      final k = _key('C');
      final line2 = k.frameDisplayText.split('\n')[1];
      // 7 notes without the repeated octave
      expect(line2, 'A B C# D E F# G#');
    });

    test('Line 3 starts with "Pent:"', () {
      for (final k in kJamKeys) {
        final line3 = k.frameDisplayText.split('\n')[2];
        expect(line3.startsWith('Pent:'), isTrue,
            reason: 'Line 3 for Concert ${k.concertKey} should start with "Pent:"');
      }
    });

    // Single quotes in Frame text would break the Lua string literal.
    test('No single quotes in any frame display text (Lua-safe)', () {
      for (final k in kJamKeys) {
        expect(
          k.frameDisplayText.contains("'"),
          isFalse,
          reason:
              'Frame text for Concert ${k.concertKey} must not contain single quotes',
        );
      }
    });

    test('Frame text for Concert G / Alto E is correct', () {
      final k = _key('G');
      final lines = k.frameDisplayText.split('\n');
      expect(lines[0], 'Concert G -> Alto E');
      expect(lines[1], 'E F# G# A B C# D#');
      expect(lines[2], 'Pent: E F# G# B C#');
    });
  });

  // ── Display helper strings ────────────────────────────────────────────────

  group('Display helper strings', () {
    test('concertLabel format', () {
      expect(_key('C').concertLabel, 'Concert C');
      expect(_key('Bb').concertLabel, 'Concert Bb');
    });

    test('altoLabel format', () {
      expect(_key('C').altoLabel, 'Alto A');
      expect(_key('B').altoLabel, 'Alto G#');
    });

    test('altoMajorNotesDisplay joins with spaces', () {
      expect(_key('Eb').altoMajorNotesDisplay, 'C D E F G A B C');
    });

    test('altoPentatonicDisplay joins with spaces', () {
      expect(_key('Eb').altoPentatonicDisplay, 'C D E G A');
    });
  });
}

JamKey _key(String concertKey) =>
    kJamKeys.firstWhere((k) => k.concertKey == concertKey);
