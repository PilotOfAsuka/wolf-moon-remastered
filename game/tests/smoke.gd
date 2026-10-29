extends SceneTree
var game: WolfGameManager

func _initialize() -> void:
	call_deferred("run")

func advance(frames: int) -> void:
	for n: int in frames:
		game.tick(20)
		if game.vm.halted: break

func run() -> void:
	game = WolfGameManager.new(null,false)
	advance(300)
	print("BOOT ",JSON.stringify(game.diagnostic_state()))
	print("TEXT ",game.platform.screen.data.transcript())
	for k: int in 6:
		game.key(-6)
		advance(100)
		print("KEY ",k," ",JSON.stringify(game.diagnostic_state()))
		print("TEXT ",game.platform.screen.data.transcript())
		if game.vm.halted: break
	game.key(-7) # Intro skip, original softkey.
	advance(150)
	game.key(53) # Close the original tutorial window.
	advance(100)
	print("PLAY ",JSON.stringify(game.diagnostic_state()))
	print("TEXT ",game.platform.screen.data.transcript())
	for raw: int in [-4,-3,-1,-4,-1,-5]:
		game.key(raw); advance(30)
		print("ACTION ",raw," ",JSON.stringify(game.diagnostic_state()))
	var saver: WolfSnapshot = WolfSnapshot.new()
	var before: Dictionary = game.diagnostic_state()
	assert(saver.save_game(game,"user://smoke.wms"))
	game.key(-3); advance(40)
	assert(saver.load_game(game,"user://smoke.wms"))
	assert(game.diagnostic_state().player==before.player)
	assert(game.diagnostic_state().facing==before.facing)
	print("SNAPSHOT OK ",JSON.stringify(game.diagnostic_state()))
	# Replaying from the same snapshot must preserve hidden state and RNG, too.
	game.key(-1); advance(30)
	var replay_one: Dictionary = state_fingerprint()
	assert(saver.load_game(game,"user://smoke.wms"))
	game.key(-1); advance(30)
	assert(state_fingerprint()==replay_one)
	assert(saver.load_game(game,"user://smoke.wms"))
	var report: Dictionary = {"state":game.diagnostic_state(),"snapshot_roundtrip":true,"deterministic_replay":true,"opcodes":game.vm.opcode_hits.keys(),"api_errors":game.platform.unsupported,"errors":game.vm.errors}
	var result_file: FileAccess = FileAccess.open("res://../research/reports/smoke_results.json",FileAccess.WRITE)
	result_file.store_string(JSON.stringify(report,"\t")); result_file.close()
	game.platform.screen.data.surface.save_png(ProjectSettings.globalize_path("res://../build/smoke.png"))
	print("FIBERS ",game.vm.fibers.size()," ERRORS ",game.vm.errors," APIS ",game.platform.unsupported)
	var result: int = 0 if game.vm.errors.is_empty() else 1
	game.close()
	quit(result)

func state_fingerprint() -> Dictionary:
	var result: Dictionary = {}
	for field: Dictionary in game.vm.classes.i.fields:
		if not int(field.flags)&8: continue
		var value: Variant = game.vm.get_static("i",field.name,field.desc)
		if field.desc in ["Z","I","B","S"]: result[field.name+field.desc]=value
		elif value is WMObject and value.type in ["[I","[B","[S","[Z"]: result[field.name+field.desc]=value.data.duplicate()
		elif value is WMObject and value.type=="java/util/Random": result[field.name+"rng"]=value.data
	return result
