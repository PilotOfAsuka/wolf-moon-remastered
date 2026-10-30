extends SceneTree
var main: Control
func invoke(owner: String,key: String,args: Array=[],object: Variant=null) -> Variant:
	var vm: WolfVM=main.game.vm
	var old: Array[Dictionary]=vm.fibers;var temporary: Array[Dictionary]=[];vm.fibers=temporary
	var frame: Dictionary=vm.launch(owner,key,object,args)
	while not frame.frames.is_empty() and not vm.halted:vm.tick(0)
	vm.fibers=old;assert(not vm.halted)
	return frame.result
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/"+name+".png"))
func draw_original() -> void:
	var game: WolfGameManager=main.game
	var original: Array[Dictionary]=game.vm.fibers;var temporary: Array[Dictionary]=[];game.vm.fibers=temporary
	var body: WMObject=game.vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")
	var draw: Dictionary=game.vm.launch("i","b(Ljavax/microedition/lcdui/Graphics;)V",null,[body])
	while not draw.frames.is_empty() and not game.vm.halted:game.vm.tick(0)
	var screen: WMObject=game.vm.get_static("h","a","Li;")
	var overlay: Dictionary=game.vm.launch("i","a(Ljavax/microedition/lcdui/Graphics;)V",screen,[game.platform.screen])
	while not overlay.frames.is_empty() and not game.vm.halted:game.vm.tick(0)
	game.vm.fibers=original
	assert(not game.vm.halted)
	var state: Dictionary=main.presentation.collect()
	main.modern_ui.update_state(state);main.layout_screen();state.ui_scale=main.modern_ui.scale.y
	main.modern_world.synchronize(state,0)
func run() -> void:
	root.size=Vector2i(2860,1608)
	main=load("res://main.tscn").instantiate();root.add_child(main);main.set_process(false)
	assert(WolfSnapshot.new().load_game(main.game,"user://smoke.wms"));main.game.saves.persistent=false
	main.game.vm.set_static("m","a","Lp;",main.game.vm.get_static("h","a","Li;"))
	main.layout_screen();await create_timer(0.5).timeout
	var vm: WolfVM=main.game.vm
	vm.set_static("i","d","B",27);vm.set_static("i","e","B",36);vm.set_static("i","h","B",0);vm.set_static("i","m","I",0)
	invoke("i","u()V")
	draw_original();await capture("regression_corpse_4k")
	assert(main.modern_container.get_global_rect().end.y<=main.modern_ui.hud.get_global_rect().position.y+2,"HUD covers game view")
	var body_visible: bool=false
	for cmd: Dictionary in main.modern_world.base_layer.plan:
		if cmd.kind=="texture" and cmd.texture.resource_path.ends_with("384.png"):body_visible=true
	assert(body_visible,"Original corpse missing")
	vm.set_static("i","g","Z",1)
	var neighbors: Array=vm.get_static("i","C","[B").data;neighbors.fill(-1);neighbors[3]=101
	vm.set_static("i","m","Z",1);vm.set_static("i","l","Z",0);vm.set_static("i","e","Z",0);vm.set_static("i","n","B",1)
	var types: Array=vm.get_static("i","r","[B").data;var fire: int=types.find(1);assert(fire>=0)
	vm.get_static("i","u","[B").data[fire]=1;vm.get_static("i","B","[B").data[0]=fire
	draw_original();await capture("regression_icons_4k")
	var expected: Array=[72,int(vm.get_static("h","d","[S").data[1])]
	for id: int in expected:
		var found: bool=false
		for cmd: Dictionary in main.modern_world.overlay_layer.plan:
			if cmd.kind=="texture" and cmd.texture.resource_path.ends_with("%03d.png"%id):found=true
		assert(found,"Original interaction icon missing: "+str(id))
	print("PRESENTATION REGRESSIONS OK: corpse clear of HUD, character/fire icons, 4K UI")
	# A revealed-map fixture makes the renderer inspectable without modifying any
	# live save or revealing unexplored cells in normal gameplay.
	vm.get_static("i","g","[B").data.fill(3)
	vm.set_static("i","h","Z",1);draw_original();await process_frame
	var state: Dictionary=main.presentation.collect();state.ui_scale=main.modern_ui.scale.y;main.modern_world.synchronize(state,0)
	await capture("regression_full_map_4k")
	assert(main.modern_world.map_layer.visible and not main.modern_ui.hud.visible)
	assert(main.modern_world.map_layer.plan.size()>100,"Full original map layer is absent")
	vm.set_static("i","h","Z",0)
	invoke("c","a(I)V",[1]);invoke("c","b(I)V",[0]);invoke("c","a(I)Ljava/lang/Object;",[0])
	var menu: WMObject=invoke("j","a(I)Lj;",[0]);vm.set_static("m","a","Lp;",menu)
	state=main.presentation.collect();main.modern_ui.update_state(state);await capture("regression_main_menu_ru")
	assert(main.modern_ui.original_button.text=="Remastered" and main.modern_ui.original_button.tooltip_text.begins_with("Сейчас"))
	vm.set_static("i","t","I",0);vm.get_static("i","d","[I").data.fill(-1);vm.get_static("i","e","[I").data.fill(-1)
	invoke("i","a(I[Ljava/lang/String;I)V",[60,null,-1]);invoke("i","x()V")
	# Inspect the screen queued by the original dispatcher without resuming
	# old rendering fibers across this isolated language-switch fixture.
	vm.set_static("m","a","Lp;",vm.get_static("m","b","Lp;"))
	state=main.presentation.collect();main.modern_ui.update_state(state);main.layout_screen();state.ui_scale=main.modern_ui.scale.y;main.modern_world.synchronize(state,0)
	await capture("regression_dialogue_ru")
	assert(state.tutorial and state.dialogue.contains("W") and not state.dialogue.contains("нажми 2"),JSON.stringify(state.dialogue))
	invoke("c","a(I)V",[0]);invoke("c","b(I)V",[0]);invoke("c","a(I)Ljava/lang/Object;",[0])
	state=main.presentation.collect();main.modern_ui.update_state(state);assert(main.modern_ui.original_button.text=="Remastered" and main.modern_ui.original_button.tooltip_text.begins_with("Current"))
	print("UI REGRESSIONS OK: fullscreen map, large inventory, RU/EN buttons, modern tutorial")
	main.game.close();main.game=null;quit()
