class_name WolfRemasteredUI
extends Control
signal keypad_input(raw: int)
signal menu_selected(index: int,variant: bool)
signal inventory_selected(id: int)
signal rest_requested
signal classic_requested
signal save_requested
signal load_requested
var modal: PanelContainer
var modal_column: VBoxContainer
var modal_scroll: ScrollContainer
var modal_actions: HBoxContainer
var modal_layout: VBoxContainer
var hud: PanelContainer
var inventory_row: HBoxContainer
var inventory_scroll: ScrollContainer
var stamina: ProgressBar
var stamina_label: Label
var clock_label: Label
var title: Label
var previous_modal: String=""
var previous_inventory: String=""
var previous_selected: int=-999
var message: Label
var map_view: TextureRect
var map_texture: ImageTexture
var map_frame: PanelContainer
var hud_reserve: float=218
var top_reserve: float=66
var language: String="ru"
var original_button: Button
var rest_button: Button
var backdrop: TextureRect
var cover: TextureRect
var footer: Label
var main_menu: bool=false
var world_ready: bool=false
var game_buttons: Array[Button]=[]
var top: PanelContainer
var top_row: HBoxContainer
var hud_body: Control
var stats: Control
var nav_pad: GridContainer
var nav_inline: HBoxContainer
var action_button: Button
var touch_hint: Label
var inventory_caption: Label
var veil: ColorRect
var quick_menu: PopupPanel
var quick_column: VBoxContainer
var remastered_mode: bool=true
var portrait: bool=false
var compact: bool=false
var safe_insets: Vector4=Vector4.ZERO # left, top, right, bottom in UI coordinates
var screen: String=""
var full_map: bool=false
var movement_buttons: Array[Button]=[]
static var frame_cache: Dictionary={}
var top_framed: bool=true

func t(ru: String,en: String) -> String:return ru if language=="ru" else en

static func frame(kind: String="panel",padding: float=12) -> StyleBoxTexture:
	var key: String=kind+str(padding)
	if frame_cache.has(key):return frame_cache[key]
	var style: StyleBoxTexture=StyleBoxTexture.new()
	style.texture=load("res://assets/ui/%s.svg"%kind)
	style.texture_margin_left=8;style.texture_margin_right=8;style.texture_margin_top=8;style.texture_margin_bottom=8
	style.content_margin_left=padding;style.content_margin_right=padding;style.content_margin_top=padding;style.content_margin_bottom=padding
	frame_cache[key]=style
	return style

static func style_button(b: Button,padding: float=10) -> void:
	for variant: String in ["normal","hover","pressed","disabled","focus"]:
		var asset: String={"normal":"button","hover":"button_hover","pressed":"button_pressed","disabled":"button_disabled","focus":"button_selected"}[variant]
		b.add_theme_stylebox_override(variant,frame(asset,padding))
	b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_color_override("font_color",Color("e9e1bf"));b.add_theme_color_override("font_hover_color",Color("fff0be"))
	b.add_theme_color_override("font_disabled_color",Color("6e7d6b"))
	b.add_theme_color_override("icon_disabled_color",Color(0.48,0.53,0.44,0.7))

func add_button(parent: Node,text: String,callback: Callable) -> Button:
	var b: Button=Button.new();b.text=text;b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size.y=48
	b.add_theme_font_size_override("font_size",20);b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	style_button(b);b.pressed.connect(callback);parent.add_child(b);return b

func icon_button(parent: Node,icon: String,callback: Callable) -> Button:
	var b: Button=add_button(parent,"",callback);b.icon=load("res://assets/ui/%s.svg"%icon)
	style_button(b,8)
	b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.custom_minimum_size=Vector2(46,46)
	b.add_theme_constant_override("icon_max_width",28);return b

func text_label(parent: Node,text: String,font_size: int=20) -> Label:
	var label: Label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("e9e1bf"))
	label.add_theme_constant_override("line_spacing",4);parent.add_child(label);return label

func place(control: Control,x: float,y: float,w: float,h: float) -> void:
	control.position=Vector2(roundf(x),roundf(y));control.size=Vector2(maxf(0,roundf(w)),maxf(0,roundf(h)))

