import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spun_music/services/chat_vault.dart';
import 'package:spun_music/services/chat_crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'both participants derive same room secret and substitution changes verification',
    () async {
      final a = await ChatVault.create('a'),
          b = await ChatVault.create('b'),
          attacker = await ChatVault.create('attacker');
      final ap = await ChatVault.publicKey(a),
          bp = await ChatVault.publicKey(b),
          mp = await ChatVault.publicKey(attacker);
      final ak = await ChatVault.roomKey(a, bp, 'room');
      expect(await ChatVault.roomKey(b, ap, 'room'), ak);
      expect(await ChatVault.roomKey(a, bp, 'other'), isNot(ak));
      expect(
        await ChatCipher.fingerprint(await ChatVault.roomKey(a, mp, 'room')),
        isNot(
          await ChatCipher.fingerprint(await ChatVault.roomKey(b, mp, 'room')),
        ),
      );
      await ChatVault.pin('a', 'b', bp);
      await expectLater(ChatVault.pin('a', 'b', mp), throwsStateError);
    },
  );
  test(
    'one recovery code restores identity; wrong code or account fails',
    () async {
      final seed = await ChatVault.create('a');
      final code = await ChatVault.newCode();
      final box = await ChatVault.wrap('a', seed, code);
      expect(await ChatVault.unwrap('a', box, code), seed);
      await expectLater(ChatVault.unwrap('b', box, code), throwsA(anything));
      await expectLater(
        ChatVault.unwrap('a', box, await ChatVault.newCode()),
        throwsA(anything),
      );
    },
  );
}
