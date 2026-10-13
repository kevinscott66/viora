import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spun_music/services/social_api.dart';

void main() {
  test('public default does not contact an unconfigured service', () async {
    await expectLater(
      SocialApi().request('GET', '/api/profile'),
      throwsA(isA<SocialError>()),
    );
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'recovery switches identity only after success and preserves old token',
    () async {
      SharedPreferences.setMockInitialValues({'socialToken': 'old'});
      final api = SocialApi(base: 'https://viora.example.com');
      await http.runWithClient(
        () async {
          await api.request('GET', '/api/profile');
          await api.recover('code');
          await api.request('GET', '/api/sessions');
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('socialPreviousToken'), 'old');
          expect(prefs.getString('socialToken'), 'new');
        },
        () => MockClient((r) async {
          if (r.url.path == '/api/recover') {
            expect(r.headers.containsKey('Authorization'), false);
            return http.Response('{"token":"new"}', 200);
          }
          expect(
            r.headers['Authorization'],
            r.url.path == '/api/profile' ? 'Bearer old' : 'Bearer new',
          );
          return http.Response('{}', 200);
        }),
      );
    },
  );
  final payload = {
    'v': 1,
    'title': 'Песня',
    'artists': ['Артист'],
    'seconds': 42,
    'lyric': 'Строка',
    'note': '',
  };
  test(
    'one identity for concurrent requests; short link resolves without auth',
    () async {
      var registrations = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/register') {
          registrations++;
          return http.Response(
            jsonEncode({'token': 'Example title 404-token'}),
            201,
          );
        }
        if (request.url.path == '/api/moments/abcdefghijklmnop') {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            jsonEncode(payload),
            200,
            headers: {"content-type": "application/json; charset=utf-8"},
          );
        }
        expect(
          request.headers['Authorization'],
          'Bearer Example title 404-token',
        );
        return http.Response('{"chats":[]}', 200);
      });
      await http.runWithClient(() async {
        final api = SocialApi(base: 'https://viora.example.com');
        await Future.wait([
          api.request('GET', '/api/chats'),
          api.request('GET', '/api/chats'),
        ]);
        expect(registrations, 1);
        final m = await api.resolve(
          Uri.parse('https://viora.example.com/m/abcdefghijklmnop'),
        );
        expect(m!.seconds, 42);
        expect(m.title, 'Песня');
      }, () => client);
    },
  );
  test(
    'legacy links remain local and foreign links do not reach API',
    () async {
      await http.runWithClient(() async {
        final api = SocialApi(base: 'https://viora.example.com');
        expect(
          (await api.resolve(
            Uri(
              scheme: 'https',
              host: 'viora.example.com',
              fragment: jsonEncode(payload),
            ),
          ))!.title,
          'Песня',
        );
        expect(
          await api.resolve(Uri.parse('https://other.test/m/abcdefghijklmnop')),
          isNull,
        );
      }, () => MockClient((_) async => throw StateError('Unexpected network')));
    },
  );
  test('server errors preserve useful messages', () async {
    SharedPreferences.setMockInitialValues({'socialToken': 'saved'});
    await http.runWithClient(
      () async {
        await expectLater(
          SocialApi(
            base: 'https://viora.example.com',
          ).request('GET', '/api/chats'),
          throwsA(
            isA<SocialError>().having(
              (e) => e.message,
              'message',
              'Нет доступа',
            ),
          ),
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Нет доступа'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  });
}
