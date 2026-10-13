import json, tempfile, threading, unittest, urllib.request, urllib.error
import server
class SocialTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=tempfile.TemporaryDirectory();server.DB=cls.tmp.name+'/test.db';server.initialize()
        cls.http=server.ThreadingHTTPServer(('127.0.0.1',0),server.Request)
        cls.url='http://127.0.0.1:'+str(cls.http.server_port)
        threading.Thread(target=cls.http.serve_forever,daemon=True).start()
    @classmethod
    def tearDownClass(cls): cls.http.shutdown();cls.http.server_close();cls.tmp.cleanup()
    def setUp(self):
        from contextlib import closing
        with closing(server.connect()) as db:
            db.execute('DELETE FROM limits');db.commit()
    def call(self,path,body=None,token=None):
        headers={'Content-Type':'application/json'}
        if token: headers['Authorization']='Bearer '+token
        request=urllib.request.Request(self.url+path,data=json.dumps(body).encode() if body is not None else None,headers=headers)
        try:
            with urllib.request.urlopen(request) as r:return r.status,json.load(r)
        except urllib.error.HTTPError as e:return e.code,json.load(e)
    def test_private_chat_and_short_links(self):
        a=self.call('/api/register',{})[1]['token'];b=self.call('/api/register',{})[1]['token'];c=self.call('/api/register',{})[1]['token']
        room=self.call('/api/chats',{},a)[1];path='/api/chats/'+room['id']+'/messages';invite=room['invite'].rsplit('/',1)[1]
        self.assertEqual(self.call(path,token=b)[0],404)
        self.assertEqual(self.call('/api/join',{'invite':invite},b)[0],200)
        self.assertEqual(self.call('/api/join',{'invite':invite},c)[0],404)
        payload={'v':1,'title':'Песня','artists':['Артист'],'seconds':45,'lyric':'строка','note':'заметка'}
        body={'nonce':'abcdefghijklmnop','text':'Привет','moment':payload}
        self.assertEqual(self.call(path,body,c)[0],404)
        self.assertEqual(self.call(path,body,a)[0],200)
        self.call(path,body,a)
        rows=self.call(path,token=b)[1]['messages'];self.assertEqual(len(rows),1);self.assertFalse(rows[0]['mine']);self.assertEqual(rows[0]['moment'],payload)
        self.assertEqual(self.call(path)[0],401)
        url=self.call('/api/moments',payload,a)[1]['url'];self.assertLess(len(url),55)
        self.assertEqual(self.call('/api/moments/'+url.rsplit('/',1)[1])[1],payload)
        self.assertEqual(self.call('/api/moments',{**payload,'seconds':-1},a)[0],400)
        self.assertEqual(self.call('/api/moments',{**payload,'replyTo':{**payload,'replyTo':payload}},a)[0],400)
        self.assertEqual(self.call(path,{'nonce':'abcdefghijklmnop2','text':'x'*2001},a)[0],400)
    def test_expired_invite(self):
        a=self.call('/api/register',{})[1]['token'];b=self.call('/api/register',{})[1]['token']
        r=self.call('/api/chats',{},a)[1]
        with server.connect() as db:db.execute('UPDATE rooms SET expires=0 WHERE id=?',(r['id'],))
        self.assertEqual(self.call('/api/join',{'invite':r['invite'].rsplit('/',1)[1]},b)[0],404)
    def test_card_publish_update_and_owner_only_revoke(self):
        a=self.call('/api/register',{})[1]['token'];b=self.call('/api/register',{})[1]['token']
        payload={'v':1,'name':'Моё имя','lyric':'Строка','theme':'ocean','tracks':[
            {'v':1,'title':'Песня '+str(i),'artists':['Исполнитель'],'seconds':0,'note':'PRIVATE','lyric':'PRIVATE','replyTo':{'v':1,'title':'Private parent','artists':['x'],'seconds':0,'note':''}} for i in range(3)]}
        self.assertEqual(self.call('/api/card',payload)[0],401)
        self.assertIsNone(self.call('/api/card',token=a)[1]['url'])
        result=self.call('/api/card',payload,a)[1];url=result['url'];code=url.rsplit('/',1)[1]
        public=self.call('/api/cards/'+code)[1]
        self.assertEqual(len(public['tracks']),3)
        self.assertTrue(all(t['note']=='' and 'replyTo' not in t for t in public['tracks']))
        self.assertNotIn('owner',public)
        self.assertEqual(self.call('/api/card',{**payload,'name':'Новое имя'},a)[1]['url'],url)
        self.assertEqual(self.call('/api/cards/'+code)[1]['name'],'Новое имя')
        self.call('/api/card/unpublish',{},b)
        self.assertEqual(self.call('/api/cards/'+code)[0],200)
        self.assertEqual(self.call('/api/card',{**payload,'tracks':[payload['tracks'][0]]*3},a)[0],400)
        self.assertEqual(self.call('/api/card',{**payload,'theme':'bad'},a)[0],400)
        self.call('/api/card/unpublish',{},a)
        self.assertEqual(self.call('/api/cards/'+code)[0],404)
        self.assertNotEqual(self.call('/api/card',payload,a)[1]['url'],url)
    def test_profile_recovery_sessions_and_restart(self):
        a=self.call('/api/register',{})[1]['token']
        self.assertEqual(self.call('/api/profile',{'name':'Имя','bio':'Example title 107','color':'ocean'},a)[0],200)
        code=self.call('/api/recovery',{},a)[1]['code']
        self.assertEqual(self.call('/api/recover',{'code':'x'*43})[0],403)
        b=self.call('/api/recover',{'code':code,'label':'Second'})[1]['token']
        profile=self.call('/api/profile',token=b)[1]
        self.assertEqual(profile['name'],'Имя');self.assertEqual(profile['bio'],'Example title 107')
        room=self.call('/api/chats',{},a)[1]
        self.assertEqual(self.call('/api/chats',token=b)[1]['chats'][0]['id'],room['id'])
        sessions=self.call('/api/sessions',token=b)[1]['sessions']
        other=next(x['id'] for x in sessions if not x['current'])
        current=next(x['id'] for x in sessions if x['current'])
        self.assertEqual(self.call('/api/sessions/revoke',{'id':current},b)[0],400)
        self.call('/api/sessions/revoke',{'id':other},b)
        self.assertEqual(self.call('/api/profile',token=a)[0],401)
        server.initialize()
        self.assertEqual(self.call('/api/profile',token=a)[0],401)
        self.call('/api/recovery',{},b)
        self.assertEqual(self.call('/api/recover',{'code':code})[0],403)
        self.assertEqual(self.call('/api/profile',{'name':'X','bio':3},b)[0],400)

    def test_automatic_encryption_and_recovery(self):
        import base64
        enc=lambda n:base64.b64encode(bytes([n])*32).decode()
        a=self.call('/api/register',{})[1]['token'];b=self.call('/api/register',{})[1]['token'];c=self.call('/api/register',{})[1]['token']
        old=self.call('/api/recovery',{},a)[1]['code']
        room=self.call('/api/chats',{},a)[1];rid=room['id'];path='/api/chats/'+rid
        self.call('/api/join',{'invite':room['invite'].rsplit('/',1)[1]},b)
        self.call(path+'/messages',{'nonce':'legacy0123456789','text':'legacy'},a)
        self.assertEqual(self.call('/api/identity',{'publicKey':enc(1)},a)[0],200)
        self.assertEqual(self.call('/api/identity',{'publicKey':enc(2)},a)[0],409)
        self.assertFalse(self.call('/api/profile',token=a)[1]['hasKeyRecovery'])
        self.assertEqual(self.call(path+'/security',{'keyId':'bad'},a)[0],409)
        self.call('/api/identity',{'publicKey':enc(3)},b)
        kid=self.call(path+'/security',token=a)[1]['keyId']
        self.assertEqual(self.call(path+'/security',token=c)[0],404)
        self.assertEqual(self.call(path+'/security',{'keyId':kid},a)[0],200)
        self.assertEqual(self.call(path+'/messages',{'nonce':'plain01234567890','text':'Example title 404'},a)[0],409)
        box={'v':1,'iv':base64.b64encode(bytes(12)).decode(),'tag':base64.b64encode(bytes(16)).decode(),'cipher':enc(5)}
        msg={'nonce':'sealed0123456789','encrypted':{**box,'key':kid}}
        self.assertEqual(self.call(path+'/messages',msg,a)[0],200)
        self.assertEqual(self.call(path+'/messages',msg,a)[0],200)
        rows=self.call(path+'/messages',token=b)[1]['messages']
        self.assertEqual(len(rows),2);self.assertEqual(rows[0]['text'],'legacy');self.assertEqual(rows[1]['text'],'');self.assertIsNone(rows[1]['moment']);self.assertEqual(rows[1]['encrypted'],msg['encrypted'])
        self.assertEqual(self.call('/api/recovery-v2',{'proof':enc(7),'backup':box},a)[0],200)
        self.assertTrue(self.call('/api/profile',token=a)[1]['hasKeyRecovery'])
        self.assertEqual(self.call('/api/recovery',{},a)[0],409)
        self.assertEqual(self.call('/api/recover',{'code':old})[0],403)
        restored=self.call('/api/recover-v2',{'proof':enc(7)})[1]
        self.assertEqual(restored['backup'],box);self.assertEqual(restored['publicKey'],enc(1))
        self.assertEqual(self.call(path+'/messages',token=restored['token'])[1]['messages'],self.call(path+'/messages',token=a)[1]['messages'])
        self.call('/api/recovery-v2',{'proof':enc(8),'backup':box},a)
        self.assertEqual(self.call('/api/recover-v2',{'proof':enc(7)})[0],403)


    def test_rate_limit_ignores_untrusted_proxy_header(self):
        for i in range(181):
            request=urllib.request.Request(self.url+'/api/moments/abcdefghijklmnop', headers={'X-Real-IP':str(i)})
            try:
                with urllib.request.urlopen(request) as response: status=response.status
            except urllib.error.HTTPError as error:
                status=error.code
            self.assertEqual(status, 429 if i==180 else 404)

if __name__=='__main__':unittest.main()
