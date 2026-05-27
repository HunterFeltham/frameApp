/// Data model for a concert-key-to-alto-sax-key mapping.
///
/// Alto saxophone is an Eb transposing instrument: a written note sounds a
/// major 6th lower in concert pitch. So Concert C → Alto written A, etc.
///
/// [scaleType] is 'major' for v1. Adding 'minor', 'pentatonic', 'blues'
/// later only requires new [JamKey] entries in key_data.dart.
class JamKey {
  final String concertKey;
  final String altoKey;
  final String scaleType;
  final List<String> altoMajorNotes;      // 8 notes (7 unique + octave repeat)
  final List<String> altoPentatonicNotes; // 5 notes

  const JamKey({
    required this.concertKey,
    required this.altoKey,
    this.scaleType = 'major',
    required this.altoMajorNotes,
    required this.altoPentatonicNotes,
  });

  String get concertLabel => 'Concert $concertKey';
  String get altoLabel => 'Alto $altoKey';

  String get altoMajorNotesDisplay => altoMajorNotes.join(' ');
  String get altoPentatonicDisplay => altoPentatonicNotes.join(' ');

  /// Compact 3-line string optimised for Frame glasses display (640×400 px).
  /// Avoids single quotes so it embeds safely in a Lua string literal.
  String get frameDisplayText {
    // Drop the repeated octave note to keep line 2 shorter on small display
    final scaleNotes = altoMajorNotes.length == 8
        ? altoMajorNotes.sublist(0, 7).join(' ')
        : altoMajorNotesDisplay;

    return 'Concert $concertKey -> Alto $altoKey\n'
        '$scaleNotes\n'
        'Pent: $altoPentatonicDisplay';
  }
}
