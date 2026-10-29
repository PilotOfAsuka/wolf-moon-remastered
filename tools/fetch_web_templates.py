"""Small official Web-only download for local/Actions builds."""
import pathlib,shutil,sys,zipfile
from fetch_macos_template import RangeFile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 base=(pathlib.Path.home()/'Library/Application Support/Godot/export_templates' if sys.platform=='darwin' else pathlib.Path.home()/'.local/share/godot/export_templates')/'4.7.2.stable'
 base.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(RangeFile())as z:
  for name in ['web_nothreads_debug.zip','web_nothreads_release.zip']:
   out=base/name
   if out.exists():continue
   with z.open('templates/'+name)as src,out.open('wb')as dst:shutil.copyfileobj(src,dst,8*1024*1024)
   with zipfile.ZipFile(out)as check:assert check.testzip()is None
   print('Installed official',name,flush=True)
if __name__=='__main__':main()
