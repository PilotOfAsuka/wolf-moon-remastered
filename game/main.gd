extends Control
var game: WolfGameManager
var display: TextureRect
var caption: Label
var transcript: RichTextLabel
var mode_button: Button
var audio: WolfAudioManager
var remastered: bool = false
var time_accumulator: float = 0.0
var side: VBoxContainer
var body: HBoxContainer
var status: Label
var screen_frame: CenterContainer
var snapshot: WolfSnapshot
var touch_bar: HBoxContainer
var keypad: PopupPanel
var header_title: Label
var page_margin: MarginContainer
var modern_container: SubViewportContainer
var modern_world: WolfRemasteredWorld
var modern_ui: WolfRemasteredUI
var presentation: WolfPresentationState
var blend: float=0.0
var transition: Tween
var classic_backdrop: ColorRect

func _ready() -> void:
	if OS.has_feature("web"):
		configure_web_scale()
		get_window().size_changed.connect(configure_web_scale)
	audio = WolfAudioManager.new()
	add_child(audio)
	game = WolfGameManager.new(audio)
	game.vm.max_slice = 12000
	snapshot = WolfSnapshot.new()
	build_ui()
	build_modern()
	if not "--classic" in OS.get_cmdline_user_args(): toggle_mode()
	resized.connect(layout_screen)
	call_deferred("layout_screen")

func configure_web_scale() -> void:
	var css_width: int=int(JavaScriptBridge.eval("window.innerWidth"))
	var css_height: int=int(JavaScriptBridge.eval("window.innerHeight"))
	var target: Vector2i=Vector2i(css_width,css_height)
	if get_window().content_scale_size==target:return
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size=target

