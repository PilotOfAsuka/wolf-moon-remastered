class_name WolfPresentationState
extends RefCounted
## Read-only projection of original fields. No gameplay decisions or extra alerts.
var vm: WolfVM

func _init(machine: WolfVM) -> void: vm=machine

func array(cl: String,name: String,desc: String) -> Array:
	var o: Variant=vm.get_static(cl,name,desc)
	return o.data if o is WMObject and o.data is Array else []

func text_block(e: WMObject) -> String:
	var lines: Variant=vm.get_field(e,"e","a","[Ljava/lang/String;")
	return " ".join(lines.data) if lines!=null else ""

func paragraphs(container: WMObject,cl: String) -> String:
	var parts: PackedStringArray=[]
	var blocks: Variant=vm.get_field(container,cl,"a","[Le;") if cl=="b" else vm.get_static(cl,"a","[Le;")
	if blocks!=null:
		for e: Variant in blocks.data:
			if e!=null: parts.append(text_block(e))
	return "\n\n".join(parts)

func collect() -> Dictionary:
	var state: Dictionary={"screen":"","world_ready":false,"menu":[],"dialogue":"","story_sprite":-1,"inventory":[],"creatures":[],"objects":[],"items":[],"inside":false,"softkeys":[]}
	var screen: Variant=vm.get_static("m","a","Lp;")
	if screen!=null:
		state.screen=screen.type
		var softkeys: Variant=vm.get_field(screen,"p","a","[Ljava/lang/String;")
		if softkeys!=null:state.softkeys=softkeys.data.duplicate()
	if screen!=null and screen.type=="j":
		state.menu_id=vm.get_field(screen,"j","j","I")
		state.title=vm.get_field(screen,"j","a","Ljava/lang/String;")
		state.selection=vm.get_field(screen,"j","f","I")
		var rows: Variant=vm.get_field(screen,"j","a","Ljava/util/Vector;")
		if rows!=null:
			for n: int in rows.data.size():
				var row: WMObject=rows.data[n]
				var variants: WMObject=vm.get_field(row,"k","a","[Le;")
				var chosen: int=int(vm.get_field(row,"k","a","I"))
				state.menu.append({"index":n,"text":text_block(variants.data[chosen]),"enabled":int(vm.get_field(row,"k","a","B"))!=0,"variant":variants.data.size()>1})
	elif screen!=null and screen.type=="b": state.dialogue=paragraphs(screen,"b")
	elif screen!=null and screen.type=="d":
		state.dialogue=paragraphs(screen,"d")
		state.story_sprite=vm.get_static("d","m","I")
	if not vm.initialized.has("i") or array("i","s","[S").is_empty() or array("i","A","[B").is_empty(): return state
	state.world_ready=true
	var graphics: Variant=vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")
	if graphics!=null:
		state.render_commands=graphics.data.commands
		state.render_revision=graphics.data.revision
	var map_image: Variant=vm.get_static("i","a","Ljavax/microedition/lcdui/Image;")
	if map_image!=null:state.map_image=map_image.data
	state.x=vm.get_static("i","d","B");state.y=vm.get_static("i","e","B");state.facing=vm.get_static("i","h","B")
	state.hour=vm.get_static("i","i","B");state.day=vm.get_static("i","A","I");state.stamina=vm.get_static("i","C","I")
	state.inside=int(vm.get_static("i","c","Z"))!=0
	state.flashlight=int(vm.get_static("i","d","Z"))!=0
	state.battle=int(vm.get_static("i","l","Z"))!=0
	state.transformed=int(vm.get_static("i","C","Z"))!=0
	state.view_offsets=array("h","a","[[B")[int(state.facing)].data.duplicate()
	state.object_icons=array("h","d","[S")
	state.creature_icons=array("h","e","[S")
	state.item_icons=array("h","b","[S")
	var texts: Array=[]
	var cache: Array=array("c","b","[Ljava/lang/Object;")
	if not cache.is_empty() and cache[0]!=null: texts=cache[0].data
	var descriptions: Array=array("h","c","[S")
	var items: Array=array("i","A","[B")
	state.selected=int(vm.get_static("i","o","B"))
	for n: int in range(0,items.size(),2):
		var id: int=int(items[n])
		if id<0 or id>=state.item_icons.size(): continue
		var name: String=""
		if id<descriptions.size() and not texts.is_empty(): name=str(texts[int(descriptions[id])])
		state.inventory.append({"slot":n/2,"id":id,"count":items[n+1],"name":name,"sprite":state.item_icons[id]})
	var types: Array=array("i","h","[B");var xs: Array=array("i","i","[B");var ys: Array=array("i","j","[B");var active: Array=array("i","a","[Z")
	for n: int in types.size(): state.creatures.append({"type":types[n],"x":xs[n],"y":ys[n],"active":int(active[n])!=0})
	var ot: Array=array("i","r","[B");var ox: Array=array("i","s","[B");var oy: Array=array("i","t","[B");var os: Array=array("i","u","[B")
	for n: int in ot.size(): state.objects.append({"type":ot[n],"x":ox[n],"y":oy[n],"status":os[n]})
	var it: Array=array("i","w","[B");var ix: Array=array("i","x","[B");var iy: Array=array("i","y","[B");var ist: Array=array("i","z","[B")
	for n: int in it.size(): state.items.append({"type":it[n],"x":ix[n],"y":iy[n],"status":ist[n]})
	return state
