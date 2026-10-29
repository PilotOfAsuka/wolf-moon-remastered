class_name WolfSnapshot
extends RefCounted
## Versioned graph snapshots include active JVM frames, shared references, random
## seeds, all original flags, pending events and mutable render surfaces.
const VERSION: int = 1
var ids: Dictionary = {}
var nodes: Array = []
var objects: Array = []

func encode(value: Variant) -> Variant:
	if value is WMObject or value is WMLong or value is MidpGraphics or value is Image:
		var id: int = value.get_instance_id()
		if ids.has(id): return {"$ref":ids[id]}
		var n: int = nodes.size(); ids[id] = n; nodes.append({})
		var data: Dictionary
		if value is WMObject: data = {"kind":"object","type":value.type,"fields":encode(value.fields),"data":encode(value.data),"extra":encode(value.extra)}
		elif value is WMLong: data = {"kind":"long","value":value.value}
		elif value is Image: data = {"kind":"image","png":value.save_png_to_buffer()}
		else: data = {"kind":"graphics","surface":encode(value.surface),"clip":value.clip,"offset":value.offset,"color":value.color,"bold":value.font_bold,"text_runs":encode(value.text_runs),"commands":encode(value.commands),"pending":encode(value.pending_commands),"capture_depth":value.capture_depth,"revision":value.revision,"phase":value.phase}
		nodes[n] = data
		return {"$ref":n}
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(encode(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = encode(value[key])
		return result
	return value

func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$ref"): return objects[int(value["$ref"])]
		var result: Dictionary = {}
		for key: Variant in value: result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(decode(item))
		return result
	return value

func save_game(game: WolfGameManager, path: String) -> bool:
	if game.vm.halted: return false
	ids.clear(); nodes.clear()
	var fibers: Array = []
	for f: Dictionary in game.vm.fibers:
		var fiber: Dictionary = f.duplicate()
		fiber.frames = []
		for frame: Dictionary in f.frames:
			var copy: Dictionary = frame.duplicate()
			copy.erase("method")
			copy.key = frame.method.name+frame.method.desc
			fiber.frames.append(copy)
		fibers.append(fiber)
	var roots: Dictionary = {"statics":game.vm.statics,"fibers":fibers,"initialized":game.vm.initialized,"initializing":game.vm.initializing,"locks":game.vm.class_locks,"now":game.vm.now_ms,"epoch":game.vm.epoch_ms,"next_id":game.vm.next_id,"screen":game.platform.screen,"display":game.platform.display,"random_serial":game.platform.random_serial,"records":game.saves.records,"images":game.platform.image_cache}
	var root: Variant = encode(roots)
	var bytes: PackedByteArray = var_to_bytes({"root":root,"nodes":nodes})
	var checksum: String = bytes.hex_encode().sha256_text()
	var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_var({"magic":"WOLFMOON_SNAPSHOT","version":VERSION,"jar":"c7f4c69f94fd6c49abcdc7011dec973b0202aaa23441fefa09ff7df04a77babe","checksum":checksum,"payload":bytes})
	file.flush(); file.close()
	if FileAccess.file_exists(path):
		var backup: Error = DirAccess.copy_absolute(path,path+".bak")
		if backup!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func load_game(game: WolfGameManager,path: String) -> bool:
	return load_file(game,path) or load_file(game,path+".bak")

func load_file(game: WolfGameManager,path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file==null: return false
	var doc: Variant = file.get_var(false)
	if not doc is Dictionary or doc.get("version")!=VERSION or doc.get("magic")!="WOLFMOON_SNAPSHOT": return false
	if doc.get("jar")!="c7f4c69f94fd6c49abcdc7011dec973b0202aaa23441fefa09ff7df04a77babe": return false
	if not doc.get("payload") is PackedByteArray: return false
	if doc.payload.hex_encode().sha256_text()!=doc.get("checksum"): return false
	var graph: Variant = bytes_to_var(doc.payload)
	if not graph is Dictionary or not graph.has_all(["root","nodes"]): return false
	objects.clear()
	for node: Dictionary in graph.nodes:
		match node.kind:
			"object": objects.append(WMObject.new(node.type))
			"long": objects.append(WMLong.new(node.value))
			"image":
				var im: Image = Image.new()
				if im.load_png_from_buffer(node.png)!=OK: return false
				im.convert(Image.FORMAT_RGBA8); objects.append(im)
			"graphics": objects.append(MidpGraphics.new())
			_: return false
	for n: int in objects.size():
		var node: Dictionary = graph.nodes[n]; var value: Variant = objects[n]
		if node.kind=="object": value.fields=decode(node.fields); value.data=decode(node.data); value.extra=decode(node.extra)
		elif node.kind=="graphics":
			value.surface=decode(node.surface); value.clip=node.clip; value.offset=node.offset; value.color=node.color; value.font_bold=node.bold
			value.text_runs.assign(decode(node.text_runs))
			value.commands.assign(decode(node.get("commands",[])))
			value.pending_commands.assign(decode(node.get("pending",[])))
			value.capture_depth=int(node.get("capture_depth",0));value.revision=int(node.get("revision",0))
			value.phase=str(node.get("phase",""))
	var roots: Dictionary = decode(graph.root)
	if not roots.has_all(["statics","fibers","initialized","initializing","locks","now","epoch","next_id","screen","display","random_serial","records","images"]): return false
	# Validate all resumed frames before replacing live state.
	for fiber: Dictionary in roots.fibers:
		for frame: Dictionary in fiber.frames:
			if not frame.has_all(["owner","key","pc","last","locals","stack","lock","entered","this"]): return false
			if not game.vm.classes.has(frame.owner) or not game.vm.classes[frame.owner].methods.has(frame.key): return false
			frame.method = game.vm.classes[frame.owner].methods[frame.key]
			if int(frame.pc)<0 or int(frame.pc)>=frame.method.code.size(): return false
	game.release_state()
	game.vm.statics = roots.statics
	game.vm.fibers.assign(roots.fibers)
	game.vm.initialized=roots.initialized; game.vm.initializing=roots.initializing
	game.vm.class_locks=roots.locks
	game.vm.now_ms=roots.now; game.vm.epoch_ms=roots.epoch; game.vm.next_id=roots.next_id
	game.vm.halted=false; game.vm.errors.clear()
	game.platform.exit_requested=false
	game.platform.screen=roots.screen; game.platform.display=roots.display
	game.platform.random_serial=roots.random_serial; game.platform.image_cache=roots.images
	game.saves.records=roots.records
	for name: String in roots.records: game.saves.commit(name,roots.records[name])
	game.texture.update(game.platform.screen.data.surface)
	game.last_flush = -1
	objects.clear()
	return true
