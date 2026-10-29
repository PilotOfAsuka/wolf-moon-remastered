"""Fetch ONLY the macOS member of the official 1.28 GB template ZIP via ranges."""
import io,json,pathlib,shutil,urllib.request,zipfile,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
URL='https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
class RangeFile(io.RawIOBase):
 def __init__(self):
  self.pos=0
  with urllib.request.urlopen(urllib.request.Request(URL,method='HEAD'),timeout=30)as r:self.length=int(r.headers['Content-Length'])
 def seekable(self):return True
 def readable(self):return True
 def tell(self):return self.pos
 def seek(self,o,w=0):
  self.pos=o if w==0 else self.pos+o if w==1 else self.length+o
  return self.pos
 def read(self,n=-1):
  if n<0:n=self.length-self.pos
  n=min(n,self.length-self.pos)
  if n==0:return b''
  if n>160*1024*1024:raise ValueError('Refusing unexpectedly large range')
  req=urllib.request.Request(URL,headers={'Range':f'bytes={self.pos}-{self.pos+n-1}'})
  with urllib.request.urlopen(req,timeout=60)as response:
   if response.status!=206:raise ValueError('Server did not honor range')
   data=response.read(n)
  self.pos+=len(data);return data
def main():
 out=ROOT/'tools/vendor/macos-4.7.2.zip';out.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(RangeFile()) as archive:
  info=archive.getinfo('templates/macos.zip');print('macOS template',info.file_size,'bytes',flush=True)
  with archive.open(info)as src,out.open('wb')as dst:shutil.copyfileobj(src,dst,8*1024*1024)
 with zipfile.ZipFile(out)as check:assert check.testzip()is None
 (ROOT/'research/reports/macos_template.json').write_text(json.dumps(dict(url=URL,member='templates/macos.zip',size=out.stat().st_size,sha256=hashlib.sha256(out.read_bytes()).hexdigest()),indent=2))
 print('Verified macOS template',out,flush=True)
if __name__=='__main__':main()
