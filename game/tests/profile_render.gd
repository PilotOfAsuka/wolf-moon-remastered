extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game: WolfGameManager=WolfGameManager.new(null,false)
	assert(WolfSnapshot.new().load_game(game,"user://smoke.wms"))
	var fibers: Array[Dictionary]=game.vm.fibers
	var temporary: Array[Dictionary]=[];game.vm.fibers=temporary
	game.vm.max_slice=500000
	var graphics: WMObject=game.vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")
	for profiling: bool in [true,false]:
		game.vm.profile_enabled=profiling
		var start: int=Time.get_ticks_usec();var instructions: int=game.vm.instructions
		var draw: Dictionary=game.vm.launch("i","b(Ljavax/microedition/lcdui/Graphics;)V",null,[graphics])
		while not draw.frames.is_empty() and not game.vm.halted:game.vm.tick(0)
		print("RENDER ","profile" if profiling else "real",": ",(Time.get_ticks_usec()-start)/1000.0," ms / ",game.vm.instructions-instructions," instructions")
	var methods: Array=game.vm.profile_instructions.keys()
	methods.sort_custom(func(a: String,b: String) -> bool:return int(game.vm.profile_instructions[a])>int(game.vm.profile_instructions[b]))
	for method: String in methods.slice(0,18):print(game.vm.profile_instructions[method]," ",method)
	graphics.data.surface.save_png(ProjectSettings.globalize_path("res://../build/render_baseline.png"))
	game.vm.fibers=fibers;game.close();quit()
