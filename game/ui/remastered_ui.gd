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
var hud: PanelContainer
var inventory_row: HBoxContainer
var stamina: ProgressBar
var stamina_label: Label
var clock_label: Label
var title: Label
var previous_modal: String=""
var previous_inventory: String=""
var message: Label
var map_view: TextureRect
var map_texture: ImageTexture
var hud_reserve: float=128.0
var language: String="ru"
var original_button: Button
var rest_button: Button
const UI_SCHEMA: int=5
var seen_schema: int=-1
var backdrop: TextureRect
var cover: TextureRect
var footer: Label
var main_menu: bool=false
var world_ready: bool=false
var game_buttons: Array[Button]=[]
func t(ru: String,en: String) -> String:return ru if language=="ru" else en

func box(alpha: float=0.96) -> StyleBoxFlat:
 var style: StyleBoxFlat=StyleBoxFlat.new();style.bg_color=Color(0.025,0.04,0.045,alpha)
 style.border_color=Color("899173");style.set_border_width_all(1);style.set_corner_radius_all(5)
 style.content_margin_left=26;style.content_margin_right=26;style.content_margin_top=22;style.content_margin_bottom=22
 return style
func add_button(parent: Node,text: String,callback: Callable) -> Button:
 var b: Button=Button.new();b.text=text;b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size.y=52
 WolfDirectionIcons.apply(b);b.add_theme_font_size_override("font_size",21)
 b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state: String in ["normal","hover","pressed"]:
  var style: StyleBoxFlat=box(0.97)
  style.bg_color=Color("132121") if state=="normal" else Color("293a32")
  style.border_color=Color("465b50") if state=="normal" else Color("c3bd8c")
  style.content_margin_top=8;style.content_margin_bottom=8;style.content_margin_left=16;style.content_margin_right=16
  b.add_theme_stylebox_override(state,style)
 b.pressed.connect(callback);parent.add_child(b);return b
func text_label(parent: Node,text: String,font_size: int=24) -> Label:
 var label: Label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color("e9e6d7"))
 label.add_theme_constant_override("line_spacing",7);parent.add_child(label);return label
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 var gradient: Gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0.0,0.55,1.0]);gradient.colors=PackedColorArray([Color("263831"),Color("0c171b"),Color("040809")])
 var texture: GradientTexture2D=GradientTexture2D.new();texture.gradient=gradient;texture.fill_from=Vector2.ZERO;texture.fill_to=Vector2.ONE
 backdrop=TextureRect.new();backdrop.texture=texture;backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
 cover=TextureRect.new();cover.texture=load("res://assets/sprites/002.png");cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;cover.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;cover.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(cover)
 var cover_material: CanvasItemMaterial=CanvasItemMaterial.new();cover_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;cover.material=cover_material
 var top: HBoxContainer=HBoxContainer.new();top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 top.offset_left=26;top.offset_right=-26;top.offset_top=20;top.add_theme_constant_override("separation",8);add_child(top)
 title=Label.new();title.text="W O L F   M O O N";title.add_theme_font_size_override("font_size",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title)
 var spacer: Control=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(spacer)
 for item: Array in [["M  Карта",51],["J  Журнал",49],["Меню",-6]]:
  var raw: int=item[1];game_buttons.append(add_button(top,item[0],func() -> void:keypad_input.emit(raw)))
 game_buttons.append(add_button(top,"Сохранить",func() -> void:save_requested.emit()))
 game_buttons.append(add_button(top,"Загрузить",func() -> void:load_requested.emit()))
 original_button=add_button(top,"Оригинал · F2",func() -> void:classic_requested.emit())
 hud=PanelContainer.new();var hud_style: StyleBoxFlat=box(1.0);hud_style.set_corner_radius_all(0);hud_style.content_margin_top=14;hud_style.content_margin_bottom=14
 hud.add_theme_stylebox_override("panel",hud_style);hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 hud.offset_top=-hud_reserve;hud.offset_bottom=0;add_child(hud)
 var row: HBoxContainer=HBoxContainer.new();row.add_theme_constant_override("separation",22);hud.add_child(row)
 var stats: VBoxContainer=VBoxContainer.new();stats.custom_minimum_size.x=190;stats.add_theme_constant_override("separation",4);row.add_child(stats)
 clock_label=text_label(stats,"",21)
 stamina=ProgressBar.new();stamina.max_value=100;stamina.show_percentage=false;stamina.custom_minimum_size=Vector2(190,10);stats.add_child(stamina)
 stamina_label=text_label(stats,"",15)
 var inventory_scroll: ScrollContainer=ScrollContainer.new();inventory_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 inventory_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(inventory_scroll)
 inventory_row=HBoxContainer.new();inventory_row.add_theme_constant_override("separation",7);inventory_scroll.add_child(inventory_row)
 rest_button=add_button(row,"Спать · R",func() -> void:rest_requested.emit())
 rest_button.icon=load("res://assets/sprites/058.png");rest_button.expand_icon=true;rest_button.add_theme_constant_override("icon_max_width",38)
 rest_button.custom_minimum_size=Vector2(118,84);rest_button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;rest_button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
 var keys: HBoxContainer=HBoxContainer.new();row.add_child(keys)
 for pair: Array in [["←",-3],["↑",-1],["●",-5],["→",-4]]:
  var raw: int=pair[1];var b: Button=add_button(keys,pair[0],func() -> void:keypad_input.emit(raw));b.custom_minimum_size=Vector2(54,62)
 modal=PanelContainer.new();modal.add_theme_stylebox_override("panel",box());add_child(modal)
 var modal_layout: VBoxContainer=VBoxContainer.new();modal_layout.add_theme_constant_override("separation",16);modal.add_child(modal_layout)
 modal_scroll=ScrollContainer.new();modal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;modal_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;modal_layout.add_child(modal_scroll)
 modal_column=VBoxContainer.new();modal_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;modal_column.add_theme_constant_override("separation",13);modal_scroll.add_child(modal_column)
 modal_actions=HBoxContainer.new();modal_actions.add_theme_constant_override("separation",10);modal_layout.add_child(modal_actions)
 modal_column.minimum_size_changed.connect(func() -> void:call_deferred("layout"))
 message=text_label(self,"",17);message.position=Vector2(28,82)
 map_view=TextureRect.new();map_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 map_view.offset_left=-124;map_view.offset_right=-26;map_view.offset_top=94;map_view.offset_bottom=192
 map_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;map_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(map_view)
 footer=text_label(self,"WASD / стрелки — движение     Enter — действие     M — карта     J — журнал",16)
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);footer.offset_left=30;footer.offset_right=-30;footer.offset_top=-45
 footer.add_theme_color_override("font_color",Color("9bab9a"));footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 resized.connect(layout);call_deferred("layout")
