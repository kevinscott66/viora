"""Private invite-only chats and unlisted moment links. Python 3.10+, stdlib."""
import base64, hashlib, json, os, re, secrets, sqlite3, time
from contextlib import closing
import push
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB = os.environ.get('VIORA_DB', 'viora.sqlite3')
def connect():
    db = sqlite3.connect(DB, timeout=15)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    return db

def initialize():
    with closing(connect()) as d, d:
        d.executescript('''
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, token TEXT UNIQUE NOT NULL, name TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS rooms(id TEXT PRIMARY KEY, owner TEXT NOT NULL REFERENCES users(id), guest TEXT REFERENCES users(id), invite TEXT UNIQUE, expires INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY AUTOINCREMENT, room TEXT NOT NULL REFERENCES rooms(id), sender TEXT NOT NULL REFERENCES users(id), nonce TEXT NOT NULL, text TEXT NOT NULL, moment TEXT, created INTEGER NOT NULL, UNIQUE(sender,nonce));
        CREATE INDEX IF NOT EXISTS messages_room ON messages(room,id);
        CREATE TABLE IF NOT EXISTS moments(id TEXT PRIMARY KEY, owner TEXT NOT NULL REFERENCES users(id), payload TEXT NOT NULL, created INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS cards(id TEXT PRIMARY KEY, owner TEXT UNIQUE NOT NULL REFERENCES users(id), payload TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS account_keys(owner TEXT PRIMARY KEY REFERENCES users(id), public_key TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS recovery_keys(owner TEXT PRIMARY KEY REFERENCES users(id), proof TEXT UNIQUE NOT NULL, backup TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS secure_rooms(room TEXT PRIMARY KEY REFERENCES rooms(id), key_id TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS encrypted_messages(message INTEGER PRIMARY KEY REFERENCES messages(id), payload TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS profiles(owner TEXT PRIMARY KEY REFERENCES users(id), bio TEXT NOT NULL DEFAULT '', color TEXT NOT NULL DEFAULT 'rose');
        CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY, owner TEXT NOT NULL REFERENCES users(id), token TEXT UNIQUE NOT NULL, label TEXT NOT NULL, created INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS recovery(owner TEXT PRIMARY KEY REFERENCES users(id), code TEXT UNIQUE NOT NULL);
        CREATE TABLE IF NOT EXISTS limits(key TEXT PRIMARY KEY, count INTEGER NOT NULL, expires INTEGER NOT NULL);
        ''')
        # Idempotent migration: preserve existing bearer tokens and chat ownership.
        d.execute('CREATE TABLE IF NOT EXISTS migrations(name TEXT PRIMARY KEY)')
        if not d.execute("SELECT 1 FROM migrations WHERE name='sessions-v1'").fetchone():
            d.execute('INSERT OR IGNORE INTO sessions SELECT id,id,token,?,? FROM users', ('Первое устройство',0))
            d.execute("INSERT INTO migrations VALUES ('sessions-v1')")
        push.initialize(d)

def b64(value,length=None,maximum=8192):
    if not isinstance(value,str): raise ValueError()
    raw=base64.b64decode(value,validate=True)
    if not 1<=len(raw)<=maximum or (length is not None and len(raw)!=length): raise ValueError()
    return value

def envelope(value,backup=False):
    fields={'v','iv','cipher','tag'} if backup else {'v','iv','cipher','tag','key'}
    if not isinstance(value,dict) or set(value)!=fields or type(value.get('v'))!=int or value['v']!=1: raise ValueError()
    b64(value['iv'],12);b64(value['tag'],16);b64(value['cipher'],32 if backup else None)
    return value

def room_keys(d,room):
    row=d.execute('SELECT r.owner,r.guest,a.public_key AS a,b.public_key AS b FROM rooms r LEFT JOIN account_keys a ON a.owner=r.owner LEFT JOIN account_keys b ON b.owner=r.guest WHERE r.id=?',(room,)).fetchone()
    kid=digest(json.dumps([room,row['owner'],row['a'],row['guest'],row['b']],separators=(',',':'))) if row and row['a'] and row['b'] else None
    return row,kid

