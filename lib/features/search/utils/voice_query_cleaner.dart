/// Words people say while asking for a song that are not part of its name.
/// Speech recognition hears them all, so searching with them makes the search
/// miss the song ("ओंकार प्रेम प्ले कर" instead of "ओंकार प्रेम").
const Set<String> _spokenFillers = {
  // मराठी / हिंदी — क्रियापदं आणि भरतीचे शब्द
  'लाव', 'लावा', 'लावून', 'प्ले', 'कर', 'करा', 'करून', 'दे', 'द्या', 'देत',
  'गाणं', 'गाणे', 'गाणी', 'गीत', 'सॉन्ग', 'साँग', 'संगीत', 'ट्रॅक',
  'शोध', 'शोधा', 'शोधून', 'शोधायचं', 'दाखव', 'दाखवा', 'दाखवून',
  'मला', 'माझं', 'माझ्या', 'माझी', 'आता', 'थोडं', 'थोडा', 'थोडी',
  'प्लीज', 'हवं', 'हवंय', 'हवा', 'हवी', 'सुरू', 'ऐक', 'ऐकायचं', 'ऐकायचंय',
  'काही', 'एक', 'बजाव', 'बजाओ', 'चलाओ', 'चला', 'गाना', 'गाने', 'सुनाओ',
  'सुनो', 'ढूंढो', 'खोजो', 'डाउनलोड', 'ऑनलाइन', 'पर', 'का', 'की', 'के',
  'से', 'में', 'और',
  // English
  'play', 'song', 'songs', 'track', 'tracks', 'music', 'for', 'me', 'please',
  'search', 'find', 'the', 'a', 'an', 'on', 'some', 'now', 'download',
  'online', 'from', 'spotify', 'youtube', 'of',
};

/// Things people say before the actual request ("ओके गूगल ...").
const List<String> _wakeWords = [
  'ok google',
  'okay google',
  'hey google',
  'ओके गूगल',
  'ओके गूगल',
  'हे गूगल',
  'अरे गूगल',
];

final RegExp _punctuation = RegExp(r'[।,.!?;:"“”‘’()\[\]]');
final RegExp _extraSpaces = RegExp(r'\s+');

/// Removes punctuation, wake words and filler words from spoken text, so the
/// words left over are the ones that actually name the song or artist.
String cleanSpokenQuery(String input) {
  var text = input.replaceAll(_punctuation, ' ');
  text = text.replaceAll(_extraSpaces, ' ').trim();
  if (text.isEmpty) return input.trim();

  final lower = text.toLowerCase();
  for (final wake in _wakeWords) {
    if (lower.startsWith(wake)) {
      text = text.substring(wake.length).trim();
      break;
    }
  }

  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return input.trim();

  final kept = words
      .where((word) => !_spokenFillers.contains(word.toLowerCase()))
      .toList();
  // If everything was a filler word, keep the original words rather than
  // searching for nothing at all.
  final result = (kept.isEmpty ? words : kept).join(' ').trim();
  return result.isEmpty ? input.trim() : result;
}

/// The queries to try, one after another, when a spoken search finds nothing:
/// the cleaned-up words first, then just the first few of them (people often
/// add a whole sentence after the song name), and finally exactly what was
/// heard, in case cleaning removed a real word.
List<String> voiceQueryFallbacks(String input) {
  final cleaned = cleanSpokenQuery(input);
  final words = cleaned.split(' ').where((w) => w.isNotEmpty).toList();

  final candidates = <String>[
    cleaned,
    if (words.length > 3) words.take(3).join(' '),
    if (words.length > 2) words.take(2).join(' '),
    input.trim(),
  ];

  final seen = <String>{};
  return [
    for (final query in candidates)
      if (query.isNotEmpty && seen.add(query.toLowerCase())) query,
  ];
}
