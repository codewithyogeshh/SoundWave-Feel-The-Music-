import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_des/dart_des.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Test JioSaavn Direct API and DES Decryption', () async {
    const url = 'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&p=1&n=5&q=kesariya';
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });

    expect(response.statusCode, 200);
    final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;
    expect(results.isNotEmpty, true);

    final first = results[0] as Map<String, dynamic>;
    final enc = first['encrypted_media_url'] as String;
    expect(enc.isNotEmpty, true);

    // Decrypt
    final key = utf8.encode('38346591');
    final des = DES(key: key, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS5);
    final decBytes = des.decrypt(base64.decode(enc.trim()));
    final decUrl = utf8.decode(decBytes);

    final url320 = decUrl.replaceAll('_96.mp4', '_320.mp4');
    expect(url320.startsWith('https://aac.saavncdn.com/'), true);

    // Verify stream download
    final headResp = await http.head(Uri.parse(url320), headers: {
      'User-Agent': 'Mozilla/5.0',
    });
    expect(headResp.statusCode, 200);
  });
}
