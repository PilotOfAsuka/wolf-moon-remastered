class_name WolfJavaNative
extends RefCounted
## Only platform APIs are implemented here. No creature/combat/quest decisions.
var vm: WolfVM
var screen: WMObject
var display: WMObject = WMObject.new("javax/microedition/lcdui/Display")
var saves: WolfSaveManager
var audio: Node
var image_cache: Dictionary = {}
var random_serial: int = 0
var flush_count: int = 0
var deterministic: bool = false
var unsupported: Dictionary = {}
var exit_requested: bool = false

func _init(machine: WolfVM, storage: WolfSaveManager, sound: Node = null) -> void:
	vm = machine; saves = storage; audio = sound
	screen = WMObject.new("javax/microedition/lcdui/Graphics")
	screen.data = MidpGraphics.new()

func byte_array(bytes: PackedByteArray) -> WMObject:
	var o: WMObject = vm.new_array("[B",bytes.size())
	for n: int in bytes.size(): o.data[n] = WolfVM.signed(bytes[n],8)
	return o

func bytes_of(array: WMObject) -> PackedByteArray:
	var bytes: PackedByteArray = []
	for b: Variant in array.data: bytes.append(int(b)&255)
	return bytes

func stream(bytes: PackedByteArray, path: String = "") -> WMObject:
	var s: WMObject = WMObject.new("java/io/InputStream")
	s.data = bytes
	s.extra = {"pos":0,"path":path}
	return s

func take(s: WMObject, count: int) -> PackedByteArray:
	var result: PackedByteArray = s.data.slice(int(s.extra.pos),int(s.extra.pos)+count)
	s.extra.pos += result.size()
	if result.size()<count: vm.throw_exception("java/io/EOFException")
	return result

func utf(s: WMObject) -> String:
	var len_bytes: PackedByteArray = take(s,2)
	if vm.exception!=null: return ""
	var bytes: PackedByteArray = take(s,(int(len_bytes[0])<<8)|int(len_bytes[1]))
	var units: PackedByteArray = []; var p: int = 0
	while p<bytes.size():
		var c: int = bytes[p]; p+=1
		var u: int = c
		if c & 224 == 192:
			u = ((c&31)<<6)|(int(bytes[p])&63); p+=1
		elif c & 240 == 224:
			u = ((c&15)<<12)|((int(bytes[p])&63)<<6)|(int(bytes[p+1])&63); p+=2
		units.append(u&255); units.append(u>>8)
	return units.get_string_from_utf16()

func random_next(o: WMObject, bits: int) -> int:
	# java.util.Random's 48-bit LCG; split multiplication avoids overflowing int64.
	var seed: int = int(o.data)
	var low: int = seed & 16777215
	var high: int = seed >> 24
	var product: int = low * 25214903917 + 11
	seed = (product + (((high*25214903917)&16777215)<<24)) & 281474976710655
	o.data = seed
	return seed >> (48-bits)

