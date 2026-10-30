extends SceneTree
var main: Control
var ui: WolfRemasteredUI
var state: Dictionary
func _initialize() -> void:call_deferred("run")
func invoke(owner: String,key: String,args: Array=[],object: Variant=null) -> Variant:
	var vm: WolfVM=main.game.vm
	var old: Array[Dictionary]=vm.fibers;var isolated: Array[Dictionary]=[];vm.fibers=isolated
	var task: Dictionary=vm.launch(owner,key,object,args)
	for step: int in 10000:
		if task.frames.is_empty() or vm.halted:break
		vm.tick(1)
	vm.fibers=old;assert(not vm.halted and task.frames.is_empty(),key)
	return task.result
func paint() -> void:
	var vm: WolfVM=main.game.vm
	invoke("i","b(Ljavax/microedition/lcdui/Graphics;)V",[vm.get_static("i","b","Ljavax/microedition/lcdui/Graphics;")])
	invoke("i","a(Ljavax/microedition/lcdui/Graphics;)V",[main.game.platform.screen],vm.get_static("h","a","Li;"))
	main.game.texture.update(main.game.platform.screen.data.surface)
	state=main.presentation.collect()
func settle() -> void:
	for tick: int in 3:
		main.layout_screen();ui.update_state(state)
		state.ui_scale=ui.scale.y;state.ui_top_reserve=ui.top_reserve;main.modern_world.synchronize(state,0)
		await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/"+name+".png"))
func assert_inside(control: Control,bounds: Rect2) -> void:
	var rect: Rect2=control.get_global_rect()
	assert(bounds.grow(1).encloses(rect),control.name+" outside screen: "+str(rect)+" vs "+str(bounds))
