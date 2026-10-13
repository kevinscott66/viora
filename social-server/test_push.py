import os,tempfile,unittest
from contextlib import closing
from unittest.mock import patch
import server,push
class Provider:
    def __init__(self,status=200,reason=''): self.status=status;self.reason=reason;self.jobs=[]
    def send(self,j): self.jobs.append(j); return self.status,self.reason
class PushTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.old=server.DB;server.DB=self.tmp.name+'/db';server.initialize()
        with closing(server.connect()) as d,d:
            d.executemany('INSERT INTO users VALUES (?,?,?)',[('a','a','A'),('b','b','B')])
            d.executemany('INSERT INTO sessions VALUES (?,?,?,?,?)',[('sa','a','ta','A',0),('sb','b','tb','B',0)])
            d.execute("INSERT INTO rooms VALUES ('room','a','b',NULL,0)")
            d.executemany('INSERT INTO push_devices VALUES (?,?,?)',[('sa','a'*64,'topic'),('sb','b'*64,'topic')])
    def tearDown(self): server.DB=self.old;self.tmp.cleanup()
    def queue(self,message=1):
        with closing(server.connect()) as d,d: push.enqueue(d,'room','a',message,100)
    def count(self):
        with closing(server.connect()) as d:return d.execute('SELECT count(*) FROM push_jobs').fetchone()[0]
    def test_coalesce_recipient_and_success(self):
        self.queue();self.queue(2);self.assertEqual(self.count(),1)
        p=Provider();self.assertTrue(push.deliver_one(server.connect,p,100));self.assertEqual(self.count(),0)
        self.assertEqual(p.jobs[0]['session'],'sb');self.assertEqual(p.jobs[0]['message'],2)
        self.assertNotIn('text',p.jobs[0])
    def test_retry_and_invalid_token(self):
        self.queue();push.deliver_one(server.connect,Provider(503),100);self.assertEqual(self.count(),1)
        self.assertFalse(push.deliver_one(server.connect,Provider(),101))
        push.deliver_one(server.connect,Provider(410,'Unregistered'),131);self.assertEqual(self.count(),0)
        with closing(server.connect()) as d:self.assertIsNone(d.execute("SELECT 1 FROM push_devices WHERE session='sb'").fetchone())
    def test_revocation_cascades_and_new_message_survives_ack(self):
        self.queue()
        outer=self
        class Concurrent(Provider):
            def send(self,j): outer.queue(2);return 200,''
        push.deliver_one(server.connect,Concurrent(),100);self.assertEqual(self.count(),1)
        with closing(server.connect()) as d,d:d.execute("DELETE FROM sessions WHERE id='sb'")
        self.assertEqual(self.count(),0)
    def test_disabled_without_configuration(self):
        with patch.dict(os.environ,{},clear=True):self.assertFalse(push.configured())
