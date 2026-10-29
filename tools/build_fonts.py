"""Rasterize local UI font, not original artwork. MIDP fonts were device-dependent."""
import json,pathlib,math
from PIL import Image,ImageFont,ImageDraw
root=pathlib.Path(__file__).resolve().parents[1]
text=(root/'game/data/texts.json').read_text()
chars=sorted(set(chr(n) for n in range(32,127))|set(text)|set(chr(n) for n in range(0x400,0x500)))
out=root/'game/assets/fonts';out.mkdir(parents=True,exist_ok=True)
for bold in [False,True]:
 font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial'+(' Bold' if bold else '')+'.ttf',14)
 ascent,descent=font.getmetrics();height=ascent+descent
 atlas=Image.new('RGBA',(512,math.ceil(len(chars)/16)*24));d=ImageDraw.Draw(atlas);glyphs={}
 for n,ch in enumerate(chars):
  x,y=n%16*32,n//16*24
  d.text((x,y),ch,font=font,fill='white')
  glyphs[str(ord(ch))]=dict(rect=[x,y,32,24],advance=round(font.getlength(ch)))
 name='bold' if bold else 'regular'
 atlas.save(out/(name+'.png'))
 (out/(name+'.json')).write_text(json.dumps(dict(height=height,ascent=ascent,glyphs=glyphs)))
