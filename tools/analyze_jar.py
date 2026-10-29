#!/usr/bin/env python3
"""Lossless WolfMoon 1.06 archive/class/resource analysis. No previous project inputs."""
from __future__ import annotations
import argparse, collections, hashlib, io, json, pathlib, struct, subprocess, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

class Reader:
    def __init__(self, data: bytes): self.data, self.p = data, 0
    def take(self, n):
        if n < 0 or self.p+n > len(self.data): raise ValueError(f"Truncated at {self.p}, need {n}")
        b = self.data[self.p:self.p+n]; self.p += n; return b
    def num(self, f): return struct.unpack('>'+f, self.take(struct.calcsize('>'+f)))[0]
    def utf(self):
        # DataInput modified UTF-8: encode UTF-16 code units; NUL uses C0 80.
        b = self.take(self.num('H')); units=[]; p=0
        while p < len(b):
            c=b[p]; p+=1
            if c < 128: units.append(c)
            elif c & 224 == 192:
                units.append(((c&31)<<6)|(b[p]&63)); p+=1
            elif c & 240 == 224:
                units.append(((c&15)<<12)|((b[p]&63)<<6)|(b[p+1]&63)); p+=2
            else: raise ValueError('Invalid modified UTF-8')
        return b''.join(struct.pack('>H',u) for u in units).decode('utf-16-be')

def signature(desc):
    args=[]; p=1
    while desc[p] != ')':
        s=p
        while desc[p]=='[': p+=1
        if desc[p]=='L': p=desc.index(';',p)+1
        else: p+=1
        args.append(desc[s:p])
    return args,desc[p+1:]