func movement(parent: Node,icon: String,raw: int) -> Button:
	var b: Button=icon_button(parent,icon,func() -> void:keypad_input.emit(raw))
	b.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS;b.set_meta("raw",raw);movement_buttons.append(b);return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var gradient: Gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,0.55,1]);gradient.colors=PackedColorArray([Color("263831"),Color("0c171b"),Color("040809")])
	var texture: GradientTexture2D=GradientTexture2D.new();texture.gradient=gradient;texture.fill_from=Vector2.ZERO;texture.fill_to=Vector2.ONE
	backdrop=TextureRect.new();backdrop.texture=texture;backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	cover=TextureRect.new();cover.texture=load("res://assets/sprites/002.png");cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;cover.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;cover.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(cover)
	var cover_material: CanvasItemMaterial=CanvasItemMaterial.new();cover_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;cover.material=cover_material
	top=PanelContainer.new();top.z_index=20;top.add_theme_stylebox_override("panel",frame("panel",7));add_child(top)
	top_row=HBoxContainer.new();top_row.add_theme_constant_override("separation",6);top.add_child(top_row)
	title=text_label(top_row,"W O L F   M O O N",21);title.autowrap_mode=TextServer.AUTOWRAP_OFF
	var spacer: Control=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top_row.add_child(spacer)
	game_buttons.append(icon_button(top_row,"map",func() -> void:keypad_input.emit(51)))
	game_buttons.append(icon_button(top_row,"journal",func() -> void:keypad_input.emit(49)))
	var menu: Button=icon_button(top_row,"menu",show_quick_menu)
	game_buttons.append(menu)
	game_buttons.append(icon_button(top_row,"save",func() -> void:save_requested.emit()))
	game_buttons.append(icon_button(top_row,"load",func() -> void:load_requested.emit()))
	original_button=icon_button(top_row,"render",func() -> void:classic_requested.emit())
	original_button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT;original_button.add_theme_font_size_override("font_size",14)
	original_button.add_theme_constant_override("icon_max_width",22)
	top_row.move_child(menu,top_row.get_child_count()-1)

	hud=PanelContainer.new();hud.add_theme_stylebox_override("panel",frame("panel",0));add_child(hud)
	hud_body=Control.new();hud.add_child(hud_body)
	stats=Control.new();hud_body.add_child(stats)
	clock_label=text_label(stats,"",16);clock_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	stamina_label=text_label(stats,"",13);stamina_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;stamina_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	stamina=ProgressBar.new();stamina.max_value=100;stamina.show_percentage=false;stats.add_child(stamina)
	var track: StyleBoxFlat=StyleBoxFlat.new();track.bg_color=Color("14251f");stamina.add_theme_stylebox_override("background",track)
	var fill: StyleBoxFlat=StyleBoxFlat.new();fill.bg_color=Color("a9b77e");stamina.add_theme_stylebox_override("fill",fill)
	inventory_caption=text_label(hud_body,"",11);inventory_caption.add_theme_color_override("font_color",Color("a4a47e"))
	inventory_scroll=ScrollContainer.new();inventory_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;inventory_scroll.scroll_deadzone=12;hud_body.add_child(inventory_scroll)
	var scrollbar: HScrollBar=inventory_scroll.get_h_scroll_bar()
	for variant: String in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var strip: StyleBoxFlat=StyleBoxFlat.new();strip.bg_color=Color("23352a") if variant=="scroll" else Color("8f9f6c")
		strip.content_margin_top=3;strip.content_margin_bottom=3;scrollbar.add_theme_stylebox_override(variant,strip)
	inventory_row=HBoxContainer.new();inventory_row.mouse_filter=Control.MOUSE_FILTER_PASS;inventory_row.add_theme_constant_override("separation",5);inventory_scroll.add_child(inventory_row)
	rest_button=icon_button(hud_body,"sleep",func() -> void:rest_requested.emit());rest_button.add_theme_font_size_override("font_size",12)
	rest_button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
	nav_pad=GridContainer.new();nav_pad.columns=3;nav_pad.add_theme_constant_override("h_separation",4);nav_pad.add_theme_constant_override("v_separation",4);hud_body.add_child(nav_pad)
	for entry: Array in [["",0],["up",-1],["",0],["left",-3],["down",-2],["right",-4]]:
		if entry[0]=="":
			var blank: Control=Control.new();blank.custom_minimum_size=Vector2(46,46);nav_pad.add_child(blank)
		else:movement(nav_pad,entry[0],entry[1])
	nav_inline=HBoxContainer.new();nav_inline.add_theme_constant_override("separation",4);hud_body.add_child(nav_inline)
	for entry: Array in [["left",-3],["up",-1],["down",-2],["right",-4]]:movement(nav_inline,entry[0],entry[1])
	action_button=icon_button(hud_body,"action",func() -> void:keypad_input.emit(-5));action_button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
	action_button.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS;action_button.add_theme_font_size_override("font_size",13)
	action_button.add_theme_stylebox_override("normal",frame("button_selected",8))
	touch_hint=text_label(hud_body,"",12);touch_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;touch_hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;touch_hint.add_theme_color_override("font_color",Color("99a68c"))

	map_frame=PanelContainer.new();map_frame.add_theme_stylebox_override("panel",frame("panel",6));map_frame.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(map_frame)
	map_frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:keypad_input.emit(51);map_frame.accept_event())
	map_view=TextureRect.new();map_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;map_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;map_view.mouse_filter=Control.MOUSE_FILTER_IGNORE;map_frame.add_child(map_view)
	message=text_label(self,"",14);message.mouse_filter=Control.MOUSE_FILTER_IGNORE
	veil=ColorRect.new();veil.z_index=19;veil.color=Color(0.01,0.025,0.02,0.45);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(veil)
	modal=PanelContainer.new();modal.z_index=21;modal.add_theme_stylebox_override("panel",frame("panel",16));add_child(modal)
	modal_layout=VBoxContainer.new();modal_layout.add_theme_constant_override("separation",12);modal.add_child(modal_layout)
	modal_scroll=ScrollContainer.new();modal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;modal_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;modal_layout.add_child(modal_scroll)
	modal_column=VBoxContainer.new();modal_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;modal_column.add_theme_constant_override("separation",12);modal_scroll.add_child(modal_column)
	modal_actions=HBoxContainer.new();modal_actions.add_theme_constant_override("separation",8);modal_layout.add_child(modal_actions)
	modal_column.minimum_size_changed.connect(func() -> void:call_deferred("layout"))
	footer=text_label(self,"",14);footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;footer.add_theme_color_override("font_color",Color("99a68c"));footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	quick_menu=PopupPanel.new();quick_menu.add_theme_stylebox_override("panel",frame("panel",14));add_child(quick_menu)
	quick_column=VBoxContainer.new();quick_column.add_theme_constant_override("separation",8);quick_menu.add_child(quick_column)
	resized.connect(layout);set_render_mode(true);call_deferred("layout")

