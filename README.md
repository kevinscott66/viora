# Viora

A Flutter music app for a personal library. Import your own audio, keep favorites, manage playback queues and listen in the background on supported native platforms. The source also includes mood selection, favorite fragments, moments and an optional Python/SQLite social service.

**Status:** active local development; public source snapshot. No App Store availability or independent cryptographic audit is claimed.

[Русский](README.ru.md) · [Portfolio](https://dobropalm.tech/#viora) · [Author](https://github.com/kevinscott66)


## Interface preview

![Viora home screen](docs/media/viora-home-demo.png)

[Player screen](docs/media/viora-player-demo.png). Captured from the actual Flutter interface in a disposable demo build. Track names, artists and covers are fictional; playback is simulated at 1:00 of 3:00, without audio.


## Run locally

Requires Flutter with Dart 3.11.4 or later compatible with the lockfile.

```sh
flutter pub get
flutter run
```

Import audio through the system file picker. Native imports persist in app storage. Web import lasts for the current browser session. Codec support depends on the platform. DRM-protected recordings are unsupported. iOS signing requires your own team and provisioning; no signing material is included.

## Optional social service

The client has no configured API endpoint by default. Local music remains available. For a separate development service, set `VIORA_API_BASE` with `--dart-define`, and adapt the example public-link host `viora.example.com` to your own domain in client/server/link platform settings. Do not point a test build at another person's deployment.

```sh
cd social-server
VIORA_DB=/tmp/viora-development.sqlite3 python3 server.py
```

The server binds loopback. For deployment, supply your own TLS proxy and data directory. It uses the socket client address for rate limiting by default. Only set `VIORA_TRUST_PROXY=1` when a trusted proxy overwrites `X-Real-IP` and direct access is blocked. Optional APNs configuration comes from environment variables and your own private key file; no push credentials are included.

## Checks

```sh
flutter analyze
flutter test
NO_PROXY=127.0.0.1,localhost python3 -m unittest discover -s social-server -p 'test*.py'
node --test moment-site/*.test.cjs
flutter build web
```

`NO_PROXY` keeps local server tests independent of an ambient HTTP proxy. Physical-device playback, keychain and codec acceptance have a separate verification cycle.

## Public source boundary

This is a fresh sanitized snapshot, with no original Git history. It contains no personal audio, covers, lyrics, track catalog, listening history, artist metadata, library hashes, analysis/source tables, device backups, signed packages, server configuration or credentials. Mood assets contain only explicitly fictional test metadata; they do not include audio. Brand artwork and licensed fonts remain.

## Privacy and limits

Local library and diagnostics stay in app storage. Public moment/card links deliberately publish their selected metadata to the configured service; anyone holding such a link can read the payload. Public links are distinct from encrypted chat.

Chats use X25519/HKDF and AES-GCM with first-use peer-key pinning. They do not implement Signal/Double Ratchet, forward secrecy or post-compromise security. Legacy plaintext history is not retroactively encrypted. Initial peer authenticity depends on the server directory and out-of-band fingerprint comparison.

[Architecture](docs/architecture.md) · [Security](SECURITY.md)

Source publication does not certify security or deployed-service availability. The source is available under the [MIT License](LICENSE). Third-party fonts and dependencies retain their own licenses.