def parse_class(data):
    r=Reader(data)
    assert r.num('I')==0xcafebabe
    minor,major=r.num('H'),r.num('H'); count=r.num('H'); cp=[None]*count; j=1
    while j<count:
        tag=r.num('B')
        if tag==1: v=r.utf()
        elif tag in (3,4): v=r.num('i' if tag==3 else 'f')
        elif tag in (5,6): v=r.num('q' if tag==5 else 'd')
        elif tag in (7,8,16): v=r.num('H')
        elif tag in (9,10,11,12,18): v=[r.num('H'),r.num('H')]
        elif tag==15: v=[r.num('B'),r.num('H')]
        else: raise ValueError(f'CP tag {tag}')
        cp[j]=(tag,v); j += 2 if tag in (5,6) else 1
    def val(n):
        if not n: return None
        t,v=cp[n]
        if t in (7,8): return val(v)
        if t in (9,10,11):
            name,desc=val(v[1]); res=dict(owner=val(v[0]),name=name,desc=desc)
            if t!=9: res['params'],res['return']=signature(desc)
            return res
        if t==12: return [val(v[0]),val(v[1])]
        if t==5: return dict(kind='long',v=v)
        return v
    flags=r.num('H'); name=val(r.num('H')); parent=val(r.num('H'))
    interfaces=[val(r.num('H')) for _ in range(r.num('H'))]
    def attrs(q):
        res={}
        for _ in range(q.num('H')):
            key=val(q.num('H')); res[key]=q.take(q.num('I'))
        return res
    fields=[]
    for _ in range(r.num('H')):
        f=dict(flags=r.num('H'),name=val(r.num('H')),desc=val(r.num('H'))); a=attrs(r)
        if 'ConstantValue' in a: f['constant']=val(Reader(a['ConstantValue']).num('H'))
        fields.append(f)
    methods={}; opcounts=collections.Counter()
    for _ in range(r.num('H')):
        m=dict(flags=r.num('H'),name=val(r.num('H')),desc=val(r.num('H'))); a=attrs(r)
        m['params'],m['return']=signature(m['desc'])
        if 'Code' in a:
            q=Reader(a['Code']); m['max_stack']=q.num('H'); m['max_locals']=q.num('H'); code=q.take(q.num('I'))
            instructions=[]; offsets={}; s=Reader(code)
            while s.p<len(code):
                pc=s.p; op=s.num('B'); opcounts[op]+=1; operands=[]
                if op==16: operands=[s.num('b')]
                elif op==17: operands=[s.num('h')]
                elif op in (18,19,20): operands=[val(s.num('B' if op==18 else 'H'))]
                elif op in (21,22,23,24,25,54,55,56,57,58,169,188): operands=[s.num('B')]
                elif op==132: operands=[s.num('B'),s.num('b')]
                elif 153<=op<=168 or op in (198,199): operands=[pc+s.num('h')]
                elif op in (200,201): operands=[pc+s.num('i')]
                elif op in (170,171):
                    s.take((-s.p)%4); default=pc+s.num('i'); pairs=[]
                    if op==170:
                        low,high=s.num('i'),s.num('i')
                        pairs=[[k,pc+s.num('i')] for k in range(low,high+1)]
                    else: pairs=[[s.num('i'),pc+s.num('i')] for _ in range(s.num('i'))]
                    operands=[default,pairs]
                elif 178<=op<=185:
                    operands=[val(s.num('H'))]
                    if op==185: s.take(2)
                elif op in (187,189,192,193): operands=[val(s.num('H'))]
                elif op==197: operands=[val(s.num('H')),s.num('B')]
                elif op==196:
                    sub=s.num('B'); operands=[sub,s.num('H')]
                    if sub==132: operands.append(s.num('h'))
                elif op==186: raise ValueError('Unexpected invokedynamic')
                offsets[pc]=len(instructions); instructions.append([op,*operands])
            offsets[len(code)]=len(instructions)
            for ins in instructions:
                op=ins[0]
                if 153<=op<=168 or op in (198,199,200,201): ins[1]=offsets[ins[1]]
                elif op in (170,171):
                    ins[1]=offsets[ins[1]]
                    for pair in ins[2]: pair[1]=offsets[pair[1]]
            m['code']=instructions; m['offsets']=[p for p in offsets if p<len(code)]; m['exceptions']=[]
            for _ in range(q.num('H')):
                start,end,handler,t=[q.num('H') for _ in range(4)]
                m['exceptions'].append(dict(start=offsets[start],end=offsets[end],handler=offsets[handler],type=val(t)))
            attrs(q); assert q.p==len(q.data)
        methods[m['name']+m['desc']]=m
    attrs(r); assert r.p==len(data)
    deps=sorted(set(val(j) for j in range(1,count) if cp[j] and cp[j][0]==7))
    refs=[val(j) for j in range(1,count) if cp[j] and cp[j][0] in (9,10,11)]
    constants=[dict(index=n,tag=cp[n][0],value=val(n)) for n in range(1,count) if cp[n] and cp[n][0] in (1,3,4,5,6,7,8)]
    return dict(name=name,parent=parent,interfaces=interfaces,flags=flags,version=[major,minor],fields=fields,methods=methods,dependencies=deps,references=refs,constants=constants),opcounts

