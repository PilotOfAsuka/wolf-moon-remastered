extends SceneTree
var vm: WolfVM
var platform: WolfJavaNative
var saves: WolfSaveManager
var results: Array = []
var comparisons: int = 0

func _initialize() -> void: call_deferred("run")

func invoke(cl: String,key: String,args: Array = [],obj: Variant = null) -> Variant:
	var f: Dictionary = vm.launch(cl,key,obj,args)
	var limit: int = 0
	while not f.frames.is_empty() and not vm.halted and limit<10000:
		vm.tick(1); limit+=1
	assert(not vm.halted and f.frames.is_empty(),cl+"."+key)
	return f.result

func state() -> Dictionary:
	var result: Dictionary = {}
	var names: Dictionary = {"B":"byte","S":"short","I":"int","Z":"boolean","[B":"byte[]","[S":"short[]","[I":"int[]","[Z":"boolean[]"}
	for field: Dictionary in vm.classes.i.fields:
		if not int(field.flags)&8 or not names.has(field.desc): continue
		var value: Variant = vm.get_static("i",field.name,field.desc)
		if value is WMObject:
			value = value.data.duplicate()
			if field.desc=="[Z":
				for n: int in value.size(): value[n] = int(value[n])!=0
		elif field.desc=="Z": value = int(value)!=0
		result[field.name+":"+names[field.desc]] = value
	return result

func record(label: String,value: Variant) -> void: results.append({"label":label,"value":value})

func run() -> void:
	vm = WolfVM.new(); saves=WolfSaveManager.new(); saves.persistent=false
	platform=WolfJavaNative.new(vm,saves); vm.native=platform
	var midlet: WMObject = vm.new_object("RMIDlet")
	invoke("RMIDlet","<init>()V",[],midlet)
	vm.set_static("m","a","Ljavax/microedition/midlet/MIDlet;",midlet)
	var vector: WMObject = WMObject.new("java/util/Vector"); vector.data=[]
	vm.set_static("m","a","Ljava/util/Vector;",vector)
	invoke("c","a()V")
	var controller: WMObject = vm.new_object("h"); invoke("h","<init>()V",[],controller)
	vm.set_static("m","a","Lh;",controller)
	var original: WMObject = vm.new_object("i"); invoke("i","<init>()V",[],original)
	vm.set_static("h","a","Li;",original)
	for pair: Array in [["a",123456789],["b",987654321],["c",314159265]]:
		var rng: WMObject = WMObject.new("java/util/Random")
		rng.data = (int(pair[1])^25214903917)&281474976710655
		vm.set_static("i",pair[0],"Ljava/util/Random;",rng)
	invoke("c","a(I)Ljava/lang/Object;",[0])
	for n: int in range(1,58): invoke("c","a(I)Ljava/lang/Object;",[n])
	invoke("i","g()V")
	invoke("i","c()V")
	record("new_game",state())
	var tiles: Array = []
	for p: Array in [[27,39],[27,38],[0,0],[-1,0],[30,0],[0,-1],[0,40]]: tiles.append(invoke("i","a(BBII)I",[p[0],p[1],0,7]))
	record("tiles_and_edges",tiles)
	var passability: Array = []
	for y: int in 40:
		for x: int in 30:
			passability.append([int(invoke("i","b(II)Z",[x,y]))!=0,int(invoke("i","c(BBI)Z",[x,y,0]))!=0])
	record("all_1200_player_creature_cells",passability)
	for hour: int in [0,6,12,18]:
		vm.set_static("i","i","B",hour)
		var damage: Array = []
		for item: int in 26: damage.append(invoke("i","c(I)I",[item]))
		record("weapon_damage_"+str(hour),damage)
	for n: int in 20: invoke("i","r()V")
	record("ai_20_updates",state())
	for n: int in 8: invoke("i","j(I)V",[1])
	record("eight_hours",state())
	vm.set_static("h","a","B",2)
	invoke("i","a(IIZ)V",[10,20,1])
	record("hard_damage",state())
	invoke("i","w()V")
	record("rms_2600",saves.records.w.duplicate())
	vm.set_static("i","C","I",1); vm.set_static("i","d","B",1); vm.set_static("i","e","B",1)
	invoke("i","b()V")
	record("rms_restored",state())
	for n: int in 720: invoke("i","j(I)V",[1])
	record("day_30_transformation",state())
	record("english_texts",vm.get_static("c","b","[Ljava/lang/Object;").data[0].data.duplicate())
	invoke("c","a(I)V",[1]); invoke("c","b(I)V",[0]); invoke("c","a(I)Ljava/lang/Object;",[0])
	record("russian_texts",vm.get_static("c","b","[Ljava/lang/Object;").data[0].data.duplicate())
	var expected: Array = vm.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://../research/reports/jvm_oracle.json")))
	var failures: Array = []
	for n: int in results.size():
		var actual: Dictionary = results[n]
		var reference: Dictionary = expected[n]
		if actual.value is Dictionary:
			for key: String in actual.value:
				comparisons += 1
				if actual.value[key]!=reference.value.get(key): failures.append({"scenario":actual.label,"field":key,"actual":actual.value[key],"expected":reference.value.get(key)})
		else:
			comparisons += 1
			if actual.value!=reference.value: failures.append({"scenario":actual.label,"actual":actual.value,"expected":reference.value})
	var report: Dictionary = {"scenarios":results.size(),"field_comparisons":comparisons,"failures":failures,"instructions":vm.instructions,"intrinsics":vm.intrinsics.hits,"executed_opcodes":vm.opcode_hits.keys()}
	var file: FileAccess = FileAccess.open("res://../research/reports/parity_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("JVM PARITY ",JSON.stringify({"scenarios":results.size(),"comparisons":comparisons,"failures":failures.size()}))
	for f: Dictionary in failures.slice(0,8): print("DIFF ",JSON.stringify(f))
	var result: int = 0 if failures.is_empty() and vm.errors.is_empty() else 1
	WolfGameManager.clear_graph([vm.statics,vm.fibers,vm.class_locks,platform.screen,platform.display,platform.image_cache])
	vm.statics.clear(); vm.fibers.clear(); vm.class_locks.clear(); platform.image_cache.clear(); vm.active.clear()
	platform.vm=null; vm.native=null; vm.intrinsics.vm=null
	quit(result)
