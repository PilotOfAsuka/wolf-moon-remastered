"""Independent, complete resource checks against the supplied JAR."""
import hashlib,io,json,pathlib,struct,sys,unittest,zipfile
from PIL import Image
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from analyze_jar import Reader,parse_class

class ArchiveTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.jar=zipfile.ZipFile(ROOT/'research/original/WolfMoon_fixed.jar')
  cls.inventory=json.loads((ROOT/'research/reports/archive_inventory.json').read_text())
  cls.world=json.loads((ROOT/'game/data/world.json').read_text())

 def test_every_archive_entry_is_accounted_and_unchanged(self):
  self.assertEqual(len(self.jar.infolist()),88)
  self.assertEqual({i.filename for i in self.jar.infolist()},{i['path'] for i in self.inventory['entries']})
  for rec in self.inventory['entries']:
   raw=self.jar.read(rec['path'])
   self.assertEqual(hashlib.sha256(raw).hexdigest(),rec['sha256'],rec['path'])
   if not rec['path'].endswith('/'):
    self.assertEqual(raw,(ROOT/'research/extracted'/rec['path']).read_bytes())
   self.assertTrue(rec['purpose'])
  self.assertEqual(self.inventory['sha256'],'c7f4c69f94fd6c49abcdc7011dec973b0202aaa23441fefa09ff7df04a77babe')

 def test_complete_map_binary_roundtrip_including_all_decorations(self):
  w=self.world;b=bytearray([w['width'],w['height'],*w['start']])
  for t in w['tiles']: b.extend(struct.pack('>H',t))
  b.append(len(w['creatures']))
  for c in w['creatures']:b.extend(c['raw'])
  for name in ['objects','items']:
   b.append(len(w[name]))
   for row in w[name]:b.extend(row)
  b.extend([len(w['decorations']),w['decoration_count']])
  for group in w['decorations']:
   for direction in group:
    for row in direction:b.extend(v&255 for v in row)
  self.assertEqual(bytes(b),self.jar.read('ck.bin'))
  self.assertEqual([w['width'],w['height'],*w['start']],[30,40,27,39])

 def test_all_417_sprite_records_and_crops(self):
  sprites=json.loads((ROOT/'game/data/sprites.json').read_text());self.assertEqual(len(sprites),417)
  sheets={}
  for ident,rec in sprites.items():
   sheet=rec['sheet']
   if sheet not in sheets:sheets[sheet]=Image.open(io.BytesIO(self.jar.read(sheet))).convert('RGBA')
   x,y,w,h=rec['rect']
   if w>0 and h>0:
    crop=Image.open(ROOT/'game/assets/sprites'/f'{int(ident):03d}.png').convert('RGBA')
    self.assertEqual(crop.tobytes(),sheets[sheet].crop((x,y,x+w,y+h)).tobytes(),ident)

 def test_modified_utf_and_translation_anomalies(self):
  texts=json.loads((ROOT/'game/data/texts.json').read_text());self.assertEqual(set(texts),{'English','Русский'})
  self.assertEqual([len(t) for t in texts.values()],[233,233])
  q=Reader(self.jar.read('l'));slots=[(q.utf(),q.num('i')) for _ in range(6)];base=q.p
  self.assertEqual(len(set(slots)),2)
  for lang,offset in slots:
   q.p=base+offset;self.assertEqual([q.utf() for _ in range(233)],texts[lang])
  self.assertEqual(len(q.data)-q.p,38)
  self.assertEqual(Reader(b'\x00\x02\xc0\x80').utf(),'\x00')

 def test_all_classes_and_instruction_boundaries(self):
  classes=json.loads((ROOT/'game/data/classes.json').read_text());self.assertEqual(len(classes),17)
  for name,c in classes.items():
   fresh,_=parse_class(self.jar.read(name+'.class'));self.assertEqual(c,fresh)
   self.assertTrue((ROOT/'research/bytecode'/f'{name}.txt').exists())
   for m in c['methods'].values():
    if 'code' not in m:continue
    self.assertEqual(len(m['code']),len(m['offsets']))
    self.assertEqual(sorted(set(m['offsets'])),m['offsets'])
    for e in m['exceptions']:self.assertLess(e['handler'],len(m['code']))

 def test_all_menu_bytes_decoded(self):
  doc=json.loads((ROOT/'game/data/menus.json').read_text());out=bytearray(struct.pack('>i',doc['header']))
  self.assertEqual(len(doc['menus']),9)
  for menu in doc['menus']:
   out.extend(struct.pack('>hhii',menu['title'],menu['sprite'],menu['flags'],len(menu['softkeys'])))
   for k in menu['softkeys']:out.extend(struct.pack('>bhhh',k['key'],k['text'],k['event'],k['target']))
   out.extend(struct.pack('>h',len(menu['rows'])))
   for row in menu['rows']:
    out.extend(struct.pack('>b',row['type']))
    if row['type']==2:out.extend(struct.pack('>h',len(row['variants'])))
    for v in row['variants']:out.extend(struct.pack('>hhi',v['text'],v['sprite'],v['flags']))
    out.extend(struct.pack('>h',row['event']))
    if row['type']!=2:out.extend(struct.pack('>h',row['target']))
  self.assertEqual(bytes(out),self.jar.read('m'))

if __name__=='__main__':unittest.main()
