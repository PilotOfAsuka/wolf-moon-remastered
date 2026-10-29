class_name WolfGameManager
extends RefCounted
## Original MIDlet lifecycle, rendering loop, event queue and algorithms run as
## cooperative fibers. UI only submits original keypad events.
var vm: WolfVM
var platform: WolfJavaNative
var saves: WolfSaveManager
var texture: ImageTexture
var last_flush: int = -1

static func clear_graph(roots: Array) -> void:
	# JVM has tracing GC; Godot references are counted. Break original Java cycles
	# when a whole session is replaced or closed, rather than leaking them.
	var pending: Array = roots.duplicate()
	var found: Dictionary = {}
	var objects: Array[WMObject] = []
	while not pending.is_empty():
		var value: Variant = pending.pop_back()
		if value is WMObject:
			var id: int = value.get_instance_id()
			if found.has(id): continue
			found[id]=true; objects.append(value)
			pending.append_array([value.fields,value.data,value.extra])
		elif value is Array: pending.append_array(value)
		elif value is Dictionary:
			for key: Variant in value:
				if key!="method": pending.append(value[key])
	for value: WMObject in objects:
		value.fields.clear(); value.data=null; value.extra.clear()

func release_state() -> void:
	clear_graph([vm.statics,vm.fibers,vm.class_locks,vm.active,platform.screen,platform.display,platform.image_cache])
	vm.statics.clear(); vm.fibers.clear(); vm.class_locks.clear(); platform.image_cache.clear()
	vm.active.clear()

func close() -> void:
	release_state()
	vm.intrinsics.vm=null
	vm.intrinsics.renderer.vm=null
	vm.intrinsics.renderer.sprites=null
	platform.vm=null
	vm.native=null

func _init(audio: Node = null, persistent: bool = true) -> void:
	vm = WolfVM.new()
	if not persistent: vm.epoch_ms = 1170000000000
	saves = WolfSaveManager.new()
	saves.persistent = persistent
	saves.load_all()
	platform = WolfJavaNative.new(vm,saves,audio)
	vm.native = platform
	texture = ImageTexture.create_from_image(platform.screen.data.surface)
	var midlet: WMObject = vm.new_object("RMIDlet")
	vm.launch("RMIDlet","<init>()V",midlet)
	vm.launch("RMIDlet","startApp()V",midlet)

func tick(delta_ms: int) -> void:
	vm.tick(delta_ms)
	if platform.flush_count != last_flush:
		texture.update(platform.screen.data.surface)
		last_flush = platform.flush_count

func key(raw: int) -> void:
	var canvas: Variant = vm.get_static("m","a","Lo;")
	if canvas != null: vm.launch("o","keyPressed(I)V",canvas,[raw])

func key_release(raw: int) -> void:
	var canvas: Variant = vm.get_static("m","a","Lo;")
	if canvas!=null: vm.launch("o","keyReleased(I)V",canvas,[raw])

func rest() -> void:
	if screen_type()!="i":return
	var state: Dictionary=WolfPresentationState.new(vm).collect()
	if not state.get("rest_available",false) or state.get("full_map",false):return
	# Select the original virtual rest slot, then press Fire. The original game
	# decides the duration, warmth bonus, transition, messages and autosave.
	vm.launch("i","h(I)V",null,[int(state.rest_slot)-int(state.selected)])
	key(-5)

func screen_type() -> String:
	var value: Variant = vm.get_static("m","a","Lp;")
	return "" if value==null else value.type

func diagnostic_state() -> Dictionary:
	var state: Dictionary = {"screen":screen_type(),"clock_ms":vm.now_ms,"instructions":vm.instructions,"errors":vm.errors.duplicate()}
	var screen: Variant = vm.get_static("m","a","Lp;")
	if screen!=null and screen.type=="j":
		state["menu"] = vm.get_field(screen,"j","j","I")
		state["selection"] = vm.get_field(screen,"j","f","I")
		state["title"] = vm.get_field(screen,"j","a","Ljava/lang/String;")
	if vm.initialized.has("i"):
		state["player"] = [vm.get_static("i","d","B"),vm.get_static("i","e","B")]
		state["facing"] = vm.get_static("i","h","B")
		state["hour"] = vm.get_static("i","i","B")
		state["day"] = vm.get_static("i","A","I")
		state["stamina"] = vm.get_static("i","C","I")
	return state
