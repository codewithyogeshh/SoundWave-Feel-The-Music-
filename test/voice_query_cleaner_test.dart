import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/search/utils/voice_query_cleaner.dart';

void main() {
  group('cleanSpokenQuery', () {
    test('drops Marathi command words', () {
      expect(cleanSpokenQuery('ओंकार प्रेम प्ले कर'), 'ओंकार प्रेम');
      expect(cleanSpokenQuery('शेवटचं गाणं लाव'), 'शेवटचं');
    });

    test('drops English filler words', () {
      expect(cleanSpokenQuery('Play Kesariya song please'), 'Kesariya');
    });

    test('removes punctuation and wake words', () {
      expect(cleanSpokenQuery('ओके गूगल, तुझे काय झाले?'), 'तुझे काय झाले');
    });

    test('keeps the words when everything is a filler', () {
      expect(cleanSpokenQuery('गाणं लाव'), 'गाणं लाव');
    });

    test('leaves a clean song name alone', () {
      expect(cleanSpokenQuery('Kesariya'), 'Kesariya');
      expect(cleanSpokenQuery('ओंकार प्रेम'), 'ओंकार प्रेम');
    });
  });

  group('voiceQueryFallbacks', () {
    test('tries the cleaned query before the raw one', () {
      final queries = voiceQueryFallbacks('ओंकार प्रेम प्ले कर');
      expect(queries.first, 'ओंकार प्रेम');
      expect(queries, contains('ओंकार प्रेम प्ले कर'));
    });

    test('shortens long sentences and removes duplicates', () {
      final queries = voiceQueryFallbacks('ओंकार प्रेम तुझे काय झाले गाणं लाव');
      expect(queries.take(3).toList(), [
        'ओंकार प्रेम तुझे काय झाले',
        'ओंकार प्रेम तुझे',
        'ओंकार प्रेम',
      ]);
      expect(queries.toSet().length, queries.length);
    });
  });
}
