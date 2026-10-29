extends SceneTree
var main: Control
var game: WolfGameManager
var vm: WolfVM

func _initialize() -> void:call_deferred("run")

func invoke(key: String,args: Array=[],object: Variant=null,owner: String="i") -> Variant:
	var old: Array[Dictionary]=vm.fibers;var isolated: Array[Dictionary]=[];vm.fibers=isolated
	var task: Dictionary=vm.launch(owner,key,object,args)
	for tick: int in 10000:
		if task.frames.is_empty() or vm.halted:break
		vm.tick(1)
	vm.fibers=old;assert(not vm.halted and task.frames.is_empty(),key)
	return task.result

func prepare(kind: int,lit: bool,inside: bool) -> void:
	assert(WolfSnapshot.new().load_game(game,"user://smoke.wms"))
	game.saves.persistent=false;vm=game.vm
	var types: Array=vm.get_static("i","r","[B").data
	var index: int=types.find(kind);assert(index>=0)
	vm.set_static("i","d","B",vm.get_static("i","s","[B").data[index])
	vm.set_static("i","e","B",vm.get_static("i","t","[B").data[index])
	vm.get_static("i","u","[B").data[index]=1 if lit else 0
	vm.get_static("i","v","[B").data[index]=100
	vm.set_static("i","m","I",-1);vm.set_static("i","C","I",40)
	vm.set_static("i","i","B",20);vm.set_static("i","z","I",32)
	for flag: String in ["l","k","j","C","e","F","u","y","x","h"]:vm.set_static("i",flag,"Z",0)
	vm.set_static("i","c","Z",int(inside));vm.set_static("i","D","I",-1)
	vm.set_static("i","t","I",0);vm.set_static("i","E","B",0)
	vm.get_static("i","d","[I").data.fill(-1);vm.get_static("i","e","[I").data.fill(-1)
	vm.set_static("m","a","Lp;",vm.get_static("h","a","Li;"))
	vm.set_static("m","b","Lp;",vm.get_static("h","a","Li;"))
	vm.get_static("m","a","Ljava/util/Vector;").data.clear()
	vm.get_static("i","b","[Z").data.fill(0)
	invoke("e()V",[],vm.get_static("h","a","Li;"))
	game.saves.records.erase("w")

func check_predicate() -> void:
	var state: Dictionary=main.presentation.collect()
	var selected: int=int(vm.get_static("i","o","B"))
	vm.set_static("i","o","B",state.rest_slot)
	var original: bool=int(invoke("b()Z"))!=0
	vm.set_static("i","o","B",selected)
	assert(state.rest_available==original,"Rest availability differs from original")
	main.modern_ui.update_state(state);main.layout_screen()
	assert(main.modern_ui.rest_button.visible and not main.modern_ui.rest_button.disabled==original)

func run() -> void:
	root.size=Vector2i(1440,810)
	main=load("res://main.tscn").instantiate();root.add_child(main);main.set_process(false);game=main.game
	# Availability is compared with the actual original predicate, with both
	# lit and unlit stoves/campfires and the original restrictions.
	for fixture: Array in [[3,true,true],[3,false,true],[1,true,false],[1,false,false]]:
		prepare(fixture[0],fixture[1],fixture[2]);check_predicate()
		for flag: String in ["C","l","k"]:
			vm.set_static("i",flag,"Z",1);check_predicate();vm.set_static("i",flag,"Z",0)
		vm.set_static("i","m","I",0);check_predicate()
	# End-to-end: click the actual HUD button, process original transitions and
	# text windows, and verify original time, stamina and the 2600-byte autosave.
	for fixture: Array in [[3,true,true],[3,false,true],[1,true,false],[1,false,false]]:
		prepare(fixture[0],fixture[1],fixture[2]);check_predicate()
		var before: int=int(vm.get_static("i","z","I"))
		main.modern_ui.rest_button.pressed.emit()
		for tick: int in 400:
			game.tick(20)
			assert(not vm.halted)
			if game.screen_type()=="b" and tick%15==0:game.key(53)
			if int(vm.get_static("i","z","I"))>before and game.saves.records.has("w"):break
		assert(int(vm.get_static("i","z","I"))==before+8,"Rest did not advance eight hours")
		assert(int(vm.get_static("i","C","I"))==40+8+(8 if fixture[2] else 0)+(8 if fixture[1] else 0),"Warmth bonus differs from original")
		assert(game.saves.records.has("w") and game.saves.records.w.size()==2600,"Original autosave missing")
		print("REST OK: ",("lit " if fixture[1] else "unlit ")+("stove" if fixture[2] else "campfire"),", eight hours, warmth bonus, original autosave")
	prepare(3,true,true)
	invoke("a(I)V",[1],null,"c");invoke("b(I)V",[0],null,"c");invoke("a(I)Ljava/lang/Object;",[0],null,"c")
	invoke("b(Ljavax/microedition/lcdui/Graphics;)V",[vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")])
	invoke("a(Ljavax/microedition/lcdui/Graphics;)V",[game.platform.screen],vm.get_static("h","a","Li;"))
	check_predicate();main.transition.kill();main.apply_blend(1.0);main.page_margin.hide();main.classic_backdrop.hide()
	var state: Dictionary=main.presentation.collect();state.ui_scale=main.modern_ui.scale.y;main.modern_world.synchronize(state,0)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/regression_sleep_button.png"))
	print("REST REGRESSIONS OK")
	game.close();main.game=null;quit()
