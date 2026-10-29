class_name WolfOriginalIntrinsics
extends RefCounted
## Direct, bytecode-checked translations of hot accessors and sprite compositing.
## Every shortcut is optional; tests compare interpreter and intrinsic paths.
var vm: WolfVM
var enabled: bool = true
var hits: Dictionary = {}
const METHODS: Array[String] = ["c.a(IIILjavax/microedition/lcdui/Graphics;)V","c.a(II)I","c.b(I)Ljava/lang/Object;","c.a(I)Ljava/lang/String;","i.a(B)I","i.a(BBII)I"]

func _init(machine: WolfVM) -> void:
	vm = machine

func accepts(owner: String,key: String) -> bool:
	return enabled and (owner+"."+key) in METHODS

func invoke(owner: String,key: String,args: Array) -> Variant:
	var method: String = owner+"."+key
	hits[method] = int(hits.get(method,0))+1
	match method:
		"c.a(IIILjavax/microedition/lcdui/Graphics;)V":
			# c.a(IIILGraphics;)V byte offsets 0..103: original metadata,
			# m.a(Graphics,rect,[I) intersection, drawImage, restore clip.
			var meta: WMObject = vm.get_static("c","a","[[S")
			var record: Array = meta.data[int(args[2])].data
			var cache: WMObject = vm.get_static("c","b","[Ljava/lang/Object;")
			var image: Image = cache.data[int(record[6])].data
			var graphics: MidpGraphics = args[3].data
			var group: Vector2=Vector2(-9999,-9999)
			var group_type: int=-1
			var coverage: Rect2i=Rect2i()
			for n: int in range(vm.active.frames.size()-1,-1,-1):
				var frame: Dictionary=vm.active.frames[n]
				if frame.owner=="i" and frame.method.name=="a" and frame.method.desc=="(IIILjavax/microedition/lcdui/Graphics;)V":
					if group_type<0:group=Vector2(int(frame.locals[0]),int(frame.locals[1]))+Vector2(graphics.offset);group_type=int(frame.locals[2])
				if frame.owner=="i" and frame.method.name=="b" and frame.method.desc=="(IIIIIILjavax/microedition/lcdui/Graphics;)V":
					coverage=Rect2i(int(frame.locals[0])+graphics.offset.x,int(frame.locals[1])+graphics.offset.y,int(frame.locals[2]),int(frame.locals[3]));break
			graphics.record_sprite(int(args[2]),int(args[0])+graphics.offset.x,int(args[1])+graphics.offset.y,group,group_type,coverage)
			var old: Rect2i = graphics.clip
			var scratch: Array = vm.get_static("c","a","[I").data
			scratch[0]=old.position.x-graphics.offset.x; scratch[1]=old.position.y-graphics.offset.y
			scratch[2]=old.size.x; scratch[3]=old.size.y
			var rect: Rect2i = Rect2i(int(args[0])-int(record[4])+graphics.offset.x,int(args[1])-int(record[5])+graphics.offset.y,int(record[2]),int(record[3])).intersection(old)
			if rect.has_area():
				graphics.clip=rect
				graphics.suppress_capture=true
				graphics.blit(image,int(args[0])-int(record[4])-int(record[0]),int(args[1])-int(record[5])-int(record[1]),20)
				graphics.suppress_capture=false
				graphics.clip=old
			return null
		"c.a(II)I": return vm.get_static("c","a","[[S").data[int(args[0])].data[int(args[1])]
		"c.b(I)Ljava/lang/Object;": return vm.get_static("c","b","[Ljava/lang/Object;").data[int(args[0])]
		"c.a(I)Ljava/lang/String;": return vm.get_static("c","b","[Ljava/lang/Object;").data[0].data[int(args[0])]
		"i.a(B)I": return int(args[0]) & 255
		"i.a(BBII)I":
			var w: int = vm.get_static("i","b","B"); var h: int = vm.get_static("i","c","B")
			var x: int = args[0]; var y: int = args[1]
			if x<0 or y<0 or x>=w or y>=h: return -1 if y>=h else 6
			return (int(vm.get_static("i","s","[S").data[x+y*w]) & int(args[3])) >> int(args[2])
	return null
