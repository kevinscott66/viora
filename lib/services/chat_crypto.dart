import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'chat_vault.dart';
import 'social_api.dart';

class ChatCipher {
  static final aes = AesGcm.with256bits();
  static Future<String> fingerprint(List<int> key) async =>
      (await Sha256().hash(
        key,
      )).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  static List<int> aad(String room, String sender, String nonce) =>
      utf8.encode(jsonEncode(['viora-chat', 1, room, sender, nonce]));
  static Future<Map<String, dynamic>> encrypt(
    List<int> key,
    String room,
    String sender,
    String nonce,
    Map<String, dynamic> payload,
  ) async {
    final bytes = utf8.encode(jsonEncode(payload));
    if (bytes.length > 8192) throw SocialError('Сообщение слишком длинное');
    final box = await aes.encrypt(
      bytes,
      secretKey: SecretKey(key),
      aad: aad(room, sender, nonce),
    );
    return {
      'v': 1,
      'key': await fingerprint(key),
      'iv': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  static Future<Map<String, dynamic>> decrypt(
    List<int> key,
    String room,
    String sender,
    String nonce,
    Map<String, dynamic> envelope,
  ) async {
    if (envelope['v'] != 1 || envelope['key'] != await fingerprint(key)) {
      throw SocialError('Нужен ключ этого диалога');
    }
    final clear = await aes.decrypt(
      SecretBox(
        base64Decode(envelope['cipher'] as String),
        nonce: base64Decode(envelope['iv'] as String),
        mac: Mac(base64Decode(envelope['tag'] as String)),
      ),
      secretKey: SecretKey(key),
      aad: aad(room, sender, nonce),
    );
    final result = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    if (result['text'] is! String) {
      throw const FormatException('Invalid message');
    }
    return result;
  }
}

class ChatCrypto {
  ChatCrypto(this.api);
  final SocialApi api;
  static final _setups = Expando<Future<void>>();
  Future<void> ensureIdentity() async {
    if (_setups[api] != null) return _setups[api];
    final task = _initialize();
    _setups[api] = task;
    try {
      await task;
    } finally {
      _setups[api] = null;
    }
  }

  Future<void> _initialize() async {
    final p = await api.request('GET', '/api/identity');
    final uid = p['user'] as String;
    var seed = await ChatVault.read(uid);
    if (seed == null && p['publicKey'] != null) {
      throw SocialError(
        'Войдите по коду восстановления из профиля на прежнем устройстве.',
      );
    }
    seed ??= await ChatVault.create(uid);
    final pub = await ChatVault.publicKey(seed);
    if (p['publicKey'] != null && p['publicKey'] != pub) {
      throw SocialError('Ключ профиля не совпадает. Нужен код восстановления.');
    }
    if (p['publicKey'] == null) {
      await api.request('POST', '/api/identity', {'publicKey': pub});
    }
  }

  Future<String> createRecovery() async {
    await ensureIdentity();
    final identity = await api.request('GET', '/api/identity');
    final uid = identity['user'] as String;
    final seed = await ChatVault.read(uid);
    if (seed == null) throw SocialError('Не найден доступ к переписке');
    final code = await ChatVault.newCode();
    await api.request('POST', '/api/recovery-v2', {
      'proof': await ChatVault.proof(code),
      'backup': await ChatVault.wrap(uid, seed, code),
    });
    return code;
  }

  Future<Map<String, dynamic>> status(String room) async {
    await ensureIdentity();
    final s = await api.request('GET', '/api/chats/$room/security');
    if (s['peerKey'] == null) {
      throw SocialError(
        'Защита включится, когда собеседник откроет диалог в новой версии viora.',
      );
    }
    await ChatVault.pin(
      s['user'] as String,
      s['peer'] as String,
      s['peerKey'] as String,
    );
    final seed = await ChatVault.read(s['user'] as String);
    if (seed == null) throw SocialError('Восстановите доступ через профиль');
    return {
      ...s,
      'localKey': await ChatVault.roomKey(seed, s['peerKey'] as String, room),
    };
  }

  Future<void> send(String room, Map<String, dynamic> payload) async {
    final s = await status(room);
    final key = s['localKey'] as List<int>;
    // Server permanently disables legacy plaintext when both public keys agree.
    await api.request('POST', '/api/chats/$room/security', {
      'keyId': s['keyId'],
    });
    final nonce = payload['nonce'] as String;
    final envelope = await ChatCipher.encrypt(
      key,
      room,
      s['user'] as String,
      nonce,
      {'text': payload['text'] ?? '', 'moment': payload['moment']},
    );
    envelope['key'] = s['keyId'];
    await api.request('POST', '/api/chats/$room/messages', {
      'nonce': nonce,
      'encrypted': envelope,
    });
  }

  Future<List<dynamic>> decode(String room, List<dynamic> rows) async {
    if (!rows.any((r) => r['encrypted'] != null)) return rows;
    Map<String, dynamic>? s;
    try {
      s = await status(room);
    } catch (_) {
      /* Preserve readable legacy history. */
    }
    final out = <dynamic>[];
    for (final row in rows) {
      if (row['encrypted'] == null) {
        out.add(row);
        continue;
      }
      try {
        if (s == null) throw StateError('Key unavailable');
        final e = Map<String, dynamic>.from(row['encrypted'] as Map);
        if (e['key'] != s['keyId']) throw StateError('Key changed');
        final key = s['localKey'] as List<int>;
        e['key'] = await ChatCipher.fingerprint(key);
        final clear = await ChatCipher.decrypt(
          key,
          room,
          row['sender'] as String,
          row['nonce'] as String,
          e,
        );
        out.add({...row, 'text': clear['text'], 'moment': clear['moment']});
      } catch (_) {
        out.add({
          ...row,
          'text': 'Восстановите доступ к сообщениям в профиле.',
          'moment': null,
          'decryptionFailed': true,
        });
      }
    }
    return out;
  }
}
