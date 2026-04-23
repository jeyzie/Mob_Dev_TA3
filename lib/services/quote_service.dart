import 'dart:convert';
import 'package:http/http.dart' as http;

class QuoteService {
  static Future<String> fetchMotivationalQuote() async {
    try {
      final client = http.Client();
      final response = await client
          .get(
            Uri.parse(
              'https://zenquotes.io/api/random?_=${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 1));
      client.close();

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final quote = data[0];
        return '“${quote['q']}” — ${quote['a']}';
      }
    } catch (_) {}

    try {
      final client = http.Client();
      final response = await client
          .get(
            Uri.parse(
              'https://api.quotable.io/random?_=${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 1));
      client.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return '“${data['content']}” — ${data['author']}';
      }
    } catch (_) {}

    const fallbackQuotes = [
      'Stay motivated! Keep going! 💪',
      'Believe you can and you’re halfway there. — Theodore Roosevelt',
      'The only way to do great work is to love what you do. — Steve Jobs',
      'Success is not final, failure is not fatal: it is the courage to continue that counts. — Winston Churchill',
    ];
    return fallbackQuotes[DateTime.now().millisecond % fallbackQuotes.length];
  }
}