func invoke(ref: Dictionary, o: Variant, args: Array, fiber: Dictionary) -> Variant:
	var owner: String = ref.owner
	var name: String = ref.name
	var desc: String = ref.desc
	if name=="<init>":
		match owner:
			"java/lang/StringBuffer": o.data = "" if args.is_empty() else str(args[0])
			"java/util/Vector": o.data = []
			"java/lang/Integer": o.data = args[0]
			"java/lang/Thread": o.data = args[0]
			"java/util/Random":
				random_serial += 1
				var seed: int = WolfVM.number(args[0]) if not args.is_empty() else (vm.epoch_ms+vm.now_ms+random_serial*997)
				o.data = (seed ^ 25214903917) & 281474976710655
			"java/io/DataInputStream": o.data = args[0].data; o.extra = args[0].extra
			"java/io/ByteArrayInputStream": o.data = bytes_of(args[0]); o.extra = {"pos":0,"path":""}
		return null
	if owner=="java/lang/System":
		match name:
			"currentTimeMillis": return WMLong.new(vm.epoch_ms+vm.now_ms)
			"getProperty": return "ru" if args[0]=="microedition.locale" else ""
			"gc": return null
			"arraycopy":
				var segment: Array = args[0].data.slice(int(args[1]),int(args[1])+int(args[4]))
				for n: int in segment.size(): args[2].data[int(args[3])+n] = segment[n]
				return null
	if owner=="java/lang/Thread":
		match name:
			"start": vm.launch(o.data.type,"run()V",o.data); return null
			"yield": fiber.yielded = true; return null
			"sleep": fiber.wake = vm.now_ms+maxi(1,WolfVM.number(args[0])); fiber.yielded = true; return null
	if owner=="java/lang/Math":
		if name=="max": return maxi(args[0],args[1])
		if name=="abs": return WolfVM.i32(absi(int(args[0])))
	if owner=="java/util/Random":
		if name=="setSeed": o.data = (WolfVM.number(args[0])^25214903917)&281474976710655; return null
		if name=="nextInt": return WolfVM.i32(random_next(o,32))
	if owner=="java/lang/Integer" and name=="intValue": return o.data
	if owner=="java/lang/String" or o is String:
		match name:
			"valueOf": return str(args[0])
			"equals": return 1 if args[0] is String and o==args[0] else 0
			"length": return o.length()
			"charAt": return o.unicode_at(int(args[0]))
			"substring": return o.substr(int(args[0]),int(args[1])-int(args[0])) if args.size()>1 else o.substr(int(args[0]))
			"indexOf": return o.find(String.chr(int(args[0])),int(args[1]) if args.size()>1 else 0)
			"startsWith": return 1 if o.begins_with(args[0]) else 0
			"toString": return o
	if owner=="java/lang/StringBuffer":
		match name:
			"append":
				o.data += String.chr(int(args[0])) if desc.begins_with("(C)") else ("null" if args[0]==null else str(args[0]))
				return o
			"deleteCharAt": o.data = o.data.substr(0,int(args[0]))+o.data.substr(int(args[0])+1); return o
			"toString": return o.data
	if owner=="java/util/Vector":
		match name:
			"addElement": o.data.append(args[0]); return null
			"elementAt": return o.data[int(args[0])]
			"firstElement": return o.data[0]
			"removeElementAt": o.data.remove_at(int(args[0])); return null
			"size": return o.data.size()
			"isEmpty": return 1 if o.data.is_empty() else 0
	if name=="getClass": return WMObject.new("java/lang/Class")
	if owner=="java/lang/Class" and name=="getResourceAsStream":
		var path: String = "res://assets/original/"+str(args[0]).trim_prefix("/")
		return stream(FileAccess.get_file_as_bytes(path),args[0]) if FileAccess.file_exists(path) else null
	if name=="wait":
		fiber.monitor_depth = int(o.extra.get("monitor_depth",1))
		o.extra.monitor_owner = 0
		o.extra.monitor_depth = 0
		fiber.waiting = o
		fiber.yielded = true
		return null
	if name in ["notify","notifyAll"]:
		for f: Dictionary in vm.fibers:
			if f.waiting==o:
				f.waiting = null
				f.reacquire = o
				if name=="notify": break
		return null
	if owner.begins_with("java/io/"):
		match name:
			"close": return null
			"readUTF": return utf(o)
			"skipBytes":
				var count: int = mini(maxi(0,int(args[0])),o.data.size()-int(o.extra.pos))
				o.extra.pos += count; return count
			"readByte","readShort","readInt":
				var count: int = 1 if name=="readByte" else (2 if name=="readShort" else 4)
				var bytes: PackedByteArray = take(o,count)
				if vm.exception!=null: return 0
				var result: int = 0
				for b: int in bytes: result = (result<<8)|b
				return WolfVM.signed(result,count*8)
			"read":
				var count: int = mini(int(args[2]),o.data.size()-int(o.extra.pos))
				for n: int in count: args[0].data[int(args[1])+n] = WolfVM.signed(int(o.data[int(o.extra.pos)+n]),8)
				o.extra.pos += count
				return count if count>0 else -1
	if owner=="javax/microedition/rms/RecordStore":
		match name:
			"openRecordStore":
				if not saves.records.has(args[0]) and int(args[1])==0:
					vm.throw_exception("javax/microedition/rms/RecordStoreNotFoundException",str(args[0])); return null
				var record: WMObject = WMObject.new(owner); record.data = str(args[0]); return record
			"closeRecordStore": return null
			"getNumRecords": return 1 if saves.records.has(o.data) else 0
			"getRecord":
				var arr: WMObject = vm.new_array("[B",saves.records[o.data].size()); arr.data = saves.records[o.data].duplicate(); return arr
			"addRecord": saves.commit(o.data,[]); return 1
			"setRecord":
				if not saves.commit(o.data,args[1].data.slice(int(args[2]),int(args[2])+int(args[3]))): vm.throw_exception("javax/microedition/rms/RecordStoreException",saves.last_error)
				return null
			"deleteRecordStore": saves.delete(args[0]); return null
	if owner=="javax/microedition/lcdui/Font":
		match name:
			"getFont":
				var font: WMObject = WMObject.new(owner); font.data = {"bold":int(args[1])&1 != 0}; return font
			"getHeight": return int(screen.data.font_data(o.data.bold).height)
			"stringWidth": return screen.data.width(args[0],o.data.bold)
	if owner=="javax/microedition/lcdui/Image":
		match name:
			"createImage":
				var im: Image
				var path: String = ""
				if args.size()==1:
					path = "res://assets/original/"+str(args[0]).trim_prefix("/")
					if image_cache.has(path): return image_cache[path]
					im = load(path).get_image()
				elif args.size()==2: im = Image.create(int(args[0]),int(args[1]),false,Image.FORMAT_RGBA8); im.fill(Color.WHITE)
				else:
					im = Image.new(); im.load_png_from_buffer(bytes_of(args[0]).slice(int(args[1]),int(args[1])+int(args[2])))
				im.convert(Image.FORMAT_RGBA8)
				var obj: WMObject = WMObject.new(owner); obj.data = im; obj.extra.path = path
				if not path.is_empty(): image_cache[path] = obj
				return obj
			"getGraphics":
				var graphics: WMObject = WMObject.new("javax/microedition/lcdui/Graphics"); graphics.data = MidpGraphics.new(o.data); return graphics
	if owner=="javax/microedition/lcdui/Graphics":
		var g: MidpGraphics = o.data
		match name:
			"setColor": g.set_color(int(args[0]) if args.size()==1 else ((int(args[0])<<16)|(int(args[1])<<8)|int(args[2])))
			"setClip": g.set_clip(args[0],args[1],args[2],args[3])
			"fillRect": g.fill_rect(args[0],args[1],args[2],args[3])
			"drawRect": g.draw_rect(args[0],args[1],args[2],args[3])
			"drawLine": g.line(args[0],args[1],args[2],args[3])
			"drawArc": g.arc(args,false)
			"fillArc": g.arc(args,true)
			"drawImage": g.blit(args[0].data,args[1],args[2],args[3])
			"drawString": g.string(args[0],args[1],args[2],args[3])
			"setFont": g.font_bold = args[0].data.bold
			"getClipX": return g.clip.position.x-g.offset.x
			"getClipY": return g.clip.position.y-g.offset.y
			"getClipWidth": return g.clip.size.x
			"getClipHeight": return g.clip.size.y
			"translate": g.offset += Vector2i(args[0],args[1])
			_: vm.fail("Missing graphics API "+name)
		return null
	if name=="getGraphics": return screen
	if name=="flushGraphics": flush_count += 1; return null
	if name=="getWidth": return 240
	if name=="getHeight": return 320
	if name=="getGameAction": return {-1:1,-2:6,-3:2,-4:5,-5:8}.get(int(args[0]),0)
	if name=="setFullScreenMode": return null
	if name=="getDisplay": return display
	if name=="setCurrent": display.data = args[0]; return null
	if name=="notifyDestroyed": vm.halted = true; exit_requested = true; return null
	if name=="notifyPaused": return null
	if owner=="javax/microedition/media/Manager":
		var player: WMObject = WMObject.new("javax/microedition/media/Player"); player.data = args[0].data; player.extra.loop = 1; return player
	if owner.begins_with("javax/microedition/media/"):
		match name:
			"prefetch": return null
			"getControl": return WMObject.new("javax/microedition/media/control/VolumeControl")
			"setLevel": return args[0]
			"setLoopCount": o.extra.loop = args[0]; return null
			"start":
				if audio!=null: audio.play_midi(o.data,int(o.extra.loop))
				return null
			"stop":
				if audio!=null: audio.stop_music()
				return null
	var api: String = owner+"."+name+desc
	unsupported[api] = true
	vm.fail("Missing Java ME API: "+api)
	return null