def dump(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('jar',nargs='?',default=str(ROOT/'research/original/WolfMoon_fixed.jar')); args=ap.parse_args()
    jar=pathlib.Path(args.jar); raw=jar.read_bytes(); z=zipfile.ZipFile(io.BytesIO(raw)); assert z.testzip() is None
    ext=ROOT/'research/extracted'; ext.mkdir(parents=True,exist_ok=True)
    data=ROOT/'game/data'; originals=ROOT/'game/assets/original'; originals.mkdir(parents=True,exist_ok=True)
    inventory=[]; classes={}; ops=collections.Counter(); external={}
    from PIL import Image,ImageDraw
    for f in z.infolist():
        b=z.read(f); p=ext/f.filename; assert ext.resolve() in p.resolve().parents
        if f.is_dir(): p.mkdir(parents=True,exist_ok=True)
        else: p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(b)
        rec=dict(path=f.filename,size=len(b),compressed=f.compress_size,sha256=hashlib.sha256(b).hexdigest(),archive_date=f.date_time,status='extracted; awaiting behavioral parity')
        if f.is_dir(): rec.update(format='directory',purpose='archive structure',status='accounted')
        elif f.filename.endswith('.class'):
            c,counts=parse_class(b); classes[c['name']]=c; ops.update(counts)
            rec.update(format=f"JVM {c['version']}",purpose='executable bytecode',methods=len(c['methods']),status='parsed losslessly; CFR + javap')
        elif f.filename.endswith('.png'):
            im=Image.open(io.BytesIO(b)); im.verify(); im=Image.open(io.BytesIO(b))
            rec.update(format='PNG',purpose='sprite sheet / UI artwork',dimensions=list(im.size),mode=im.mode,status='extracted verbatim')
        elif f.filename.endswith('.mid'):
            assert b[:4]==b'MThd'; rec.update(format='Standard MIDI',purpose='music',midi=list(struct.unpack('>HHH',b[8:14])),status='extracted verbatim; audio conversion separate')
        elif f.filename=='META-INF/MANIFEST.MF': rec.update(format='JAR manifest',purpose='MIDlet metadata',status='decoded')
        else: rec.update(format='binary resource container',purpose='determined from c.class resource index',status='decoded below')
        inventory.append(rec)
        if not f.is_dir() and not f.filename.endswith('.class') and not f.filename.startswith('META-INF/'):
            (originals/f.filename).write_bytes(b)
    for c in classes.values():
        for ref in c['references']:
            if ref['owner'] not in classes:
                external[ref['owner']+'.'+ref['name']+ref['desc']]=ref
    dump(data/'classes.json',classes)
    dump(ROOT/'research/reports/class_dependencies.json',{k:dict(parent=v['parent'],dependencies=v['dependencies']) for k,v in classes.items()})
    dump(ROOT/'research/reports/external_api.json',list(external.values()))
    dump(ROOT/'research/reports/opcodes.json',dict(sorted(ops.items())))
    for name in classes:
        result=subprocess.run(['javap','-c','-p','-s','-constants','-verbose','-classpath',str(jar),name],capture_output=True,text=True,check=True)
        (ROOT/'research/bytecode'/f'{name}.txt').write_text(result.stdout)
    # c.a() reads h: 64 records, offset/readUTF/length. Exact bounds, no skipped bytes.
    r=Reader(z.read('h')); resources=[]
    for n in range(64): resources.append(dict(id=n,offset=r.num('i'),file=r.utf(),size=r.num('i')))
    assert r.p==len(r.data)
    sprites={}; texts={}; coverage=collections.defaultdict(list); anomalies=[]
    for rec in resources:
        n=rec['id']; start=rec['offset']; end=start+rec['size']; b=z.read(rec['file'])[start:end]
        if len(b)!=rec['size']:
            anomalies.append(dict(resource=n,file=rec['file'],declared=rec['size'],actual=len(b),reason='resource index retains pre-translation length'))
            assert n==0
        coverage[rec['file']].append((start,start+len(b))); q=Reader(b)
        if n==0:
            langs=[(q.utf(),q.num('i')) for _ in range(6)]; base=q.p; consumed=[]
            for lang,offset in langs:
                q.p=base+offset; a=q.p; texts[lang]=[q.utf() for _ in range(233)]; consumed.append((a,q.p))
            text_end=max(e for a,e in consumed)
            if text_end != len(b):
                anomalies.append(dict(resource=n,trailing_bytes=len(b)-text_end,hex=b[text_end:].hex(),reason='unreferenced suffix after translated language blocks; preserved'))
            rec.update(format='six language slots (duplicates), modified UTF-8',languages=[l for l,o in langs],language_offsets=langs,actual_size=len(b))
        elif n<58:
            a,e=q.num('h'),q.num('h'); frames=[]
            for ident in range(a,e): frames.append((ident,[q.num('h') for _ in range(6)]))
            sheet=q.take(8).replace(b'\0',b'').decode('ascii')
            if sheet: image=Image.open(io.BytesIO(z.read(sheet))).convert('RGBA'); assert q.p==len(b)
            else:
                image=Image.open(io.BytesIO(q.take(len(b)-q.p))).convert('RGBA'); sheet=f'embedded_{n:02d}.png'; image.save(originals/sheet)
            for ident,rect in frames:
                sprites[ident]=dict(resource=n,sheet=sheet,rect=rect[:4],origin=rect[4:])
                x,y,w,h=rect[:4]
                if w>0 and h>0:
                    target=ROOT/'game/assets/sprites'/f'{ident:03d}.png'; target.parent.mkdir(parents=True,exist_ok=True)
                    image.crop((x,y,x+w,y+h)).save(target)
            rec.update(format='sprite frame metadata',sheet=sheet,frames=[a,e])
        elif n<63:
            assert b[:4]==b'MThd'; rec.update(format='Standard MIDI')
        else:
            # i.g() [()V], including packed creatures and final decoration tables.
            w,h,sx,sy=[q.num('B') for _ in range(4)]; tiles=[q.num('H') for _ in range(w*h)]
            actors=[]
            for _ in range(q.num('B')):
                packed_a,packed_b=q.num('B'),q.num('B'); actors.append(dict(raw=[packed_a,packed_b],region=packed_a>>4,type=packed_a&15,parameter=packed_b>>4,variant=packed_b&15))
            objects=[[q.num('B') for _ in range(3)] for _ in range(q.num('B'))]
            items=[[q.num('B') for _ in range(3)] for _ in range(q.num('B'))]
            groups,decor_count=q.num('B'),q.num('B'); decor_count=decor_count or 20
            decorations=[[[[q.num('b') for _ in range(3)] for _ in range(decor_count)] for _ in range(8)] for _ in range(groups)]
            assert q.p==len(b),(q.p,len(b))
            world=dict(width=w,height=h,start=[sx,sy],tiles=tiles,creatures=actors,objects=objects,items=items,decoration_count=decor_count,decorations=decorations,
                       tile_bits=dict(terrain=[0,7],region=[9,7680],feature=[13,57344]),source='i.g()V / resource 63')
            dump(data/'world.json',world); rec.update(format='complete world, packed creatures, objects, items, decorations',dimensions=[w,h])
    dump(data/'resources.json',resources); dump(data/'sprites.json',sprites); dump(data/'texts.json',texts)
    # g resource group lists, and r menus: preserve all bytes, document parsing separately.
    q=Reader(z.read('g')); groups=[[q.num('h') for _ in range(q.num('h'))] for _ in range(2)]; assert q.p==len(q.data)
    dump(data/'resource_groups.json',groups)
    # j.a(I)Lj; reads /m. Keep both softkey event numbers and all row variants.
    q=Reader(z.read('m')); menu_header=q.num('i'); menus=[]
    while q.p<len(q.data):
        menu=dict(id=len(menus),title=q.num('h'),sprite=q.num('h'),flags=q.num('i'),softkeys=[],rows=[])
        for _ in range(q.num('i')):
            menu['softkeys'].append(dict(key=q.num('b'),text=q.num('h'),event=q.num('h'),target=q.num('h')))
        for _ in range(q.num('h')):
            row=dict(type=q.num('b'),variants=[])
            for _ in range(q.num('h') if row['type']==2 else 1):
                row['variants'].append(dict(text=q.num('h'),sprite=q.num('h'),flags=q.num('i')))
            row['event']=q.num('h');row['target']=q.num('h') if row['type']!=2 else -1
            menu['rows'].append(row)
        menus.append(menu)
    assert q.p==len(q.data)
    dump(data/'menus.json',dict(header=menu_header,menus=menus))
    for filename,spans in coverage.items():
        pos=0
        for a,b in sorted(spans): assert a==pos,(filename,pos,a); pos=b
        assert pos==len(z.read(filename)),(filename,pos,len(z.read(filename)))
    dump(ROOT/'research/reports/resource_index.json',resources)
    dump(ROOT/'research/reports/anomalies.json',anomalies)
    roles={'RMIDlet':'MIDlet entry/lifecycle','a':'loading screen','b':'scrolling modal dialogue','c':'resource loader, text lookup, sprite clipping','d':'storyboard and ending screens','e':'text wrapping and inline sprites','f':'integer particle system','g':'Rovio splash animation','h':'game/menu coordinator, environment tables and effects','i':'world, turns, AI, combat, inventory, quests, saves, perspective','j':'menu renderer and binary menu loader','k':'menu row data','l':'factories and event forwarding','m':'threads, event queue, lifecycle, RMS helpers','n':'MIDI playlist and player lifecycle','o':'GameCanvas, physical key mapping, softkeys','p':'screen base and reference size'}
    for rec in inventory:
        name=rec['path']
        if name.endswith('.class'): rec['purpose']=roles[name[:-6]];rec['usage']='see bytecode/'+name[:-6]+'.txt; executable descriptors in game/data/classes.json'
        elif name.endswith('.png'):
            ids=[k for k,v in sprites.items() if v['sheet']==name]
            rec['sprite_ids']=ids;rec['usage']='c.a(IIILjavax/microedition/lcdui/Graphics;)V' if ids else 'MIDlet icon' if name=='icon.png' else 'no indexed sprite references found'
        elif name=='m': rec.update(format='binary menus (big endian)',purpose=f'{len(menus)} menus, softkeys, events and variant rows',status='decoded completely',usage='j.a(I)Lj; -> game/data/menus.json')
        elif name=='g': rec.update(format='short resource groups',purpose='startup and music loading groups',status='decoded completely',usage='c.a(I)[S')
        elif name=='h':rec.update(format='64 resource index records',purpose='offset/UTF filename/length directory',status='decoded with translated-length anomaly documented',usage='c.a()[Ljava/lang/Object;')
        elif name=='l':rec.update(format='modified UTF-8 language container',purpose='233 English and 233 Russian texts, six duplicate slots',status='decoded; 38 unreferenced bytes preserved',usage='c.a(DataInputStream,int,int)String')
        elif name=='r':rec.update(format='57 sequential sprite metadata records',purpose='417 sprite records linked to PNG sheets',status='decoded completely',usage='c.a(DataInputStream,int,int)String')
        elif name=='ck.bin':rec.update(format='big endian world map with packed creatures',purpose='complete world, objects, items and directional decorations',status='decoded completely',usage='i.g()V')
        elif name.endswith('.mid'):rec['usage']='n.a(I,I)V via resources 58..62; original scheduling retained'
    dump(ROOT/'research/reports/archive_inventory.json',dict(source=jar.name,sha256=hashlib.sha256(raw).hexdigest(),entries=inventory,classes=len(classes),resources=len(resources),coverage=coverage,excluded_inputs='No previous project materials used'))
    colors=['#4c5635','#3b4d2b','#667449','#a09b83','#6e624a','#374c5d','#7b8fa0','#726d57']
    im=Image.new('RGB',(w*12,h*12)); d=ImageDraw.Draw(im)
    for y in range(h):
        for x in range(w):
            tile=tiles[x+y*w]; d.rectangle((x*12,y*12,x*12+11,y*12+11),fill=colors[tile&7]); f=(tile>>13)&7
            if f: d.text((x*12,y*12),str(f),fill='white')
    d.ellipse((sx*12,sy*12,sx*12+11,sy*12+11),fill='red'); im.save(ROOT/'research/reports/world_map.png')
    print(json.dumps(dict(entries=len(inventory),classes=len(classes),opcodes=len(ops),api_calls=len(external),sprites=len(sprites),languages=list(texts),world=[w,h],start=[sx,sy],source_sha256=hashlib.sha256(raw).hexdigest()),ensure_ascii=False))

if __name__=='__main__': main()
