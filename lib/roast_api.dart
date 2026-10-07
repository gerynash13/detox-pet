   import 'dart:convert';
   import 'package:http/http.dart' as http;

   const supabaseUrl = 'https://huvqnnmcfkinlxlhatav.supabase.co';
   const supabaseAnonKey = 'sb_publishable_XomYTCiO08-McfoLcPF7iQ_0ckM7Lv7';

   Future<String> fetchRoast({
    required String app,
    required int minutes,
    String? task,
    String? title,
  }) async {
    final res = await http.post(
      Uri.parse('$supabaseUrl/functions/v1/intervene'),
      headers: {
        'Authorization': 'Bearer $supabaseAnonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
          {'app': app, 'minutes': minutes, 'task': task, 'title': title}),
    );
    if (res.statusCode != 200) {
      throw Exception('Roast failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as Map)['roast'] as String;
  }