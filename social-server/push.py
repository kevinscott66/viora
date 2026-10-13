"""Optional APNs delivery. No message text, names or lyrics leave the service."""
import os, time
from contextlib import closing


def topics():
    return {v.strip() for v in os.environ.get('VIORA_APNS_TOPICS', '').split(',') if v.strip()}


def configured():
    return bool(topics() and all(os.environ.get(k) for k in
        ('VIORA_APNS_KEY_FILE', 'VIORA_APNS_KEY_ID', 'VIORA_APNS_TEAM_ID')))


def initialize(d):
    d.executescript('''
    CREATE TABLE IF NOT EXISTS push_devices(
      session TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
      token TEXT NOT NULL, topic TEXT NOT NULL, UNIQUE(token,topic));
    CREATE TABLE IF NOT EXISTS push_jobs(
      session TEXT NOT NULL REFERENCES push_devices(session) ON DELETE CASCADE,
      room TEXT NOT NULL REFERENCES rooms(id), message INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, due INTEGER NOT NULL,
      expires INTEGER NOT NULL, PRIMARY KEY(session,room));
    ''')


def enqueue(d, room, sender, message, now):
    # Coalesce pending notifications per room/device. Idempotent message retries
    # never call this function; job updates cannot duplicate the original message.
    d.execute('''INSERT INTO push_jobs(session,room,message,due,expires)
      SELECT p.session,r.id,?,?,? FROM push_devices p JOIN sessions s ON s.id=p.session
      JOIN rooms r ON r.id=? WHERE (s.owner=r.owner OR s.owner=r.guest) AND s.owner<>?
      ON CONFLICT(session,room) DO UPDATE SET message=excluded.message,
      due=excluded.due,expires=excluded.expires,attempts=0''',
      (message,now,now+86400,room,sender))


class Provider:
    def __init__(self):
        import httpx
        import jwt
        from pathlib import Path
        self.jwt = jwt
        self.key = Path(os.environ['VIORA_APNS_KEY_FILE']).read_text()
        self.client = httpx.Client(http2=True, timeout=10, trust_env=False)
        self.token = None
        self.issued = 0

    def send(self, job):
        now = int(time.time())
        if not self.token or now-self.issued >= 3000:
            self.token = self.jwt.encode({'iss':os.environ['VIORA_APNS_TEAM_ID'],'iat':now},
                self.key, algorithm='ES256', headers={'kid':os.environ['VIORA_APNS_KEY_ID']})
            self.issued = now
        response = self.client.post('https://api.push.apple.com/3/device/'+job['token'],
            headers={'authorization':'bearer '+self.token,'apns-topic':job['topic'],
              'apns-push-type':'alert','apns-priority':'10',
              'apns-expiration':str(job['expires']),'apns-collapse-id':job['room']},
            json={'aps':{'alert':{'title':'viora','body':'Новое сообщение в диалоге'},'sound':'default'},'room':job['room']})
        reason = ''
        if response.status_code != 200:
            try: reason = response.json().get('reason','')
            except (ValueError, AttributeError): pass
        return response.status_code, reason


def deliver_one(connect, provider, now=None):
    now = int(time.time()) if now is None else now
    with closing(connect()) as d, d:
        d.execute('BEGIN IMMEDIATE')
        d.execute('DELETE FROM push_jobs WHERE expires<=? OR attempts>=12',(now,))
        row = d.execute('''SELECT j.*,p.token,p.topic FROM push_jobs j
          JOIN push_devices p ON p.session=j.session WHERE due<=? ORDER BY due LIMIT 1''',(now,)).fetchone()
        if not row: return False
        job = dict(row)
        d.execute('UPDATE push_jobs SET due=?,attempts=attempts+1 WHERE session=? AND room=?',
                  (now+60,job['session'],job['room']))
    try: status, reason = provider.send(job)
    except Exception: status, reason = 503, ''
    with closing(connect()) as d, d:
        if status == 410 or reason in ('BadDeviceToken','DeviceTokenNotForTopic'):
            # Do not erase a token refreshed while the request was in flight.
            d.execute('DELETE FROM push_devices WHERE session=? AND token=? AND topic=?',
                      (job['session'],job['token'],job['topic']))
        elif status == 200 or (status == 400 and reason not in ('ExpiredProviderToken',)):
            d.execute('DELETE FROM push_jobs WHERE session=? AND room=? AND message=?',
                      (job['session'],job['room'],job['message']))
        else:
            d.execute('UPDATE push_jobs SET due=? WHERE session=? AND room=? AND message=?',
                (now+min(3600,30*2**min(job['attempts'],7)),job['session'],job['room'],job['message']))
    return True


def run(connect):
    provider = Provider()
    while True:
        try:
            if not deliver_one(connect, provider): time.sleep(2)
        except Exception:
            # Never log device tokens, provider credentials or message bodies.
            time.sleep(5)


if __name__ == '__main__':
    from server import connect, initialize as init
    if not configured(): raise SystemExit('APNs configuration required')
    init()
    run(connect)