func button(parent: Node,text: String,action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	WolfDirectionIcons.apply(b)
	b.custom_minimum_size = Vector2(72,44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func label(parent: Node,text: String,font_size: int,color: Color = Color("e6e0cc")) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func build_ui() -> void:
	var theme: Theme = Theme.new()
	theme.default_font_size = 16
	for state: String in ["normal","hover","pressed"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("182628") if state=="normal" else Color("34433d")
		style.border_color = Color("45594e")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left=12; style.content_margin_right=12
		theme.set_stylebox(state,"Button",style)
	self.theme = theme
	var margin: MarginContainer = MarginContainer.new()
	page_margin=margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for name: String in ["left","right"]: margin.add_theme_constant_override("margin_"+name,24)
	for name: String in ["top","bottom"]: margin.add_theme_constant_override("margin_"+name,8)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title: Label = label(header,"W O L F   M O O N",26)
	header_title=title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_button = button(header,"CLASSIC",toggle_mode)
	mode_button.custom_minimum_size.y=32
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",28)
	column.add_child(body)
	screen_frame = CenterContainer.new()
	screen_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(screen_frame)
	display = TextureRect.new()
	display.texture = game.texture
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.custom_minimum_size = Vector2(480,640)
	screen_frame.add_child(display)
	side = VBoxContainer.new()
	side.custom_minimum_size.x = 320
	side.add_theme_constant_override("separation",12)
	body.add_child(side)
	caption = label(side,"Wolf Moon · 1.06",21)
	label(side,"Клавиши телефона",14,Color("91a396"))
	var soft: HBoxContainer = HBoxContainer.new(); side.add_child(soft)
	var left: Button = button(soft,"Выбрать / Меню",func() -> void: game.key(-6))
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(soft,"Назад",func() -> void: game.key(-7))
	var pad: GridContainer = GridContainer.new(); pad.columns = 3; side.add_child(pad)
	var labels: Array[String] = ["1","2  ↑","3","4  ←","5  ●","6  →","7","8  ↓","9","*","0","#"]
	var codes: Array[int] = [49,50,51,52,53,54,55,56,57,42,48,35]
	for n: int in codes.size():
		var key: int = codes[n]
		var b: Button = button(pad,labels[n],func() -> void: game.key(key))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(side,"Стрелки — движение и поворот\nEnter — действие · Esc — меню\nЦифры — исходное управление",14,Color("91a396"))
	var sound_row: HBoxContainer = HBoxContainer.new(); side.add_child(sound_row)
	label(sound_row,"Музыка",14)
	var volume: HSlider = HSlider.new(); volume.min_value=0; volume.max_value=1; volume.step=0.01; volume.value=audio.music_volume
	volume.focus_mode=Control.FOCUS_NONE
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL; volume.value_changed.connect(audio.set_music); sound_row.add_child(volume)
	var save_row: HBoxContainer = HBoxContainer.new(); side.add_child(save_row)
	button(save_row,"Сохранить · F5",save_snapshot)
	button(save_row,"Загрузить · F9",load_snapshot)
	status = label(side,"",14,Color("b9c9a4"))
	transcript = RichTextLabel.new()
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.custom_minimum_size.y = 140
	transcript.add_theme_color_override("default_color",Color("c1cbbb"))
	transcript.add_theme_font_size_override("normal_font_size",16)
	side.add_child(transcript)
	touch_bar = HBoxContainer.new()
	touch_bar.add_theme_constant_override("separation",4)
	column.add_child(touch_bar)
	for item: Array in [["Меню",-6],["←",-3],["↑",-1],["●",-5],["→",-4]]:
		var raw: int = item[1]
		var b: Button = button(touch_bar,item[0],func() -> void: game.key(raw))
		b.custom_minimum_size.x=40; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var more: Button = button(touch_bar,"123",show_keypad); more.custom_minimum_size.x=40
	keypad = PopupPanel.new(); add_child(keypad)
	var mobile_pad: GridContainer = GridContainer.new(); mobile_pad.columns=3; keypad.add_child(mobile_pad)
	for n: int in codes.size():
		var raw: int = codes[n]
		button(mobile_pad,labels[n],func() -> void: game.key(raw))
	button(mobile_pad,"Меню",func() -> void: game.key(-6))
	button(mobile_pad,"Назад",func() -> void: game.key(-7))
	button(mobile_pad,"Закрыть",func() -> void: keypad.hide())
	label(column,"WOLF MOON  ·  Rovio 2006  ·  Персональная версия",12,Color("65796e"))

func layout_screen() -> void:
	if display==null: return
	header_title.text="W O L F   M O O N" if size.x>=600 else "WOLF MOON"
	header_title.add_theme_font_size_override("font_size",26 if size.x>=600 else 20)
	for name: String in ["left","right"]: page_margin.add_theme_constant_override("margin_"+name,12 if size.x<400 else 24)
	var available: Vector2 = Vector2(maxf(240,size.x-420),maxf(320,size.y-75))
	var scale_factor: float = minf(available.x/240.0,available.y/320.0)
	if not remastered: scale_factor = maxf(1,floorf(scale_factor))
	display.custom_minimum_size = Vector2(240,320)*scale_factor
	side.visible = size.x>=800
	touch_bar.visible = not side.visible
	if size.x<800:
		var factor: float = minf((size.x-48)/240,(size.y-200)/320)
		display.custom_minimum_size = Vector2(240,320)*(factor if remastered else maxf(1,floorf(factor)))

func build_modern() -> void:
	presentation=WolfPresentationState.new(game.vm)
	modern_container=SubViewportContainer.new();modern_container.stretch=true
	modern_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modern_container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	modern_container.z_index=-2;add_child(modern_container)
	var viewport: SubViewport=SubViewport.new()
	viewport.size=Vector2i(1440,810)
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	viewport.handle_input_locally=false;modern_container.add_child(viewport)
	modern_world=WolfRemasteredWorld.new();viewport.add_child(modern_world)
	classic_backdrop=ColorRect.new();classic_backdrop.color=Color.BLACK
	classic_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);classic_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	classic_backdrop.z_index=-1;add_child(classic_backdrop)
	modern_ui=WolfRemasteredUI.new();modern_ui.z_index=10;add_child(modern_ui)
	modern_ui.keypad_input.connect(game.key)
	modern_ui.classic_requested.connect(toggle_mode)
	modern_ui.save_requested.connect(save_snapshot);modern_ui.load_requested.connect(load_snapshot)
	modern_ui.inventory_selected.connect(func(id: int) -> void: game.vm.launch("i","i(I)V",null,[id]))
	modern_ui.menu_selected.connect(func(index: int,variant: bool) -> void:
		var screen: Variant=game.vm.get_static("m","a","Lp;")
		if screen!=null and screen.type=="j":
			game.vm.launch("j","e(I)V",screen,[index])
			game.key(-4 if variant else -6)
	)
	modern_container.visible=false;modern_ui.visible=false

func show_keypad() -> void:
	keypad.popup_centered(Vector2i(280,260))

func toggle_mode() -> void:
	remastered = not remastered
	mode_button.text = "ШИРОКИЙ CLASSIC" if remastered else "ОРИГИНАЛ"
	display.material = null
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if transition!=null and transition.is_running():transition.kill()
	page_margin.visible=true;classic_backdrop.visible=true
	modern_container.visible=true;modern_ui.visible=true
	game.vm.max_slice=5000
	transition=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition.tween_method(apply_blend,blend,1.0 if remastered else 0.0,0.4)
	transition.finished.connect(func() -> void:
		page_margin.visible=not remastered;classic_backdrop.visible=not remastered
		modern_container.visible=remastered;modern_ui.visible=remastered
	)
	layout_screen()

func apply_blend(value: float) -> void:
	blend=value
	page_margin.modulate.a=1.0-value;classic_backdrop.color.a=1.0-value
	modern_container.modulate.a=value;modern_ui.modulate.a=value

func _process(delta: float) -> void:
	if game==null: return
	time_accumulator += delta*1000.0
	var elapsed: int = mini(500,int(time_accumulator))
	time_accumulator -= elapsed
	game.tick(elapsed)
	if game.platform.exit_requested: get_tree().quit(); return
	if transcript!=null: transcript.text = game.platform.screen.data.transcript()
	if not game.vm.errors.is_empty(): status.text = "Ошибка ядра — подробности в журнале"
	if remastered or (transition!=null and transition.is_running()):
		var state: Dictionary=presentation.collect()
		modern_world.synchronize(state,delta)
		modern_ui.update_state(state)
		modern_ui.message.text=status.text

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo: return
	var code: int = event.physical_keycode
	if code in [KEY_F2,KEY_F5,KEY_F9]:
		if event.pressed:
			if code==KEY_F2: toggle_mode()
			elif code==KEY_F5: save_snapshot()
			else: load_snapshot()
		return
	var mapping: Dictionary = {KEY_UP:-1,KEY_W:-1,KEY_DOWN:-2,KEY_S:-2,KEY_LEFT:-3,KEY_A:-3,KEY_RIGHT:-4,KEY_D:-4,KEY_ENTER:-5,KEY_SPACE:-5,KEY_ESCAPE:-6,KEY_TAB:-7,KEY_BACKSPACE:-7,KEY_ASTERISK:42,KEY_NUMBERSIGN:35}
	var raw: int = -999
	if mapping.has(code): raw=mapping[code]
	elif code>=KEY_0 and code<=KEY_9: raw=48+code-KEY_0
	elif code>=KEY_KP_0 and code<=KEY_KP_9: raw=48+code-KEY_KP_0
	if raw!=-999:
		if event.pressed: game.key(raw)
		else: game.key_release(raw)
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		var mapping: Dictionary = {JOY_BUTTON_DPAD_UP:-1,JOY_BUTTON_DPAD_DOWN:-2,JOY_BUTTON_DPAD_LEFT:-3,JOY_BUTTON_DPAD_RIGHT:-4,JOY_BUTTON_A:-5,JOY_BUTTON_B:-7,JOY_BUTTON_START:-6}
		if mapping.has(event.button_index): game.key(mapping[event.button_index])

func save_snapshot() -> void:
	status.text = "Сохранено" if snapshot.save_game(game,"user://quicksave.wms") else "Не удалось сохранить"

func load_snapshot() -> void:
	status.text = "Загружено" if snapshot.load_game(game,"user://quicksave.wms") else "Сохранение не найдено или повреждено"

func _exit_tree() -> void:
	if game!=null: game.close()
