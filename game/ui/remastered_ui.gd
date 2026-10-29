class_name WolfRemasteredUI
extends Control
signal keypad_input(raw: int)
signal menu_selected(index: int,variant: bool)
signal inventory_selected(id: int)
signal classic_requested
signal save_requested
signal load_requested
var modal: PanelContainer
var modal_column: VBoxContainer
var hud: PanelContainer
var inventory_row: HBoxContainer
var stamina: ProgressBar
var clock_label: Label
var title: Label
var previous_modal: String=""
var previous_inventory: String=""
var message: Label
var map_view: TextureRect
var map_texture: ImageTexture

func box(alpha: float=0.9) -> StyleBoxFlat:
	var style: StyleBoxFlat=StyleBoxFlat.new();style.bg_color=Color(0.025,0.04,0.045,alpha)
	style.border_color=Color("697262");style.set_border_width_all(1);style.set_corner_radius_all(7)
	style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=16;style.content_margin_bottom=16
	return style

func add_button(parent: Node,text: String,callback: Callable) -> Button:
	var b: Button=Button.new();b.text=text;b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size.y=40
	WolfDirectionIcons.apply(b)
	b.add_theme_font_size_override("font_size",17);b.pressed.connect(callback);parent.add_child(b);return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer=HBoxContainer.new();top.position=Vector2(28,22);top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);top.offset_left=28;top.offset_right=-28;top.offset_top=22
	add_child(top)
	title=Label.new();title.text="W O L F   M O O N";title.add_theme_font_size_override("font_size",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title)
	add_button(top,"Меню",func() -> void: keypad_input.emit(-6))
	add_button(top,"F5  Сохранить",func() -> void: save_requested.emit())
	add_button(top,"Оригинал · F2",func() -> void: classic_requested.emit())
	hud=PanelContainer.new();hud.add_theme_stylebox_override("panel",box(0.84));hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud.offset_left=28;hud.offset_right=-28;hud.offset_top=-108;hud.offset_bottom=-22;add_child(hud)
	var row: HBoxContainer=HBoxContainer.new();row.add_theme_constant_override("separation",24);hud.add_child(row)
	var stats: VBoxContainer=VBoxContainer.new();stats.custom_minimum_size.x=190;row.add_child(stats)
	clock_label=Label.new();clock_label.add_theme_font_size_override("font_size",16);stats.add_child(clock_label)
	stamina=ProgressBar.new();stamina.max_value=100;stamina.show_percentage=false;stamina.custom_minimum_size=Vector2(190,9);stats.add_child(stamina)
	inventory_row=HBoxContainer.new();inventory_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(inventory_row)
	var keys: HBoxContainer=HBoxContainer.new();row.add_child(keys)
	for p: Array in [["←",-3],["↑",-1],["●",-5],["→",-4]]:
		var raw: int=p[1];var b: Button=add_button(keys,p[0],func() -> void: keypad_input.emit(raw));b.custom_minimum_size.x=42
	modal=PanelContainer.new();modal.add_theme_stylebox_override("panel",box());add_child(modal)
	modal_column=VBoxContainer.new();modal_column.add_theme_constant_override("separation",10);modal.add_child(modal_column)
	message=Label.new();message.position=Vector2(28,76);message.add_theme_font_size_override("font_size",15);add_child(message)
	map_view=TextureRect.new();map_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_view.offset_left=-118;map_view.offset_right=-28;map_view.offset_top=88;map_view.offset_bottom=178
	map_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;map_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(map_view)
	resized.connect(layout)
	call_deferred("layout")

func layout() -> void:
	if modal==null:return
	var width: float=minf(650,size.x-48)
	modal.position=Vector2((size.x-width)*0.5,100)
	modal.size=Vector2(width,0)
	title.visible=size.x>700
	hud.offset_left=20;hud.offset_right=-20

func update_state(state: Dictionary) -> void:
	hud.visible=state.get("world_ready",false)
	map_view.visible=hud.visible
	if state.has("map_image"):
		if map_texture==null:map_texture=ImageTexture.create_from_image(state.map_image);map_view.texture=map_texture
		else:map_texture.update(state.map_image)
	if hud.visible:
		clock_label.text="День %d  ·  %02d:00"%[int(state.day)+1,int(state.hour)]
		stamina.value=state.stamina
		var inv_key: String=JSON.stringify([state.inventory,state.selected])
		if inv_key!=previous_inventory:
			previous_inventory=inv_key
			for child: Node in inventory_row.get_children():inventory_row.remove_child(child);child.queue_free()
			for item: Dictionary in state.inventory:
				var b: Button=Button.new();b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size=Vector2(58,54)
				b.icon=load("res://assets/sprites/%03d.png"%int(item.sprite));b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
				b.text=str(item.count);b.tooltip_text=item.name
				b.modulate=Color.WHITE if int(item.slot)==int(state.selected) else Color("a4aea1")
				var id: int=item.id;b.pressed.connect(func() -> void: inventory_selected.emit(id));inventory_row.add_child(b)
	var key: String=JSON.stringify([state.screen,state.get("title"),state.get("menu"),state.get("selection"),state.dialogue,state.story_sprite,state.softkeys])
	modal.visible=state.screen!="i"
	if key==previous_modal:return
	previous_modal=key
	for child: Node in modal_column.get_children():modal_column.remove_child(child);child.queue_free()
	if state.screen=="j":
		if not str(state.get("title","")).is_empty():
			var heading: Label=Label.new();heading.text=state.title;heading.add_theme_font_size_override("font_size",25);modal_column.add_child(heading)
		var seen: Dictionary={}
		for item: Dictionary in state.menu:
			if item.text in seen:continue
			seen[item.text]=true
			if not item.enabled:
				var text: Label=Label.new();text.text=item.text;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				text.custom_minimum_size.x=minf(600,size.x-92);text.add_theme_font_size_override("font_size",20);modal_column.add_child(text)
				continue
			var index: int=item.index;var variant: bool=item.variant
			var b: Button=add_button(modal_column,item.text,func() -> void: menu_selected.emit(index,variant))
			if int(item.index)==int(state.selection):b.modulate=Color("e5d6a5")
		add_softkeys(state.softkeys)
	elif state.screen in ["b","d"]:
		if int(state.story_sprite)>=0 and ResourceLoader.exists("res://assets/sprites/%03d.png"%int(state.story_sprite)):
			var picture: TextureRect=TextureRect.new();picture.texture=load("res://assets/sprites/%03d.png"%int(state.story_sprite))
			picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.custom_minimum_size.y=180;modal_column.add_child(picture)
		var text: Label=Label.new();text.text=state.dialogue;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size.x=minf(600,size.x-92)
		text.add_theme_font_size_override("font_size",20);text.add_theme_color_override("font_color",Color("e5e5d5"));modal_column.add_child(text)
		add_softkeys(state.softkeys)
		if state.screen=="b" and not state.softkeys.any(func(value: Variant) -> bool: return value!=null and not str(value).is_empty()):
			add_button(modal_column,"Ок",func() -> void: keypad_input.emit(53))
	else:
		var label: Label=Label.new();label.text="W O L F   M O O N";label.add_theme_font_size_override("font_size",30);modal_column.add_child(label)
	call_deferred("layout")

func add_softkeys(labels: Array) -> void:
	var row: HBoxContainer=HBoxContainer.new();modal_column.add_child(row)
	for n: int in mini(2,labels.size()):
		if labels[n]==null or str(labels[n]).is_empty():continue
		var raw: int=-6-n
		var b: Button=add_button(row,str(labels[n]),func() -> void: keypad_input.emit(raw))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
