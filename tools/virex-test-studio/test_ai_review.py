import unittest
import tempfile
from pathlib import Path
from ai_review import gpt, read_evidence, prompt, safe_display, LIMIT

class BridgeTests(unittest.TestCase):
    def test_gpt_payload(self):
        def send(url, headers, payload):
            self.assertEqual(url,'https://api.openai.com/v1/responses')
            self.assertEqual(headers['Authorization'],'Bearer fake')
            self.assertFalse(payload['store'])
            self.assertIn('original evidence',payload['input'])
            return {'status':'completed','output':[{'type':'message','content':[{'type':'output_text','text':'verdict'}]}]}
        self.assertEqual(gpt('model','fake','original evidence',send)[0],'verdict')
    def test_reject_truncation(self):
        with self.assertRaises(ValueError):
            gpt('m','k','e',lambda *args: {'status':'incomplete'})
    def test_reject_empty_response(self):
        with self.assertRaises(ValueError):
            gpt('m','k','e',lambda *args: {'status':'completed','output':[]})
    def test_evidence(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'e.txt'; p.write_text('árvíztűrő',encoding='utf-8-sig')
            self.assertEqual(read_evidence(p),'árvíztűrő')
            p.write_text(' '*20,encoding='utf-8')
            with self.assertRaises(ValueError): read_evidence(p)
            p.write_text('x'*(LIMIT+1),encoding='utf-8')
            with self.assertRaises(ValueError): read_evidence(p)
    def test_untrusted_text_and_terminal(self):
        self.assertIn('evidence',prompt('e'))
        self.assertNotIn('\x1b',safe_display('\x1b[2J'))

if __name__ == '__main__': unittest.main()