func layout() -> void:
 if modal==null:return
 var width: float=minf(840,size.x-44)
 if main_menu and size.x>=1100:width=510
 modal_column.custom_minimum_size.x=width-72
 var max_height: float=maxf(180,size.y-(hud_reserve if hud.visible else 0)-140)
 modal_actions.visible=modal_actions.get_child_count()>0
 var height: float=minf(max_height,modal_column.get_combined_minimum_size().y+48+(modal_actions.get_combined_minimum_size().y+16 if modal_actions.visible else 0))
 modal.size=Vector2(width,maxf(100,height))
 modal.position=Vector2((size.x-width)/2,maxf(96,(size.y-(hud_reserve if hud.visible else 0)-height)/2))
 if main_menu and size.x>=1100:modal.position.x=size.x*0.54
 cover.visible=main_menu and size.x>=1100
 cover.position=Vector2(size.x*0.07,size.y*0.15);cover.size=Vector2(size.x*0.37,size.y*0.65)
 title.visible=size.x>1000 and not main_menu
 for b: Button in game_buttons:b.visible=world_ready and not main_menu
func update_state(state: Dictionary) -> void:
 if language!=state.get("locale","ru") or seen_schema!=UI_SCHEMA:
  language=state.get("locale","ru");seen_schema=UI_SCHEMA;previous_modal="";previous_inventory=""
  hud_reserve=128.0;hud.offset_top=-hud_reserve
  var captions: Array[String]=[t("M  Карта","M  Map"),t("J  Журнал","J  Journal"),t("Меню","Menu"),t("Сохранить","Save"),t("Загрузить","Load")]
  for index: int in game_buttons.size():game_buttons[index].text=captions[index]
  original_button.text=t("Оригинал · F2","Original · F2")
  rest_button.text=t("Спать · R","Rest · R")
  footer.text=t("WASD / стрелки — движение     Enter — действие     M — карта     J — журнал","WASD / arrows — move     Enter — act     M — map     J — journal")
 world_ready=state.get("world_ready",false)
 game_buttons[0].text=t("M  Закрыть карту","M  Close map") if state.get("full_map",false) else t("M  Карта","M  Map")
 main_menu=state.screen=="j" and int(state.get("menu_id",-1))==0
 hud.visible=world_ready and not main_menu and not state.get("full_map",false)
 map_view.visible=hud.visible
 backdrop.visible=not world_ready or main_menu
 footer.visible=main_menu
 if state.has("map_image"):
  if map_texture==null:map_texture=ImageTexture.create_from_image(state.map_image);map_view.texture=map_texture
  else:map_texture.update(state.map_image)
 if world_ready:
  rest_button.disabled=state.screen!="i" or not state.get("rest_available",false)
  rest_button.tooltip_text=t("Отдохнуть и сохранить игру · R","Rest and save the game · R") if not rest_button.disabled else t("Сейчас здесь нельзя спать","You cannot rest here right now")
  clock_label.text="%s %d  ·  %02d:00"%[t("День","Day"),int(state.day)+1,int(state.hour)]
  stamina.value=state.stamina;stamina_label.text="%s  %d / 100"%[t("Выносливость","Stamina"),int(state.stamina)]
  var inventory_key: String=JSON.stringify([state.inventory,state.selected])
  if inventory_key!=previous_inventory:
   previous_inventory=inventory_key
   for child: Node in inventory_row.get_children():inventory_row.remove_child(child);child.queue_free()
   for item: Dictionary in state.inventory:
    var b: Button=add_button(inventory_row,"",func() -> void:inventory_selected.emit(int(item.id)))
    b.custom_minimum_size=Vector2(90,84);b.icon=load("res://assets/sprites/%03d.png"%int(item.sprite));b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
    b.add_theme_constant_override("icon_max_width",64);b.tooltip_text=item.name+t(" · Q / E — выбор, Enter — использовать"," · Q / E — select, Enter — use")
    for button_state: String in ["normal","hover","pressed"]:
     var compact: StyleBoxFlat=b.get_theme_stylebox(button_state).duplicate();compact.content_margin_left=8;compact.content_margin_right=8;compact.content_margin_top=8;compact.content_margin_bottom=8;b.add_theme_stylebox_override(button_state,compact)
    if int(item.count)>1:
     var count: Label=text_label(b,str(item.count),17);count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
     count.offset_left=-27;count.offset_top=-25;count.offset_right=-5;count.offset_bottom=-3;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;count.mouse_filter=Control.MOUSE_FILTER_IGNORE
     count.add_theme_color_override("font_outline_color",Color.BLACK);count.add_theme_constant_override("outline_size",5)
    if int(item.slot)==int(state.selected):
     var selected: StyleBoxFlat=box();selected.bg_color=Color("263c32");selected.border_color=Color("c8bd85");selected.content_margin_left=8;selected.content_margin_right=8;selected.content_margin_top=8;selected.content_margin_bottom=8;b.add_theme_stylebox_override("normal",selected)
 var key: String=JSON.stringify([state.screen,state.get("title"),state.get("menu"),state.get("selection"),state.dialogue,state.story_sprite,state.softkeys])
 modal.visible=state.screen!="i"
 if key==previous_modal:return
 previous_modal=key
 for child: Node in modal_column.get_children():modal_column.remove_child(child);child.queue_free()
 for child: Node in modal_actions.get_children():modal_actions.remove_child(child);child.queue_free()
 if state.screen=="j":
  if main_menu:text_label(modal_column,t("ГЛАВНОЕ МЕНЮ","MAIN MENU"),23)
  elif not str(state.get("title","")).is_empty():text_label(modal_column,state.title,28)
  var seen: Dictionary={}
  for item: Dictionary in state.menu:
   if item.text in seen:continue
   seen[item.text]=true
   if not item.enabled:text_label(modal_column,WolfControlText.adapt(item.text),24);continue
   var index: int=item.index;var variant: bool=item.variant
   var b: Button=add_button(modal_column,item.text,func() -> void:menu_selected.emit(index,variant))
   if int(item.index)==int(state.selection):b.add_theme_color_override("font_color",Color("e9d99c"))
  if not main_menu:add_softkeys(state.softkeys)
 elif state.screen in ["b","d"]:
  text_label(modal_column,t("ПОДСКАЗКА","TUTORIAL") if state.get("tutorial",false) else (t("ИСТОРИЯ","STORY") if state.screen=="d" else t("СООБЩЕНИЕ","MESSAGE")),17).add_theme_color_override("font_color",Color("bbb68d"))
  if int(state.story_sprite)>=0 and ResourceLoader.exists("res://assets/sprites/%03d.png"%int(state.story_sprite)):
   var picture: TextureRect=TextureRect.new();picture.texture=load("res://assets/sprites/%03d.png"%int(state.story_sprite));picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
   picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.custom_minimum_size.y=200;modal_column.add_child(picture)
  text_label(modal_column,state.dialogue,25)
  if state.screen=="b":add_button(modal_actions,t("Понятно · Enter","Continue · Enter"),func() -> void:keypad_input.emit(53)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
  else:add_softkeys(state.softkeys)
 else:text_label(modal_column,"W O L F   M O O N",32)
 modal_scroll.scroll_vertical=0;call_deferred("layout")
func add_softkeys(labels: Array) -> void:
 var row: HBoxContainer=modal_actions
 for index: int in mini(2,labels.size()):
  if labels[index]==null or str(labels[index]).is_empty():continue
  var raw: int=-6-index
  var b: Button=add_button(row,str(labels[index]),func() -> void:keypad_input.emit(raw));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