func set_render_mode(active: bool) -> void:
	remastered_mode=active
	if original_button==null:return
	var caption: String="Remastered" if active else "Classic"
	if original_button.text!=caption:
		original_button.text=caption;original_button.add_theme_stylebox_override("normal",frame("button_selected" if active else "button",8))
	original_button.tooltip_text=t("Сейчас: ","Current: ")+original_button.text+t(". Переключить вид · F2",". Switch view · F2")

func show_quick_menu() -> void:
	for child: Node in quick_column.get_children():quick_column.remove_child(child);child.queue_free()
	var menu_caption: String=t("Меню игры","Game menu") if screen=="i" else t("Закрыть","Close")
	for entry: Array in [[menu_caption,"menu",func() -> void:
		if screen=="i":keypad_input.emit(-6)],[t("Сохранить","Save game"),"save",func() -> void:save_requested.emit()],[t("Загрузить","Load game"),"load",func() -> void:load_requested.emit()]]:
		var callback: Callable=entry[2]
		var b: Button=add_button(quick_column,entry[0],func() -> void:quick_menu.hide();callback.call())
		b.icon=load("res://assets/ui/%s.svg"%entry[1]);b.custom_minimum_size=Vector2(230,48)
		b.disabled=entry[1]=="save" and not world_ready
	quick_menu.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;quick_menu.content_scale_size=Vector2i(260,200)
	quick_menu.popup_centered(Vector2i(Vector2(260,200)*scale))

