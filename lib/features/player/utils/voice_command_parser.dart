/// Spoken playback commands understood by the app, in Marathi, Hindi and
/// English. Kept as a pure function so it can be unit tested without a phone.
enum VoiceCommand {
  next,
  previous,
  pause,
  resume,
  restart,
  shuffle,
  repeat,
  favorite,
  volumeUp,
  volumeDown,
  mute,
}

class _CommandRule {
  final VoiceCommand command;
  final List<String> phrases;

  const _CommandRule(this.command, this.phrases);
}

/// Checked top to bottom, so the first match wins. Longer / more specific
/// phrases are listed before shorter ones.
const List<_CommandRule> _rules = [
  // Volume rules come first: "आवाज बंद कर" is mute, not pause.
  _CommandRule(VoiceCommand.mute, [
    'म्यूट',
    'mute',
    'निःशब्द',
    'शांत कर',
    'आवाज बंद कर',
    'आवाज बंद',
    'sound off',
    'silence',
    'आवाज़ बंद',
  ]),
  _CommandRule(VoiceCommand.volumeUp, [
    'आवाज वाढव',
    'आवाज वाढ',
    'आवाज मोठा',
    'मोठा आवाज',
    'आवाज जास्त',
    'volume up',
    'louder',
    'increase volume',
    'आवाज़ बढ़ा',
    'आवाज बढ़ा',
  ]),
  _CommandRule(VoiceCommand.volumeDown, [
    'आवाज कमी कर',
    'आवाज कमी',
    'आवाज हळू',
    'हळू कर',
    'आवाज मंद',
    'volume down',
    'quieter',
    'lower volume',
    'decrease volume',
    'आवाज़ कम',
    'आवाज कम',
  ]),
  _CommandRule(VoiceCommand.repeat, [
    'पुन्हा पुन्हा',
    'पुनरावृत्ती',
    'repeat',
    'loop',
    'लूप',
  ]),
  _CommandRule(VoiceCommand.previous, [
    'मागचं',
    'मागचा',
    'मागील',
    'मागे',
    'previous',
    'back',
    'पिछला',
    'पिछले',
  ]),
  _CommandRule(VoiceCommand.next, [
    'पुढचं',
    'पुढचा',
    'पुढील',
    'पुढे',
    'next',
    'skip',
    'अगला',
    'अगले',
    'आगे',
  ]),
  _CommandRule(VoiceCommand.restart, [
    'सुरुवातीपासून',
    'सुरुवाती पासून',
    'पहिल्यापासून',
    'पहिल्यापासून लाव',
    'from start',
    'restart',
    'शुरू से',
  ]),
  _CommandRule(VoiceCommand.shuffle, [
    'शफल',
    'shuffle',
    'random',
  ]),
  _CommandRule(VoiceCommand.pause, [
    'थांबव',
    'थांब',
    'बंद कर',
    'pause',
    'stop',
    'रोको',
    'रोक',
  ]),
  _CommandRule(VoiceCommand.resume, [
    'पुन्हा लाव',
    'पुन्हा सुरू',
    'पुन्हा चालू',
    'सुरू कर',
    'सुरु कर',
    'चालू कर',
    'लाव',
    'play',
    'resume',
    'start',
    'चलाओ',
  ]),
  _CommandRule(VoiceCommand.favorite, [
    'आवडतं',
    'आवडत',
    'आवडीत',
    'फेव्हरिट',
    'favorite',
    'favourite',
  ]),
];

/// Examples shown in the voice control sheet, so users know what to say.
const List<String> voiceCommandExamples = [
  'पुढचं गाणं',
  'मागचं गाणं',
  'थांबव',
  'पुन्हा लाव',
  'सुरुवातीपासून',
  'शफल',
  'पुन्हा पुन्हा',
  'आवडतं',
  'आवाज वाढव',
  'आवाज कमी कर',
  'म्यूट कर',
];

String _normalize(String input) {
  return input
      .toLowerCase()
      // Marathi and Hindi letters live in U+0900..U+097F; keep those and words.
      .replaceAll(RegExp(r'[^\w\s\u0900-\u097F]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Returns the command in [spoken], or null when it is not a playback command.
VoiceCommand? parseVoiceCommand(String spoken) {
  final text = _normalize(spoken);
  if (text.isEmpty) return null;

  for (final rule in _rules) {
    for (final phrase in rule.phrases) {
      if (text.contains(_normalize(phrase))) return rule.command;
    }
  }
  return null;
}
