# Architecture

Flutter/Dart owns the local library, playback, UI and client cryptography. `lib/controllers/music_controller.dart` orchestrates imports and queues. Native `MusicStore` streams selected files into application Documents/Music, using digest-derived filenames and checked manifest names. Web import remains session-local. `just_audio` and `just_audio_background` handle playback and OS media integration.

Diary and favorite-fragment stores validate record IDs before local file access. No personal collection is bundled. Fictional mood fixtures demonstrate station selection and migration behavior without carrying a real library. Do not substitute private catalog exports in a public change.

The optional Python stdlib social API uses SQLite, loopback binding, hashed bearer sessions, room membership checks, consumed invitations and owner-scoped session revocation. Deployers own TLS, data permissions, backups and trusted-proxy configuration. APNs is optional and externally configured. The public client deliberately leaves its service endpoint unset.

Current short-link sharing uploads the explicitly selected moment/card payload to the configured service. Links are unlisted, not confidential. Legacy fragment links decode their payload in the browser. `moment-site` uses validated payloads and `textContent` for display.

Chat identity seeds and first-use peer pins use FlutterSecureStorage. X25519/HKDF and AES-GCM bind ciphertext to room/sender/nonce. Recovery wraps an identity seed with a code-derived key, sends a separate proof and verifies the recovered public key. Existing plaintext history remains distinguishable. This protocol does not provide forward secrecy or post-compromise security, and its first peer observation depends on the server directory.

No production infrastructure map, private documentation, device identity, signing profile, original repository history or personal media is part of this public snapshot.

## Demo captures

`docs/media` contains actual UI screenshots from a disposable Flutter harness with fictional records and original generated demo covers. A fake player supplies a 60/180 second position without audio or network. The harness is excluded from this repository.
