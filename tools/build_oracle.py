"""Build an independent real-JVM oracle around the unmodified class files.
Only javax.microedition platform stubs are provided; no game code is recompiled.
"""
import pathlib,subprocess,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
SRC=ROOT/'build/oracle-src';OUT=ROOT/'build/oracle-classes'
SOURCES={
'javax/microedition/midlet/MIDlet.java':'''package javax.microedition.midlet;
public class MIDlet { public void notifyDestroyed(){} public void notifyPaused(){} }
''',
'javax/microedition/midlet/MIDletStateChangeException.java':'''package javax.microedition.midlet;
public class MIDletStateChangeException extends Exception {}
''',
'javax/microedition/lcdui/Displayable.java':'''package javax.microedition.lcdui;
public class Displayable { public int getWidth(){return 240;} public int getHeight(){return 320;} }
''',
'javax/microedition/lcdui/Canvas.java':'''package javax.microedition.lcdui;
public class Canvas extends Displayable { public void setFullScreenMode(boolean v){} public int getGameAction(int k){return 0;} }
''',
'javax/microedition/lcdui/game/GameCanvas.java':'''package javax.microedition.lcdui.game;
public class GameCanvas extends javax.microedition.lcdui.Canvas {
private final javax.microedition.lcdui.Graphics g=new javax.microedition.lcdui.Graphics(240,320);
public GameCanvas(boolean v){} public javax.microedition.lcdui.Graphics getGraphics(){return g;} public void flushGraphics(){} }
''',
'javax/microedition/lcdui/Display.java':'''package javax.microedition.lcdui;
public class Display { public static Display getDisplay(javax.microedition.midlet.MIDlet m){return new Display();} public void setCurrent(Displayable d){} }
''',
'javax/microedition/lcdui/Font.java':'''package javax.microedition.lcdui;
public class Font {
public java.awt.Font font;
private Font(int style){font=new java.awt.Font("Arial",style&1,14);}
public static Font getFont(int f,int s,int z){return new Font(s);}
public int getHeight(){return 16;} public int stringWidth(String s){return s.length()*7;}
}
''',
'javax/microedition/lcdui/Image.java':'''package javax.microedition.lcdui;
import java.io.*; import javax.imageio.ImageIO; import java.awt.image.BufferedImage;
public class Image {
public BufferedImage image;
private Image(BufferedImage im){image=im;}
public static Image createImage(String p)throws IOException{return new Image(ImageIO.read(Image.class.getResourceAsStream(p)));}
public static Image createImage(byte[] b,int o,int n){try{return new Image(ImageIO.read(new ByteArrayInputStream(b,o,n)));}catch(IOException e){throw new RuntimeException(e);}}
public static Image createImage(int w,int h){BufferedImage im=new BufferedImage(w,h,BufferedImage.TYPE_INT_ARGB);java.awt.Graphics2D g=im.createGraphics();g.setColor(java.awt.Color.WHITE);g.fillRect(0,0,w,h);g.dispose();return new Image(im);}
public Graphics getGraphics(){return new Graphics(image);}
}
''',
'javax/microedition/lcdui/Graphics.java':'''package javax.microedition.lcdui;
import java.awt.image.BufferedImage;
public class Graphics {
public BufferedImage image; public java.awt.Graphics2D g; private Font font=Font.getFont(0,0,0);
public Graphics(int w,int h){this(new BufferedImage(w,h,BufferedImage.TYPE_INT_ARGB));}
public Graphics(BufferedImage im){image=im;g=im.createGraphics();g.setClip(0,0,im.getWidth(),im.getHeight());}
public void setColor(int c){g.setColor(new java.awt.Color(c&0xffffff));}
public void setColor(int r,int gg,int b){g.setColor(new java.awt.Color(r,gg,b));}
public void setClip(int x,int y,int w,int h){g.setClip(x,y,Math.max(0,w),Math.max(0,h));}
public void fillRect(int x,int y,int w,int h){g.fillRect(x,y,w,h);}
public void drawRect(int x,int y,int w,int h){g.drawRect(x,y,w,h);}
public void drawLine(int x,int y,int ex,int ey){g.drawLine(x,y,ex,ey);}
public void drawArc(int x,int y,int w,int h,int s,int e){g.drawArc(x,y,w,h,s,e);}
public void fillArc(int x,int y,int w,int h,int s,int e){g.fillArc(x,y,w,h,s,e);}
public void drawImage(Image im,int x,int y,int a){if((a&1)!=0)x-=im.image.getWidth()/2;else if((a&8)!=0)x-=im.image.getWidth();if((a&2)!=0)y-=im.image.getHeight()/2;else if((a&32)!=0)y-=im.image.getHeight();g.drawImage(im.image,x,y,null);}
public void setFont(Font f){font=f;g.setFont(f.font);}
public void drawString(String s,int x,int y,int a){if((a&1)!=0)x-=font.stringWidth(s)/2;else if((a&8)!=0)x-=font.stringWidth(s);if((a&32)!=0)y-=font.getHeight();g.drawString(s,x,y+13);}
public int getClipX(){return g.getClipBounds().x;} public int getClipY(){return g.getClipBounds().y;}
public int getClipWidth(){return g.getClipBounds().width;} public int getClipHeight(){return g.getClipBounds().height;}
public void translate(int x,int y){g.translate(x,y);}
}
''',
'javax/microedition/rms/RecordStore.java':'''package javax.microedition.rms;
import java.util.*;
public class RecordStore {
public static final Map<String,byte[]> records=new HashMap<>(); private final String name;
private RecordStore(String n){name=n;}
public static RecordStore openRecordStore(String n,boolean c)throws Exception{if(!c&&!records.containsKey(n))throw new Exception("missing");return new RecordStore(n);}
public static void deleteRecordStore(String n){records.remove(n);}
public void closeRecordStore(){} public int getNumRecords(){return records.containsKey(name)?1:0;}
public byte[] getRecord(int id){return records.get(name).clone();}
public int addRecord(byte[] b,int o,int n){records.put(name,b==null?new byte[0]:Arrays.copyOfRange(b,o,o+n));return 1;}
public void setRecord(int id,byte[] b,int o,int n){records.put(name,Arrays.copyOfRange(b,o,o+n));}
}
''',
'javax/microedition/media/Control.java':'''package javax.microedition.media; public interface Control {}''',
'javax/microedition/media/Controllable.java':'''package javax.microedition.media; public interface Controllable { Control getControl(String s); }''',
'javax/microedition/media/Player.java':'''package javax.microedition.media;
public interface Player extends Controllable { void prefetch(); void setLoopCount(int n); void start(); void stop(); }''',
'javax/microedition/media/Manager.java':'''package javax.microedition.media;
public class Manager { public static Player createPlayer(java.io.InputStream in,String type){return null;} }''',
'javax/microedition/media/control/VolumeControl.java':'''package javax.microedition.media.control;
public interface VolumeControl extends javax.microedition.media.Control { int setLevel(int n); }'''
}
def main():
 for name,source in SOURCES.items():
  p=SRC/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(source)
 OUT.mkdir(parents=True,exist_ok=True)
 sources=[str(p) for p in SRC.rglob('*.java')]+[str(ROOT/'tools/oracle/Oracle.java')]
 subprocess.run(['javac','-encoding','UTF-8','-d',str(OUT),*sources],check=True)
 with zipfile.ZipFile(ROOT/'research/original/WolfMoon_fixed.jar')as jar:
  for rec in jar.infolist():
   if not rec.is_dir() and rec.filename.endswith('.class'):
    (OUT/rec.filename).write_bytes(jar.read(rec))
 print('Built independent JVM oracle with original classes')
if __name__=='__main__':main()