def moment(m, parent=False):
    if not isinstance(m, dict) or m.get('v') != 1: raise ValueError()
    out = {'v': 1}
    for key, limit in [('title',300), ('note',500), ('lyric',150)]:
        v = m.get(key, '')
        if not isinstance(v,str) or len(v)>limit or (key=='title' and not v.strip()): raise ValueError()
        out[key]=v
    a=m.get('artists'); sec=m.get('seconds')
    if not isinstance(a,list) or not 1<=len(a)<=30 or any(not isinstance(x,str) or not x.strip() or len(x)>200 for x in a): raise ValueError()
    if type(sec)!=int or not 0<=sec<=86400: raise ValueError()
    out.update(artists=a,seconds=sec)
    source=m.get('source')
    if isinstance(source,str) and len(source)<=2048:
        from urllib.parse import urlsplit
        u=urlsplit(source)
        allowed={'open.spotify.com','www.deezer.com','deezer.com','music.apple.com','music.yandex.ru','music.yandex.com','soundcloud.com','www.youtube.com','youtu.be'}
        if u.scheme=='https' and u.hostname in allowed and not u.username and not u.password:
            out['source']=source
    if 'replyTo' in m:
        if parent: raise ValueError()
        out['replyTo']=moment(m['replyTo'],True)
        out['replyTo']['note']=''
    return out

def music_card(value):
    if not isinstance(value,dict) or value.get('v') != 1: raise ValueError()
    name=value.get('name');lyric=value.get('lyric');theme=value.get('theme');tracks=value.get('tracks')
    if not isinstance(name,str) or not 1<=len(name.strip())<=50: raise ValueError()
    if not isinstance(lyric,str) or len(lyric)>150 or theme not in ('rose','ocean','violet'): raise ValueError()
    if not isinstance(tracks,list) or len(tracks)!=3: raise ValueError()
    clean=[]
    for track in tracks:
        m=moment(track)
        clean.append({k:m[k] for k in ('v','title','artists','seconds','source') if k in m} | {'note':'','lyric':''})
    if len({(t['title'].strip().casefold(),tuple(a.casefold() for a in t['artists'])) for t in clean})!=3: raise ValueError()
    return {'v':1,'name':name.strip(),'lyric':lyric,'theme':theme,'tracks':clean}

