import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spun_music/services/chat_vault.dart';
import 'package:spun_music/services/social_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'recovery sends proof only and switches account after authenticated backup restore',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({'socialToken': 'old'});
      final seed = List<int>.filled(32, 13), code = await ChatVault.newCode();
      final backup = await ChatVault.wrap('recovered', seed, code);
      final pub = await ChatVault.publicKey(seed);
      var corrupt = true;
      final api = SocialApi(base: 'https://viora.example.com');
      await http.runWithClient(
        () async {
          await expectLater(api.recover(code), throwsA(anything));
          expect(
            (await SharedPreferences.getInstance()).getString('socialToken'),
            'old',
          );
          expect(await ChatVault.read('recovered'), isNull);
          corrupt = false;
          await api.recover(code);
          expect(await ChatVault.read('recovered'), seed);
          expect(
            (await SharedPreferences.getInstance()).getString('socialToken'),
            'new',
          );
        },
        () => MockClient((r) async {
          expect(r.url.path, '/api/recover-v2');
          expect(r.body.contains(code), false);
          expect(jsonDecode(r.body)['proof'], await ChatVault.proof(code));
          return http.Response(
            jsonEncode({
              'token': 'new',
              'user': 'recovered',
              'publicKey': pub,
              'backup': corrupt
                  ? {...backup, 'tag': base64Encode(List<int>.filled(16, 0))}
                  : backup,
            }),
            200,
          );
        }),
      );
    },
  );
}
