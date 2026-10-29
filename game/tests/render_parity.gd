extends SceneTree
func _initialize() -> void:call_deferred("run")
func primitive(value: Variant) -> Variant:
	if value is WMLong:return value.value
	if value is WMObject:
		if value.type.begins_with("["):return primitive(value.data)
		if value.type=="java/util/Random":return value.data
		return value.type
	if value is Array:
		var result: Array=[]
		for child: Variant in value:result.append(primitive(child))
		return result
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value:result[key]=primitive(value[key])
		return result
	return value
func run() -> void:
	var game: WolfGameManager=WolfGameManager.new(null,false)
	var loader: WolfSnapshot=WolfSnapshot.new()
	var timings: Array=[]
	var scenarios: Array=[[27,38,1,0],[27,37,0,7],[15,20,3,12]]
	assert(loader.load_game(game,"user://smoke.wms"))
	var map: Array=game.vm.get_static("i","s","[S").data
	for index: int in map.size():
		if int(map[index])&7==7:scenarios.append([index%30,index/30,2,19]);break
	for scenario: Array in scenarios:
		var reference: Dictionary={}
		for fast: bool in [false,true]:
			assert(loader.load_game(game,"user://smoke.wms"))
			game.vm.intrinsics.fast_render=fast
			game.vm.set_static("i","d","B",scenario[0]);game.vm.set_static("i","e","B",scenario[1]);game.vm.set_static("i","h","B",scenario[2]);game.vm.set_static("i","i","B",scenario[3])
			var fibers: Array[Dictionary]=game.vm.fibers;var temporary: Array[Dictionary]=[];game.vm.fibers=temporary
			var graphics: WMObject=game.vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")
			var start: int=Time.get_ticks_usec()
			var draw: Dictionary=game.vm.launch("i","b(Ljavax/microedition/lcdui/Graphics;)V",null,[graphics])
			while not draw.frames.is_empty() and not game.vm.halted:game.vm.tick(0)
			assert(not game.vm.halted)
			var elapsed: float=(Time.get_ticks_usec()-start)/1000.0
			var fields: Dictionary={}
			for field: String in game.vm.statics:fields[field]=primitive(game.vm.statics[field])
			var result: Dictionary={"pixels":graphics.data.surface.get_data().hex_encode().sha256_text(),"fields":JSON.stringify(fields)}
			game.vm.fibers=fibers
			print("SCENE ",scenario," ","fast" if fast else "original"," ",elapsed," ms ",result.pixels)
			timings.append({"scene":scenario,"fast":fast,"ms":elapsed})
			if fast:
				assert(result.pixels==reference.pixels,"Renderer changed original pixels")
				if result.fields!=reference.fields:
					var before: Dictionary=JSON.parse_string(reference.fields);var after: Dictionary=JSON.parse_string(result.fields)
					for key: String in after:
						if before.get(key)!=after[key]:print("FIELD DIFF ",key,": ",str(before.get(key)).left(200)," -> ",str(after[key]).left(200))
				assert(result.fields==reference.fields,"Renderer changed original fields / RNG")
			else:reference=result
	FileAccess.open("res://../build/render_parity.json",FileAccess.WRITE).store_string(JSON.stringify(timings,"\t"))
	print("RENDER PARITY OK: ",scenarios.size()," scenes, exact pixels and original fields")
	game.close();quit()
