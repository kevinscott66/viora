import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local keys and client-only recovery encryption. The recovery code is never sent to the server.
class ChatVault {
  static const storage = FlutterSecureStorage();
  static final agreement = X25519();
  static final aes = AesGcm.with256bits();
  static Future<List<int>> hash(Object value) async =>
      (await Sha256().hash(utf8.encode(jsonEncode(value)))).bytes;
  static Future<List<int>?> read(String uid) async {
    final s = await storage.read(key: 'viora.identity.v1.$uid');
    return s == null ? null : base64Decode(s);
  }

  static Future<void> write(String uid, List<int> seed) async {
    if (seed.length != 32) throw const FormatException('Invalid identity');
    await storage.write(
      key: 'viora.identity.v1.$uid',
      value: base64Encode(seed),
    );
    if (await storage.read(key: 'viora.identity.v1.$uid') !=
        base64Encode(seed)) {
      throw StateError(
        'Не удалось сохранить доступ на устройстве. Повторите попытку.',
      );
    }
  }

  static Future<List<int>> create(String uid) async {
    final key = await agreement.newKeyPair();
    final seed = await key.extractPrivateKeyBytes();
    await write(uid, seed);
    return seed;
  }

  static Future<String> publicKey(List<int> seed) async => base64Encode(
    (await (await agreement.newKeyPairFromSeed(seed)).extractPublicKey()).bytes,
  );
  static Future<List<int>> roomKey(
    List<int> seed,
    String peer,
    String room,
  ) async {
    final shared = await agreement.sharedSecretKey(
      keyPair: await agreement.newKeyPairFromSeed(seed),
      remotePublicKey: SimplePublicKey(
        base64Decode(peer),
        type: KeyPairType.x25519,
      ),
    );
    final result = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: await hash(['viora-room', 1, room]),
      info: utf8.encode('viora-chat-encryption-v1'),
    );
    return result.extractBytes();
  }

  static Future<void> pin(String uid, String peerId, String publicKey) async {
    final slot = 'viora.peer.v1.$uid.$peerId';
    final old = await storage.read(key: slot);
    if (old != null && old != publicKey) {
      throw StateError('Ключ собеседника изменился. Отправка остановлена.');
    }
    if (old == null) await storage.write(key: slot, value: publicKey);
  }

  static Future<String> newCode() async =>
      'v2.${base64UrlEncode(await (await aes.newSecretKey()).extractBytes())}';
  static void validateCode(String code) {
    if (!code.startsWith('v2.') ||
        base64Url.decode(code.substring(3)).length != 32) {
      throw const FormatException('Неверный код восстановления');
    }
  }

  static Future<String> proof(String code) async {
    validateCode(code);
    return base64Encode(await hash(['viora-recovery-auth', code]));
  }

  static Future<Map<String, dynamic>> wrap(
    String uid,
    List<int> seed,
    String code,
  ) async {
    validateCode(code);
    final box = await aes.encrypt(
      seed,
      secretKey: SecretKey(await hash(['viora-recovery-key', code])),
      aad: utf8.encode(uid),
    );
    return {
      'v': 1,
      'iv': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  static Future<List<int>> unwrap(
    String uid,
    Map<String, dynamic> b,
    String code,
  ) async {
    validateCode(code);
    return aes.decrypt(
      SecretBox(
        base64Decode(b['cipher'] as String),
        nonce: base64Decode(b['iv'] as String),
        mac: Mac(base64Decode(b['tag'] as String)),
      ),
      secretKey: SecretKey(await hash(['viora-recovery-key', code])),
      aad: utf8.encode(uid),
    );
  }
}