func run() -> void:
	Input.emulate_touch_from_mouse=true
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse",true)
	root.size=Vector2i(393,660)
	main=load("res://main.tscn").instantiate();root.add_child(main);main.set_process(false);ui=main.modern_ui
	main.transition.kill();main.apply_blend(1);main.page_margin.hide();main.classic_backdrop.hide()
	assert(WolfSnapshot.new().load_game(main.game,"user://smoke.wms"));main.game.saves.persistent=false
	var vm: WolfVM=main.game.vm
	vm.set_static("i","d","B",27);vm.set_static("i","e","B",36);vm.set_static("i","h","B",0)
	vm.set_static("i","i","B",7);vm.set_static("i","m","I",-1);vm.set_static("m","a","Lp;",vm.get_static("h","a","Li;"))
	invoke("i","u()V")
	invoke("c","a(I)V",[1]);invoke("c","b(I)V",[0]);invoke("c","a(I)Ljava/lang/Object;",[0])
	# More than a row of real item sprites must stay usable by scrolling.
	var inventory: Array=vm.get_static("i","A","[B").data
	for n: int in 9:inventory[n*2]=[23,22,3,12,14,24,2,8,9][n];inventory[n*2+1]=3
	vm.set_static("i","p","B",9)
	paint()
	for dimensions: Vector2i in [Vector2i(393,660),Vector2i(320,568),Vector2i(430,850),Vector2i(844,390),Vector2i(568,320),Vector2i(1440,810),Vector2i(2860,1608)]:
		root.size=dimensions;await settle()
		var bounds: Rect2=Rect2(Vector2.ZERO,Vector2(dimensions))
		for control: Control in [ui.top,ui.hud,ui.original_button,ui.rest_button,ui.action_button,ui.inventory_scroll,ui.map_frame]:assert_inside(control,bounds)
		for button: Button in ui.game_buttons:
			if button.visible:assert_inside(button,bounds)
		for button: Button in ui.movement_buttons:
			if button.is_visible_in_tree():
				assert_inside(button,bounds);assert(button.get_global_rect().size.x>=44 and button.get_global_rect().size.y>=44)
		assert(ui.inventory_scroll.size.x>=120,"Inventory collapsed")
		assert(main.modern_container.get_global_rect().end.y<=ui.hud.get_global_rect().position.y+1,"HUD covers world objects")
		assert(ui.original_button.text=="Remastered")
		await capture("mobile_%dx%d"%[dimensions.x,dimensions.y])
		print("RESPONSIVE OK ",dimensions)
	root.size=Vector2i(844,390);ui.safe_insets=Vector4(44,0,44,21);await settle()
	var safe_bounds: Rect2=Rect2(44,0,756,369)
	for control: Control in [ui.top,ui.rest_button,ui.action_button,ui.inventory_scroll,ui.nav_inline]:assert_inside(control,safe_bounds)
	ui.safe_insets=Vector4.ZERO
	root.size=Vector2i(393,660);await settle()
	# Feed real touchscreen events through Godot's input pipeline, rather than
	# calling the button's signal. Navigation should react on finger-down.
	var taps: Array[int]=[]
	ui.keypad_input.connect(func(raw: int) -> void:taps.append(raw))
	var forward: Button=ui.nav_pad.get_child(1)
	var finger: InputEventScreenTouch=InputEventScreenTouch.new();finger.index=0;finger.position=forward.get_global_rect().get_center();finger.pressed=true
	root.push_input(finger,true);await process_frame
	print("TOUCH INPUT OK: immediate forward step, no duplicate on release")
	assert(taps==[-1],"Touch movement did not fire immediately: "+str(taps))
	finger=InputEventScreenTouch.new();finger.index=0;finger.position=forward.get_global_rect().get_center();finger.pressed=false
	root.push_input(finger,true);await process_frame
	assert(taps==[-1],"Touch movement fired twice")
	# ScrollContainer consumes the mouse gesture emulated from touch. The
	# desktop test enables the touchscreen hint and supplies that gesture.
	var inventory_start: Vector2=ui.inventory_scroll.get_global_rect().get_center()+Vector2(65,0)
	var mouse: InputEventMouseButton=InputEventMouseButton.new();mouse.device=-1;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.button_mask=MOUSE_BUTTON_MASK_LEFT;mouse.position=inventory_start;mouse.global_position=inventory_start;mouse.pressed=true
	root.push_input(mouse,true)
	for step: int in 6:
		var drag: InputEventMouseMotion=InputEventMouseMotion.new();drag.device=-1;drag.button_mask=MOUSE_BUTTON_MASK_LEFT;drag.position=inventory_start-Vector2((step+1)*22,0);drag.global_position=drag.position;drag.relative=Vector2(-22,0)
		root.push_input(drag,true);await process_frame
	mouse=InputEventMouseButton.new();mouse.device=-1;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=inventory_start-Vector2(132,0);mouse.global_position=mouse.position;mouse.pressed=false;root.push_input(mouse,true);await process_frame
	assert(ui.inventory_scroll.scroll_horizontal>0,"Inventory does not scroll by touch gesture")
	print("INVENTORY SWIPE OK")
	finger=InputEventScreenTouch.new();finger.index=0;finger.position=ui.action_button.get_global_rect().get_center();finger.pressed=true;root.push_input(finger,true);await process_frame
	assert(taps==[-1,-5],"Touch action did not fire immediately")
	finger=InputEventScreenTouch.new();finger.index=0;finger.position=ui.action_button.get_global_rect().get_center();finger.pressed=false;root.push_input(finger,true);await process_frame
	assert(taps==[-1,-5],"Touch action fired twice")
	ui.show_quick_menu();await process_frame
	assert(ui.quick_menu.visible and ui.quick_column.get_child_count()==3)
	ui.quick_menu.hide()
	var frozen: Dictionary=main.game.diagnostic_state()
	main.toggle_mode();main.transition.kill();main.apply_blend(0);main.modern_container.hide();ui.hide();main.layout_screen();await process_frame
	assert(main.mode_button.text=="Classic" and ui.original_button.text=="Classic")
	assert_inside(main.display,Rect2(Vector2.ZERO,Vector2(root.size)))
	await capture("mobile_classic")
	main.toggle_mode();main.transition.kill();main.apply_blend(1);main.page_margin.hide();main.classic_backdrop.hide();await settle()
	assert(ui.original_button.text=="Remastered" and main.game.diagnostic_state()==frozen)
	# Long dialogue remains scrollable, with its action always inside the screen.
	state.screen="b";state.dialogue="История Жанет Кейн. ".repeat(80);state.tutorial=false
	await settle();assert(ui.modal.visible and not ui.hud.visible)
	assert_inside(ui.modal,Rect2(Vector2.ZERO,Vector2(root.size)));assert_inside(ui.modal_actions,Rect2(Vector2.ZERO,Vector2(root.size)))
	await capture("mobile_dialogue")
	state.screen="i";state.locale="en";await settle();assert(ui.original_button.text=="Remastered" and ui.action_button.text=="Action")
	var texts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/texts.json"))
	assert(WolfControlText.for_touch(texts["Русский"][60]).contains("Нажимай стрелки"))
	assert(WolfControlText.for_touch(texts.English[61]).contains("Swipe the item bar"))
	print("RESPONSIVE UI OK: portrait, landscape, touch targets, inventory, mode labels, dialogue, unchanged game state")
	main.game.close();main.game=null;quit()
