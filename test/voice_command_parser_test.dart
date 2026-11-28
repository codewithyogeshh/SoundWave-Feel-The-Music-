import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/player/utils/voice_command_parser.dart';

void main() {
  test('understands Marathi playback commands', () {
    expect(parseVoiceCommand('पुढचं गाणं'), VoiceCommand.next);
    expect(parseVoiceCommand('मागचं गाणं लाव'), VoiceCommand.previous);
    expect(parseVoiceCommand('थांबव'), VoiceCommand.pause);
    expect(parseVoiceCommand('गाणं पुन्हा लाव'), VoiceCommand.resume);
    expect(parseVoiceCommand('सुरुवातीपासून'), VoiceCommand.restart);
    expect(parseVoiceCommand('शफल'), VoiceCommand.shuffle);
    expect(parseVoiceCommand('पुन्हा पुन्हा'), VoiceCommand.repeat);
    expect(parseVoiceCommand('हे गाणं आवडतं'), VoiceCommand.favorite);
  });

  test('understands Hindi and English commands', () {
    expect(parseVoiceCommand('अगला गाना'), VoiceCommand.next);
    expect(parseVoiceCommand('रोको'), VoiceCommand.pause);
    expect(parseVoiceCommand('Next song'), VoiceCommand.next);
    expect(parseVoiceCommand('PAUSE!'), VoiceCommand.pause);
    expect(parseVoiceCommand('play.'), VoiceCommand.resume);
    expect(parseVoiceCommand('repeat'), VoiceCommand.repeat);
  });

  test('ignores punctuation, casing and extra words', () {
    expect(parseVoiceCommand('  पुढचं   गाणं? '), VoiceCommand.next);
    expect(parseVoiceCommand('कृपया पुढचं गाणं लाव'), VoiceCommand.next);
    expect(parseVoiceCommand('Song skip please'), VoiceCommand.next);
  });

  test('understands volume up, volume down and mute', () {
    expect(parseVoiceCommand('आवाज वाढव'), VoiceCommand.volumeUp);
    expect(parseVoiceCommand('आवाज कमी कर'), VoiceCommand.volumeDown);
    expect(parseVoiceCommand('म्यूट कर'), VoiceCommand.mute);
    expect(parseVoiceCommand('थोडा मोठा आवाज कर'), VoiceCommand.volumeUp);
    expect(parseVoiceCommand('आवाज हळू कर'), VoiceCommand.volumeDown);
    expect(parseVoiceCommand('volume up'), VoiceCommand.volumeUp);
    expect(parseVoiceCommand('Volume Down please'), VoiceCommand.volumeDown);
    expect(parseVoiceCommand('mute'), VoiceCommand.mute);
    expect(parseVoiceCommand('आवाज़ बढ़ा'), VoiceCommand.volumeUp);
  });

  test('"आवाज बंद कर" mutes instead of pausing', () {
    expect(parseVoiceCommand('आवाज बंद कर'), VoiceCommand.mute);
    expect(parseVoiceCommand('गाणं बंद कर'), VoiceCommand.pause);
  });

  test('returns null for unrelated speech', () {
    expect(parseVoiceCommand(''), isNull);
    expect(parseVoiceCommand('आज हवामान कसं आहे'), isNull);
    expect(parseVoiceCommand('what is the time'), isNull);
  });

  test('"पुन्हा लाव" resumes while "पुन्हा पुन्हा" repeats', () {
    expect(parseVoiceCommand('पुन्हा लाव'), VoiceCommand.resume);
    expect(parseVoiceCommand('पुन्हा पुन्हा लाव'), VoiceCommand.repeat);
  });
}