def digest(s): return hashlib.sha256(s.encode()).hexdigest()
class Request(BaseHTTPRequestHandler):
    def log_message(self,*args): pass # Do not log tokens, invites, message bodies.
    def send(self,status,data):
        raw=json.dumps(data,ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Cache-Control','no-store')
        self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Content-Length',str(len(raw)))
        self.end_headers();self.wfile.write(raw)
    def do_GET(self): self.handle_api()
    def do_POST(self): self.handle_api()
    def handle_api(self):
        try:
            with closing(connect()) as d, d:
                # Proxy must overwrite this header; bind only to loopback.
                ip=(self.headers.get('X-Real-IP',self.client_address[0])
                    if os.environ.get('VIORA_TRUST_PROXY') == '1' else self.client_address[0])
                now=int(time.time()); bucket=now//60
                key=digest(ip)+':'+str(bucket)
                d.execute('DELETE FROM limits WHERE expires<?',(now,))
                d.execute('INSERT INTO limits VALUES (?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1',(key,now+120))
                count=d.execute('SELECT count FROM limits WHERE key=?',(key,)).fetchone()[0]
                d.commit()
                if count>180: return self.send(429,{'error':'Слишком много запросов. Попробуйте позже.'})
                body={}
                if self.command=='POST':
                    size=int(self.headers.get('Content-Length','0'))
                    if size<1 or size>16384: return self.send(413,{'error':'Слишком большое сообщение'})
                    body=json.loads(self.rfile.read(size))
                    if not isinstance(body,dict): raise ValueError()
                path=self.path.split('?')[0].rstrip('/')
                if self.command=='GET' and path=='/api/health': return self.send(200,{'ok':True})
                if self.command=='POST' and path=='/api/register':
                    k=digest(ip)+':registration:'+str(now//3600)
                    d.execute('INSERT INTO limits VALUES (?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1',(k,now+3600))
                    n=d.execute('SELECT count FROM limits WHERE key=?',(k,)).fetchone()[0]
                    d.commit()
                    if n>10: return self.send(429,{'error':'Попробуйте создать профиль позже'})
                    token=secrets.token_urlsafe(32);uid=secrets.token_urlsafe(12)
                    d.execute('INSERT INTO users VALUES (?,?,?)',(uid,digest(token),'Слушатель'))
                    d.execute('INSERT INTO sessions VALUES (?,?,?,?,?)',(uid,uid,digest(token),'Первое устройство',now))
                    d.commit();return self.send(201,{'id':uid,'token':token,'name':'Слушатель'})
                match=re.fullmatch('/api/moments/([A-Za-z0-9_-]{16})',path)
                if self.command=='GET' and match:
                    row=d.execute('SELECT payload FROM moments WHERE id=?',(match[1],)).fetchone()
                    return self.send(200,json.loads(row[0])) if row else self.send(404,{'error':'Момент не найден'})
                match=re.fullmatch('/api/cards/([A-Za-z0-9_-]{16})',path)
                if self.command=='GET' and match:
                    row=d.execute('SELECT payload FROM cards WHERE id=?',(match[1],)).fetchone()
                    return self.send(200,json.loads(row[0])) if row else self.send(404,{'error':'Визитка не опубликована'})
                if self.command=='POST' and path=='/api/recover-v2':
                    proof=b64(body.get('proof'),32)
                    d.execute('BEGIN IMMEDIATE')
                    row=d.execute('SELECT r.owner,r.backup,k.public_key FROM recovery_keys r JOIN account_keys k ON k.owner=r.owner WHERE proof=?',(digest(proof),)).fetchone()
                    if not row:return self.send(403,{'error':'Неверный код восстановления'})
                    if d.execute('SELECT count(*) FROM sessions WHERE owner=?',(row['owner'],)).fetchone()[0]>=20:return self.send(409,{'error':'Отключите старое устройство'})
                    token=secrets.token_urlsafe(32)
                    d.execute('INSERT INTO sessions VALUES (?,?,?,?,?)',(secrets.token_urlsafe(12),row['owner'],digest(token),'iPhone',now));d.commit()
                    return self.send(200,{'token':token,'user':row['owner'],'publicKey':row['public_key'],'backup':json.loads(row['backup'])})
                if self.command=='POST' and path=='/api/recover':
                    code=body.get('code',''); label=body.get('label','iPhone')
                    if not isinstance(code,str) or not re.fullmatch('[A-Za-z0-9_-]{43}',code) or not isinstance(label,str) or not 1<=len(label)<=50: raise ValueError()
                    d.execute('BEGIN IMMEDIATE')
                    row=d.execute('SELECT owner FROM recovery WHERE code=?',(digest(code),)).fetchone()
                    if not row: return self.send(403,{'error':'Неверный код восстановления'})
                    if d.execute('SELECT count(*) FROM sessions WHERE owner=?',(row['owner'],)).fetchone()[0]>=20: return self.send(409,{'error':'Удалите старое устройство перед подключением нового'})
                    token=secrets.token_urlsafe(32)
                    d.execute('INSERT INTO sessions VALUES (?,?,?,?,?)',(secrets.token_urlsafe(12),row['owner'],digest(token),label,now));d.commit()
                    return self.send(200,{'token':token})
                auth=self.headers.get('Authorization','')
                user=d.execute('SELECT u.id,u.name,s.id AS session FROM sessions s JOIN users u ON u.id=s.owner WHERE s.token=?',(digest(auth[7:]) if auth.startswith('Bearer ') else '',)).fetchone()
                if not user: return self.send(401,{'error':'Нет доступа к профилю'})
                uid=user['id']
                if path=='/api/identity':
                    d.execute('BEGIN IMMEDIATE')
                    row=d.execute('SELECT public_key FROM account_keys WHERE owner=?',(uid,)).fetchone()
                    if self.command=='POST':
                        pub=b64(body.get('publicKey'),32)
                        if row and row[0]!=pub:return self.send(409,{'error':'Ключ уже существует. Восстановите профиль по коду.'})
                        d.execute('INSERT OR IGNORE INTO account_keys VALUES (?,?)',(uid,pub));d.commit()
                        return self.send(200,{'user':uid,'publicKey':pub})
                    return self.send(200,{'user':uid,'publicKey':row[0] if row else None})
                if self.command=='POST' and path=='/api/recovery-v2':
                    proof=b64(body.get('proof'),32);backup=envelope(body.get('backup'),True)
                    if not d.execute('SELECT 1 FROM account_keys WHERE owner=?',(uid,)).fetchone():raise ValueError()
                    d.execute('INSERT INTO recovery_keys VALUES (?,?,?) ON CONFLICT(owner) DO UPDATE SET proof=excluded.proof,backup=excluded.backup',(uid,digest(proof),json.dumps(backup)))
                    d.execute('DELETE FROM recovery WHERE owner=?',(uid,));d.commit()
                    return self.send(200,{'ok':True})
                if path=='/api/push' and self.command=='GET':
                    return self.send(200,{'available':push.configured(),'registered':bool(d.execute('SELECT 1 FROM push_devices WHERE session=?',(user['session'],)).fetchone())})
                if path=='/api/push' and self.command=='POST':
                    if body.get('enabled') is False:
                        d.execute('DELETE FROM push_devices WHERE session=?',(user['session'],));d.commit()
                        return self.send(200,{'ok':True})
                    if not push.configured(): return self.send(503,{'error':'Уведомления пока не подключены'})
                    token=body.get('token');topic=body.get('topic')
                    if not isinstance(token,str) or not re.fullmatch('[a-fA-F0-9]{64,512}',token) or not isinstance(topic,str) or topic not in push.topics(): raise ValueError()
                    d.execute('BEGIN IMMEDIATE')
                    # A token belongs to one active login; switching accounts removes old jobs.
                    d.execute('DELETE FROM push_devices WHERE (token=? AND topic=?) OR session=?',(token.lower(),topic,user['session']))
                    d.execute('INSERT INTO push_devices VALUES (?,?,?)',(user['session'],token.lower(),topic));d.commit()
                    return self.send(200,{'ok':True})
                if path=='/api/card':
                    if self.command=='POST':
                        payload=music_card(body)
                        d.execute('INSERT INTO cards VALUES (?,?,?) ON CONFLICT(owner) DO UPDATE SET payload=excluded.payload',(secrets.token_urlsafe(12),uid,json.dumps(payload)));d.commit()
                    row=d.execute('SELECT id,payload FROM cards WHERE owner=?',(uid,)).fetchone()
                    return self.send(200,{'url':'https://viora.example.com/p/'+row['id'],'card':json.loads(row['payload'])} if row else {'url':None})
                if self.command=='POST' and path=='/api/card/unpublish':
                    d.execute('DELETE FROM cards WHERE owner=?',(uid,));d.commit()
                    return self.send(200,{'ok':True})
                if path=='/api/profile':
                    if self.command=='POST':
                        name=body.get('name');bio=body.get('bio','');color=body.get('color','rose')
                        if not isinstance(name,str) or not 1<=len(name.strip())<=50 or not isinstance(bio,str) or len(bio)>200 or color not in ['rose','ocean','dusk']: raise ValueError()
                        d.execute('UPDATE users SET name=? WHERE id=?',(name.strip(),uid))
                        d.execute('INSERT INTO profiles VALUES (?,?,?) ON CONFLICT(owner) DO UPDATE SET bio=excluded.bio,color=excluded.color',(uid,bio,color));d.commit()
                    profile=d.execute('SELECT bio,color FROM profiles WHERE owner=?',(uid,)).fetchone()
                    name=d.execute('SELECT name FROM users WHERE id=?',(uid,)).fetchone()[0]
                    return self.send(200,{'id':uid,'name':name,'bio':profile['bio'] if profile else '', 'color':profile['color'] if profile else 'rose','hasKeyRecovery':bool(d.execute('SELECT 1 FROM recovery_keys WHERE owner=?',(uid,)).fetchone()),'hasRecovery':bool(d.execute('SELECT 1 FROM recovery WHERE owner=? UNION SELECT 1 FROM recovery_keys WHERE owner=?',(uid,uid)).fetchone())})
                if self.command=='POST' and path=='/api/recovery':
                    if d.execute('SELECT 1 FROM account_keys WHERE owner=?',(uid,)).fetchone():return self.send(409,{'error':'Обновите приложение для создания кода с ключами переписки'})
                    code=secrets.token_urlsafe(32)
                    d.execute('INSERT INTO recovery VALUES (?,?) ON CONFLICT(owner) DO UPDATE SET code=excluded.code',(uid,digest(code)));d.commit()
                    return self.send(200,{'code':code})
                if self.command=='GET' and path=='/api/sessions':
                    rows=d.execute('SELECT id,label,created FROM sessions WHERE owner=? ORDER BY created DESC',(uid,)).fetchall()
                    return self.send(200,{'sessions':[{**dict(r),'current':r['id']==user['session']} for r in rows]})
                if self.command=='POST' and path=='/api/sessions/revoke':
                    sid=body.get('id')
                    if not isinstance(sid,str): raise ValueError()
                    if sid==user['session']: return self.send(400,{'error':'Нельзя отключить текущее устройство'})
                    d.execute('DELETE FROM sessions WHERE owner=? AND id=?',(uid,sid));d.commit()
                    return self.send(200,{'ok':True})
                if self.command=='POST' and path=='/api/moments':
                    payload=moment(body);code=secrets.token_urlsafe(12)
                    if d.execute('SELECT count(*) FROM moments WHERE owner=?',(uid,)).fetchone()[0]>=10000: return self.send(429,{'error':'Лимит моментов достигнут'})
                    d.execute('INSERT INTO moments VALUES (?,?,?,?)',(code,uid,json.dumps(payload),now));d.commit()
                    return self.send(201,{'url':'https://viora.example.com/m/'+code})
                if path=='/api/chats':
                    if self.command=='POST':
                        if d.execute('SELECT count(*) FROM rooms WHERE owner=?',(uid,)).fetchone()[0]>=100: return self.send(429,{'error':'Лимит диалогов достигнут'})
                        room=secrets.token_urlsafe(12);invite=secrets.token_urlsafe(24)
                        d.execute('INSERT INTO rooms VALUES (?,?,NULL,?,?)',(room,uid,digest(invite),now+604800));d.commit()
                        return self.send(201,{'id':room,'invite':'https://viora.example.com/c/'+invite})
                    rows=d.execute('SELECT r.id, CASE WHEN r.owner=? THEN g.name ELSE o.name END AS name, r.guest IS NULL AS waiting FROM rooms r JOIN users o ON o.id=r.owner LEFT JOIN users g ON g.id=r.guest WHERE r.owner=? OR r.guest=? ORDER BY r.rowid DESC',(uid,uid,uid)).fetchall()
                    return self.send(200,{'chats':[dict(r) for r in rows]})
                if self.command=='POST' and path=='/api/join':
                    invite=body.get('invite','')
                    if not isinstance(invite,str) or not re.fullmatch('[A-Za-z0-9_-]{32}',invite): raise ValueError()
                    d.execute('BEGIN IMMEDIATE')
                    room=d.execute('SELECT * FROM rooms WHERE invite=? AND expires>?',(digest(invite),now)).fetchone()
                    if not room: return self.send(404,{'error':'Приглашение истекло или уже использовано'})
                    if room['owner']==uid: return self.send(400,{'error':'Это ваше приглашение'})
                    d.execute('UPDATE rooms SET guest=?,invite=NULL WHERE id=? AND guest IS NULL',(uid,room['id']));d.commit()
                    return self.send(200,{'id':room['id']})
                match=re.fullmatch('/api/chats/([A-Za-z0-9_-]{16})/security',path)
                if match:
                    room=match[1];d.execute('BEGIN IMMEDIATE')
                    row,kid=room_keys(d,room)
                    if not row or uid not in (row['owner'],row['guest']):return self.send(404,{'error':'Диалог не найден'})
                    if self.command=='POST':
                        if not kid or body.get('keyId')!=kid:return self.send(409,{'error':'Собеседник ещё не включил защиту'})
                        existing=d.execute('SELECT key_id FROM secure_rooms WHERE room=?',(room,)).fetchone()
                        if existing and existing[0]!=kid:return self.send(409,{'error':'Ключ диалога изменился'})
                        d.execute('INSERT OR IGNORE INTO secure_rooms VALUES (?,?)',(room,kid));d.commit()
                    return self.send(200,{'user':uid,'peer':row['guest'] if uid==row['owner'] else row['owner'],'peerKey':row['b'] if uid==row['owner'] else row['a'],'keyId':kid})
                match=re.fullmatch('/api/chats/([A-Za-z0-9_-]{16})/messages',path)
                if match:
                    room=match[1]
                    member=d.execute('SELECT * FROM rooms WHERE id=? AND (owner=? OR guest=?)',(room,uid,uid)).fetchone()
                    if not member: return self.send(404,{'error':'Диалог не найден'})
                    if self.command=='POST':
                        d.execute('BEGIN IMMEDIATE')
                        secured=d.execute('SELECT key_id FROM secure_rooms WHERE room=?',(room,)).fetchone()
                        nonce=body.get('nonce','')
                        if not isinstance(nonce,str) or not re.fullmatch('[A-Za-z0-9_-]{16,64}',nonce):raise ValueError()
                        sealed=None
                        if secured:
                            if body.get('text') or body.get('moment') is not None:return self.send(409,{'error':'Диалог защищён. Обновите приложение.'})
                            sealed=envelope(body.get('encrypted'))
                            if sealed['key']!=secured[0]:raise ValueError()
                            text='';m=None
                        else:
                            if 'encrypted' in body:raise ValueError()
                            text=body.get('text','')
                            if not isinstance(text,str) or len(text)>2000:raise ValueError()
                            m=moment(body['moment']) if body.get('moment') is not None else None
                            if not text.strip() and m is None:raise ValueError()
                        inserted=d.execute('INSERT OR IGNORE INTO messages(room,sender,nonce,text,moment,created) VALUES (?,?,?,?,?,?)',(room,uid,nonce,text,json.dumps(m) if m else None,now))
                        if inserted.rowcount:
                            if sealed:d.execute('INSERT INTO encrypted_messages VALUES (?,?)',(inserted.lastrowid,json.dumps(sealed)))
                            push.enqueue(d,room,uid,inserted.lastrowid,now)
                        d.commit()
                        return self.send(200,{'ok':True})
                    from urllib.parse import parse_qs,urlsplit
                    before=int(parse_qs(urlsplit(self.path).query).get('before',['9223372036854775807'])[0])
                    rows=d.execute('SELECT id,sender,nonce,text,moment,created FROM messages WHERE room=? AND id<? ORDER BY id DESC LIMIT 100',(room,before)).fetchall()
                    out=[]
                    for r in reversed(rows):
                        v=dict(r);v['moment']=json.loads(v['moment']) if v['moment'] else None;v['mine']=v['sender']==uid
                        sealed=d.execute('SELECT payload FROM encrypted_messages WHERE message=?',(v['id'],)).fetchone()
                        if sealed:v['encrypted']=json.loads(sealed[0])
                        out.append(v)
                    return self.send(200,{'messages':out})
                self.send(404,{'error':'Не найдено'})
        except (ValueError,TypeError,KeyError,AttributeError,json.JSONDecodeError): self.send(400,{'error':'Некорректные данные'})
        except Exception: self.send(500,{'error':'Сервис временно недоступен'})

if __name__=='__main__':
    initialize();ThreadingHTTPServer(('127.0.0.1',int(os.environ.get('PORT','8794'))),Request).serve_forever()