func layout() -> void:
	if modal==null:return
	portrait=size.x<size.y;compact=portrait or size.x<950 or size.y<580
	var left: float=safe_insets.x;var right: float=safe_insets.z;var bottom: float=safe_insets.w
	var width: float=size.x-left-right;var margin: float=8 if compact else 18
	top_row.add_theme_constant_override("separation",4 if compact else 6)
	top_reserve=safe_insets.y+(64 if compact else 78)
	place(top,left+margin,safe_insets.y+6,width-margin*2,54 if compact else 62)
	title.visible=not main_menu and ((portrait and width>=370) or (not portrait and width>=700))
	title.text="WM" if portrait else "W O L F   M O O N"
	title.add_theme_font_size_override("font_size",17 if compact else 21)
	if compact and not portrait and width<700:place(top,size.x-right-308,safe_insets.y+6,300,54)
	var framed: bool=not main_menu and world_ready
	if framed!=top_framed:
		top_framed=framed;top.add_theme_stylebox_override("panel",frame("panel",7) if framed else StyleBoxEmpty.new())
	for index: int in game_buttons.size():game_buttons[index].visible=index==2 or (world_ready and not main_menu and (not compact or index<3))
	original_button.custom_minimum_size=Vector2(132,44)
	hud_reserve=(218 if portrait else (116 if compact else 126))+bottom
	place(hud,left,size.y-hud_reserve,width,hud_reserve)
	var w: float=width;var padding: float=12
	var stats_width: float=w-24 if portrait else (w-306 if compact else 174)
	place(stats,padding,10,stats_width,30 if compact else 80)
	if compact:
		place(clock_label,0,0,stats_width*0.59,22);place(stamina_label,stats_width*0.59,1,stats_width*0.41,22);place(stamina,0,26,stats_width,5)
	else:
		place(clock_label,0,0,174,28);place(stamina,0,37,174,7);place(stamina_label,0,55,174,22)
		stamina_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	if compact:stamina_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if portrait:
		place(inventory_scroll,12,48,w-88,64);place(rest_button,w-68,46,56,62)
		place(nav_pad,12,116,146,96);place(action_button,w-108,124,96,80)
		place(touch_hint,164,116,w-278,96)
	elif compact:
		var inv_width: float=w-378
		place(inventory_scroll,12,46,inv_width,64);place(rest_button,24+inv_width,44,56,62)
		place(nav_inline,w-290,49,196,48);place(action_button,w-86,25,74,78)
	else:
		var right_pack: float=w-390
		place(inventory_scroll,204,36,right_pack-220,80);place(rest_button,right_pack,32,64,78)
		place(nav_inline,right_pack+76,48,196,52);place(action_button,w-98,25,82,86)
	nav_pad.visible=portrait;nav_inline.visible=not portrait;touch_hint.visible=portrait and w>=370
	inventory_caption.visible=not compact;place(inventory_caption,204,12,maxf(0,w-620),20)
	var slot: Vector2=Vector2(62,58) if compact else Vector2(76,72)
	for node: Node in inventory_row.get_children():
		if node is Button:node.custom_minimum_size=slot;node.add_theme_constant_override("icon_max_width",44 if compact else 54)
	var map_size: float=68 if compact else 88
	place(map_frame,size.x-right-map_size-margin,top_reserve+6,map_size,map_size)
	place(message,left+margin,top_reserve+6,maxf(0,width-map_size-30),32)
	cover.visible=main_menu and not compact
	place(cover,size.x*0.06,size.y*0.16,size.x*0.37,size.y*0.66)
	var modal_width: float=minf(780,width-24)
	if main_menu and not compact:modal_width=510
	modal_column.custom_minimum_size.x=maxf(1,modal_width-48)
	var available_height: float=maxf(96,size.y-top_reserve-bottom-38)
	modal_actions.visible=modal_actions.get_child_count()>0
	var natural: float=modal_column.get_combined_minimum_size().y+32+(modal_actions.get_combined_minimum_size().y+12 if modal_actions.visible else 0)
	var modal_height: float=minf(available_height,maxf(96,natural))
	place(modal,(size.x-modal_width)/2,top_reserve+maxf(10,(available_height-modal_height)/2),modal_width,modal_height)
	if main_menu and not compact:modal.position.x=size.x*0.54
	place(footer,left+16,size.y-bottom-32,width-32,24);footer.visible=main_menu and not compact

