import java.lang.reflect.*;
import java.util.*;
import java.nio.file.*;

/** Calls ORIGINAL JVM bytecode via reflection, disambiguating return types. */
public final class Oracle {
    static Class<?> cls(String name)throws Exception{return Class.forName(name);}
    static Field field(String cl,String name,Class<?> type)throws Exception {
        for(Field f:cls(cl).getDeclaredFields())if(f.getName().equals(name)&&f.getType()==type){f.setAccessible(true);return f;}
        throw new NoSuchFieldException(cl+"."+name+":"+type);
    }
    static Object get(String cl,String name,Class<?> type)throws Exception{return field(cl,name,type).get(null);}
    static void set(String cl,String name,Class<?> type,Object value)throws Exception{field(cl,name,type).set(null,value);}
    static Object call(String cl,String name,Class<?> ret,Class<?>[] types,Object...args)throws Exception {
        for(Method m:cls(cl).getDeclaredMethods())if(m.getName().equals(name)&&m.getReturnType()==ret&&Arrays.equals(m.getParameterTypes(),types)){
            m.setAccessible(true);
            try{return m.invoke(null,args);}catch(InvocationTargetException e){throw new RuntimeException(cl+"."+name,e.getCause());}
        }throw new NoSuchMethodException(cl+"."+name);
    }
    static final Class<?>[] NONE={};
    static final Class<?>[] INT={int.class};
    static final List<Object> results=new ArrayList<>();
    static String json(Object value){
        if(value==null)return "null";
        if(value instanceof String s)return "\""+s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")+"\"";
        if(value instanceof Map<?,?> map){List<String> pairs=new ArrayList<>();for(var e:map.entrySet())pairs.add(json(e.getKey().toString())+":"+json(e.getValue()));return "{"+String.join(",",pairs)+"}";}
        if(value instanceof Iterable<?> list){List<String> items=new ArrayList<>();for(Object item:list)items.add(json(item));return "["+String.join(",",items)+"]";}
        if(value.getClass().isArray()){List<String> items=new ArrayList<>();for(int n=0;n<Array.getLength(value);n++)items.add(json(Array.get(value,n)));return "["+String.join(",",items)+"]";}
        return value.toString();
    }
    static Map<String,Object> state()throws Exception {
        Map<String,Object> state=new TreeMap<>();
        // All primitive original game fields + primitive arrays. Exclude wall clock,
        // rendering buffers/particles; these depend on a device's frame scheduling.
        for(Field f:cls("i").getDeclaredFields()){
            if(!Modifier.isStatic(f.getModifiers()))continue;Class<?> t=f.getType();
            if(t==byte.class||t==short.class||t==int.class||t==boolean.class||(t.isArray()&&t.getComponentType().isPrimitive())){
                f.setAccessible(true);Object v=f.get(null);
                // Snapshot copies prevent later steps mutating earlier records.
                if(v!=null&&t.isArray()){int len=Array.getLength(v);Object copy=Array.newInstance(t.getComponentType(),len);System.arraycopy(v,0,copy,0,len);v=copy;}
                state.put(f.getName()+":"+t.getTypeName(),v);
            }
        }return state;
    }
    static void record(String label,Object value){Map<String,Object> rec=new LinkedHashMap<>();rec.put("label",label);rec.put("value",value);results.add(rec);}
    public static void main(String[] args)throws Exception {
        Object midlet=cls("RMIDlet").getConstructor().newInstance();
        set("m","a",cls("javax.microedition.midlet.MIDlet"),midlet);
        set("m","a",Vector.class,new Vector<>());
        call("c","a",void.class,NONE);
        Object controller=cls("h").getConstructor().newInstance();
        set("m","a",cls("h"),controller);
        Object game=cls("i").getConstructor().newInstance();
        set("h","a",cls("i"),game);
        set("i","a",Random.class,new Random(123456789));
        set("i","b",Random.class,new Random(987654321));
        set("i","c",Random.class,new Random(314159265));
        call("c","a",Object.class,INT,0);
        for(int n=1;n<58;n++)call("c","a",Object.class,INT,n);
        call("i","g",void.class,NONE);
        call("i","c",void.class,NONE);
        record("new_game",state());
        List<Object> tiles=new ArrayList<>();
        for(int[] p:new int[][]{{27,39},{27,38},{0,0},{-1,0},{30,0},{0,-1},{0,40}})
            tiles.add(call("i","a",int.class,new Class<?>[]{byte.class,byte.class,int.class,int.class},(byte)p[0],(byte)p[1],0,7));
        record("tiles_and_edges",tiles);
        List<Object> passability=new ArrayList<>();
        for(int y=0;y<40;y++)for(int x=0;x<30;x++)passability.add(List.of(
            call("i","b",boolean.class,new Class<?>[]{int.class,int.class},x,y),
            call("i","c",boolean.class,new Class<?>[]{byte.class,byte.class,int.class},(byte)x,(byte)y,0)));
        record("all_1200_player_creature_cells",passability);
        for(int hour:new int[]{0,6,12,18}){
            set("i","i",byte.class,(byte)hour);List<Object> damage=new ArrayList<>();
            for(int item=0;item<26;item++)damage.add(call("i","c",int.class,INT,item));
            record("weapon_damage_"+hour,damage);
        }
        for(int n=0;n<20;n++)call("i","r",void.class,NONE);
        record("ai_20_updates",state());
        for(int n=0;n<8;n++)call("i","j",void.class,INT,1);
        record("eight_hours",state());
        set("h","a",byte.class,(byte)2);
        call("i","a",void.class,new Class<?>[]{int.class,int.class,boolean.class},10,20,true);
        record("hard_damage",state());
        call("i","w",void.class,NONE);
        record("rms_2600",javax.microedition.rms.RecordStore.records.get("w"));
        set("i","C",int.class,1);set("i","d",byte.class,(byte)1);set("i","e",byte.class,(byte)1);
        call("i","b",void.class,NONE);
        record("rms_restored",state());
        for(int n=0;n<720;n++)call("i","j",void.class,INT,1);
        record("day_30_transformation",state());
        record("english_texts",((Object[])get("c","b",Object[].class))[0]);
        call("c","a",void.class,INT,1);call("c","b",void.class,INT,0);call("c","a",Object.class,INT,0);
        record("russian_texts",((Object[])get("c","b",Object[].class))[0]);
        Files.writeString(Path.of(args[0]),json(results));
        System.out.println("Original JVM oracle: "+results.size()+" scenarios");
    }
}
