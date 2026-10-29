#!/usr/bin/env python3
"""Reproducible test entry point; checks never modify the source JAR."""
import argparse,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(args,log=None):
 print('Checking',args[-1],flush=True)
 if log:
  with (ROOT/'build'/log).open('w') as out: p=subprocess.run(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
 else:p=subprocess.run(args,cwd=ROOT)
 if p.returncode:raise SystemExit(p.returncode)
 if log:
  text=(ROOT/'build'/log).read_text()
  if 'SCRIPT ERROR' in text or 'ERROR:' in text: print(text);raise SystemExit(1)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot');ap.add_argument('--smoke',action='store_true');a=ap.parse_args()
 (ROOT/'build').mkdir(exist_ok=True)
 run([sys.executable,'-m','unittest','discover','-s','tests','-v'])
 run([sys.executable,'tools/build_oracle.py'])
 run(['java','-Djava.awt.headless=true','-cp','build/oracle-classes:research/extracted','Oracle','research/reports/jvm_oracle.json'],'oracle.log')
 run([a.godot,'--headless','--path','game','--editor','--import'],'check_import.log')
 run([a.godot,'--headless','--path','game','--script','res://tests/oracle_parity.gd'],'parity.log')
 if a.smoke:run([a.godot,'--headless','--path','game','--script','res://tests/smoke.gd'],'smoke.log')
 print('All requested checks passed.')
if __name__=='__main__':main()
