import '../models/jam_key.dart';

/// All concert-key → alto-sax written-key mappings for v1 (major keys only).
///
/// Alto sax transposes: written note sounds a major 6th lower in concert pitch.
///   Concert C  → Alto A  (A is a major 6th above C)
///   Concert G  → Alto E  ... etc.
///
/// Scale note lists include the repeated octave (8 notes total) so the UI
/// can display the full ascending scale. The Frame display trims the repeat.
///
/// To add minor / pentatonic / blues keys in the future: append new JamKey
/// entries here with scaleType set appropriately. No other file needs changes.
const List<JamKey> kJamKeys = [
  // ── Sharp-side keys ──────────────────────────────────────────────────────
  JamKey(
    concertKey: 'C',
    altoKey: 'A',
    altoMajorNotes: ['A', 'B', 'C#', 'D', 'E', 'F#', 'G#', 'A'],
    altoPentatonicNotes: ['A', 'B', 'C#', 'E', 'F#'],
  ),
  JamKey(
    concertKey: 'G',
    altoKey: 'E',
    altoMajorNotes: ['E', 'F#', 'G#', 'A', 'B', 'C#', 'D#', 'E'],
    altoPentatonicNotes: ['E', 'F#', 'G#', 'B', 'C#'],
  ),
  JamKey(
    concertKey: 'D',
    altoKey: 'B',
    altoMajorNotes: ['B', 'C#', 'D#', 'E', 'F#', 'G#', 'A#', 'B'],
    altoPentatonicNotes: ['B', 'C#', 'D#', 'F#', 'G#'],
  ),
  JamKey(
    concertKey: 'A',
    altoKey: 'F#',
    altoMajorNotes: ['F#', 'G#', 'A#', 'B', 'C#', 'D#', 'E#', 'F#'],
    altoPentatonicNotes: ['F#', 'G#', 'A#', 'C#', 'D#'],
  ),
  JamKey(
    concertKey: 'E',
    altoKey: 'C#',
    altoMajorNotes: ['C#', 'D#', 'E#', 'F#', 'G#', 'A#', 'B#', 'C#'],
    altoPentatonicNotes: ['C#', 'D#', 'E#', 'G#', 'A#'],
  ),
  JamKey(
    // Concert B → Alto G# (the theoretical sharp key; enharmonic with Concert Cb → Alto Ab)
    // G# major contains Fx (F double-sharp = enharmonic G).
    // A future enharmonic-display toggle could show Ab major notes instead.
    concertKey: 'B',
    altoKey: 'G#',
    altoMajorNotes: ['G#', 'A#', 'B#', 'C#', 'D#', 'E#', 'Fx', 'G#'],
    altoPentatonicNotes: ['G#', 'A#', 'B#', 'D#', 'E#'],
  ),

  // ── Flat-side keys ───────────────────────────────────────────────────────
  JamKey(
    concertKey: 'F',
    altoKey: 'D',
    altoMajorNotes: ['D', 'E', 'F#', 'G', 'A', 'B', 'C#', 'D'],
    altoPentatonicNotes: ['D', 'E', 'F#', 'A', 'B'],
  ),
  JamKey(
    concertKey: 'Bb',
    altoKey: 'G',
    altoMajorNotes: ['G', 'A', 'B', 'C', 'D', 'E', 'F#', 'G'],
    altoPentatonicNotes: ['G', 'A', 'B', 'D', 'E'],
  ),
  JamKey(
    concertKey: 'Eb',
    altoKey: 'C',
    altoMajorNotes: ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C'],
    altoPentatonicNotes: ['C', 'D', 'E', 'G', 'A'],
  ),
  JamKey(
    concertKey: 'Ab',
    altoKey: 'F',
    altoMajorNotes: ['F', 'G', 'A', 'Bb', 'C', 'D', 'E', 'F'],
    altoPentatonicNotes: ['F', 'G', 'A', 'C', 'D'],
  ),
  JamKey(
    concertKey: 'Db',
    altoKey: 'Bb',
    altoMajorNotes: ['Bb', 'C', 'D', 'Eb', 'F', 'G', 'A', 'Bb'],
    altoPentatonicNotes: ['Bb', 'C', 'D', 'F', 'G'],
  ),
  JamKey(
    concertKey: 'Gb',
    altoKey: 'Eb',
    altoMajorNotes: ['Eb', 'F', 'G', 'Ab', 'Bb', 'C', 'D', 'Eb'],
    altoPentatonicNotes: ['Eb', 'F', 'G', 'Bb', 'C'],
  ),
];
