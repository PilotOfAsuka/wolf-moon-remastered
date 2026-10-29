extends SceneTree
var main: Control

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.save_png(ProjectSettings.globalize_path("res://../build/"+name+".png"))==OK)

func run() -> void:
	root.size=Vector2i(1440,810)
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	if main.remastered:main.toggle_mode()
	main.set_process(false)
	var loader: WolfSnapshot = WolfSnapshot.new()
	assert(loader.load_game(main.game,"user://smoke.wms"))
	# Repaint just the visual scene with the current capture schema. Freeze the
	# original simulation fibers; this preview must not advance a game turn.
	var fibers: Array[Dictionary]=main.game.vm.fibers
	var repaint_fibers: Array[Dictionary]=[]
	main.game.vm.fibers=repaint_fibers
	var graphics: WMObject=main.game.vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")
	var draw: Dictionary=main.game.vm.launch("i","b(Ljavax/microedition/lcdui/Graphics;)V",null,[graphics])
	while not draw.frames.is_empty() and not main.game.vm.halted:main.game.vm.tick(0)
	main.game.vm.fibers=fibers
	main.layout_screen()
	await create_timer(0.5).timeout
	await capture("classic")
	main.toggle_mode()
	var state: Dictionary=main.presentation.collect()
	print("DISPLAY LIST ",state.get("render_commands",[]).size()," commands")
	main.modern_world.synchronize(state,1.0)
	main.modern_ui.update_state(state)
	await create_timer(0.5).timeout
	await capture("wide_classic")
	var frozen: Dictionary=main.game.diagnostic_state()
	main.toggle_mode()
	await create_timer(0.5).timeout
	assert(main.game.diagnostic_state()==frozen)
	main.toggle_mode()
	await create_timer(0.5).timeout
	assert(main.game.diagnostic_state()==frozen)
	print("RENDER TOGGLE STATE OK")
	root.size=Vector2i(480,900)
	await process_frame
	main.layout_screen()
	await capture("portrait")
	print("UI PREVIEWS OK")
	quit()
