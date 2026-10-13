import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'moment_link.dart';
import 'chat_vault.dart';

class SocialApi {
  static final instance = SocialApi();
  final String base;
  SocialApi({
    this.base = const String.fromEnvironment(
      'VIORA_API_BASE',
      defaultValue: '',
    ),
  });
  Future<String>? _identity;
  Future<String> _token() => _identity ??= _loadToken().catchError((Object e) {
    _identity = null;
    throw e;
  });
  Future<String> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('socialToken');
    if (saved != null) return saved;
    final profile = await request('POST', '/api/register', {}, false);
    final token = profile['token'] as String;
    if (!await prefs.setString('socialToken', token)) {
      throw Exception('Не удалось сохранить профиль на устройстве');
    }
    return token;
  }

  Future<void> recover(String code) async {
    code = code.trim();
    final modern = code.startsWith('v2.');
    final data =
        await request('POST', modern ? '/api/recover-v2' : '/api/recover', {
          if (modern) 'proof': await ChatVault.proof(code) else 'code': code,
          'label': 'iPhone',
        }, false);
    if (modern) {
      final uid = data['user'] as String;
      final seed = await ChatVault.unwrap(
        uid,
        Map<String, dynamic>.from(data['backup'] as Map),
        code,
      );
      if (await ChatVault.publicKey(seed) != data['publicKey']) {
        throw SocialError(
          'Не удалось проверить восстановление. Вход не изменён.',
        );
      }
      await ChatVault.write(uid, seed);
    }
    final token = data['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString('socialToken');
    // Keep the previous local identity available for support/recovery, never merge accounts.
    if (old != null && !await prefs.setString('socialPreviousToken', old)) {
      throw SocialError('Не удалось сохранить прежний профиль');
    }
    if (!await prefs.setString('socialToken', token)) {
      throw SocialError('Не удалось сохранить вход');
    }
    _identity = Future.value(token);
  }

  static String nonce() {
    final random = Random.secure();
    return base64Url.encode(List.generate(18, (_) => random.nextInt(256)));
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool auth = true,
  ]) async {
    if (base.isEmpty) {
      throw SocialError(
        'Социальный сервис не настроен. Локальная музыка доступна.',
      );
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) headers['Authorization'] = 'Bearer ${await _token()}';
    try {
      final url = Uri.parse('$base$path');
      final response =
          await (method == 'GET'
                  ? http.get(url, headers: headers)
                  : http.post(
                      url,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ))
              .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw SocialError(data['error'] as String? ?? 'Ошибка сервера');
      }
      return data;
    } on SocialError {
      rethrow;
    } catch (_) {
      throw SocialError('Нет соединения с сервисом. Попробуйте ещё раз.');
    }
  }

  Future<Uri> shorten(Uri legacy) async {
    final payload =
        jsonDecode(Uri.decodeComponent(legacy.fragment))
            as Map<String, dynamic>;
    final data = await request('POST', '/api/moments', payload);
    return Uri.parse(data['url'] as String);
  }

  Future<ReceivedMoment?> resolve(Uri uri) async {
    final legacy = ReceivedMoment.parse(uri);
    if (legacy != null) return legacy;
    final code = uri.scheme == 'viora' && uri.host == 'moment'
        ? uri.queryParameters['id']
        : uri.scheme == 'https' &&
              uri.host == 'viora.example.com' &&
              uri.pathSegments.length == 2 &&
              uri.pathSegments.first == 'm'
        ? uri.pathSegments.last
        : null;
    if (code == null || !RegExp(r'^[A-Za-z0-9_-]{16}$').hasMatch(code)) {
      return null;
    }
    final data = await request('GET', '/api/moments/$code', null, false);
    return ReceivedMoment.parse(
      Uri(scheme: 'viora', host: 'moment', fragment: jsonEncode(data)),
    );
  }
}

class SocialError implements Exception {
  final String message;
  SocialError(this.message);
  @override
  String toString() => message;
}