func update_state(state: Dictionary) -> void:
	var next_language: String=state.get("locale","ru")
	var needs_layout: bool=next_language!=language or screen!=state.screen or world_ready!=state.get("world_ready",false) or full_map!=state.get("full_map",false)
	if next_language!=language:language=next_language;previous_modal="";previous_inventory=""
	screen=state.screen;world_ready=state.get("world_ready",false);full_map=state.get("full_map",false)
	main_menu=screen=="j" and int(state.get("menu_id",-1))==0
	hud.visible=world_ready and screen=="i" and not full_map
	map_frame.visible=hud.visible;backdrop.visible=not world_ready or main_menu
	modal.visible=screen!="i";veil.visible=modal.visible and world_ready and not main_menu
	set_render_mode(remastered_mode)
	var tips: Array[String]=[t("Закрыть карту · M","Close map · M") if full_map else t("Карта · M","Map · M"),t("Журнал · J","Journal · J"),t("Меню, сохранение и загрузка","Menu, save and load"),t("Сохранить · F5","Save · F5"),t("Загрузить · F9","Load · F9")]
	for n: int in game_buttons.size():
		game_buttons[n].tooltip_text=tips[n];game_buttons[n].disabled=screen!="i" and n!=2
	for b: Button in movement_buttons:
		b.tooltip_text={-1:t("Вперёд","Move forward"),-2:t("Развернуться","Turn around"),-3:t("Поворот влево","Turn left"),-4:t("Поворот вправо","Turn right")}[int(b.get_meta("raw"))]
	action_button.text=t("Действие","Action");action_button.tooltip_text=t("Использовать предмет · Enter","Use selected item · Enter")
	rest_button.text=t("Спать","Rest");rest_button.disabled=screen!="i" or not state.get("rest_available",false)
	rest_button.tooltip_text=t("Отдохнуть и сохранить игру · R","Rest and save the game · R") if not rest_button.disabled else t("Сейчас здесь нельзя спать","You cannot rest here right now")
	touch_hint.text=t("Выбери предмет\nи нажми действие","Choose an item\nand tap Action")
	inventory_caption.text=t("П Р Е Д М Е Т Ы","I N V E N T O R Y")
	footer.text=t("WASD — движение    Enter — действие    M — карта    J — журнал","WASD — move    Enter — act    M — map    J — journal")
	if state.has("map_image"):
		if map_texture==null:map_texture=ImageTexture.create_from_image(state.map_image);map_view.texture=map_texture
		else:map_texture.update(state.map_image)
	if world_ready:
		rest_button.add_theme_stylebox_override("normal",frame("button_selected" if int(state.selected)==int(state.get("rest_slot",-1)) else "button",8))
		clock_label.text="%s %d · %02d:00"%[t("День","Day"),int(state.day)+1,int(state.hour)]
		stamina.value=state.stamina;stamina_label.text=t("Силы ","Stamina ")+"%d / 100"%int(state.stamina)
		var inventory_key: String=JSON.stringify([state.inventory,state.selected])
		if inventory_key!=previous_inventory:
			needs_layout=true
			previous_inventory=inventory_key
			for child: Node in inventory_row.get_children():inventory_row.remove_child(child);child.queue_free()
			for item: Dictionary in state.inventory:
				var b: Button=add_button(inventory_row,"",func() -> void:inventory_selected.emit(int(item.id)))
				b.mouse_filter=Control.MOUSE_FILTER_PASS
				b.icon=load("res://assets/sprites/%03d.png"%int(item.sprite));b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
				style_button(b,6);b.tooltip_text=item.name
				if int(item.slot)==int(state.selected):b.add_theme_stylebox_override("normal",frame("button_selected",6))
				if int(item.slot)==int(state.selected) and int(state.selected)!=previous_selected:inventory_scroll.call_deferred("ensure_control_visible",b)
				if int(item.count)>1:
					var count: Label=text_label(b,str(item.count),14);count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
					count.offset_left=-26;count.offset_top=-23;count.offset_right=-6;count.offset_bottom=-4;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;count.mouse_filter=Control.MOUSE_FILTER_IGNORE
					count.add_theme_color_override("font_outline_color",Color.BLACK);count.add_theme_constant_override("outline_size",4)
			previous_selected=int(state.selected)
	var key: String=JSON.stringify([screen,state.get("title"),state.get("menu"),state.get("selection"),state.dialogue,state.story_sprite,state.softkeys,compact])
	if key!=previous_modal:
		needs_layout=true
		previous_modal=key
		for container: VBoxContainer in [modal_column]:
			for child: Node in container.get_children():container.remove_child(child);child.queue_free()
		for child: Node in modal_actions.get_children():modal_actions.remove_child(child);child.queue_free()
		if screen=="j":
			if main_menu:
				if compact:
					var logo: TextureRect=TextureRect.new();logo.texture=load("res://assets/sprites/002.png");logo.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
					logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;logo.custom_minimum_size.y=84;logo.material=cover.material;modal_column.add_child(logo)
				else:text_label(modal_column,"W O L F   M O O N",20)
			elif not str(state.get("title","")).is_empty():text_label(modal_column,state.title,20 if compact else 26)
			var seen: Dictionary={}
			for item: Dictionary in state.menu:
				if item.text in seen:continue
				seen[item.text]=true
				if not item.enabled:text_label(modal_column,WolfControlText.for_touch(item.text) if compact else WolfControlText.adapt(item.text),17 if compact else 22);continue
				var index: int=item.index;var variant: bool=item.variant
				var b: Button=add_button(modal_column,item.text,func() -> void:menu_selected.emit(index,variant))
				b.add_theme_font_size_override("font_size",18 if compact else 22)
				if index==int(state.selection):b.add_theme_stylebox_override("normal",frame("button_selected",10))
			if not main_menu:add_softkeys(state.softkeys)
		elif screen in ["b","d"]:
			text_label(modal_column,t("ПОДСКАЗКА","TUTORIAL") if state.get("tutorial",false) else (t("ИСТОРИЯ","STORY") if screen=="d" else t("СООБЩЕНИЕ","MESSAGE")),12 if compact else 16).add_theme_color_override("font_color",Color("c9bc83"))
			if int(state.story_sprite)>=0 and ResourceLoader.exists("res://assets/sprites/%03d.png"%int(state.story_sprite)):
				var picture: TextureRect=TextureRect.new();picture.texture=load("res://assets/sprites/%03d.png"%int(state.story_sprite));picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.custom_minimum_size.y=120 if compact else 200;modal_column.add_child(picture)
			text_label(modal_column,WolfControlText.for_touch(state.dialogue) if compact else state.dialogue,18 if compact else 24)
			if screen=="b":add_button(modal_actions,t("Понятно","Continue"),func() -> void:keypad_input.emit(53)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
			else:add_softkeys(state.softkeys)
		else:text_label(modal_column,"W O L F   M O O N",24)
		modal_scroll.scroll_vertical=0
	if needs_layout:layout()

func add_softkeys(labels: Array) -> void:
	for index: int in mini(2,labels.size()):
		if labels[index]==null or str(labels[index]).is_empty():continue
		var raw: int=-6-index
		var b: Button=add_button(modal_actions,str(labels[index]),func() -> void:keypad_input.emit(raw));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
