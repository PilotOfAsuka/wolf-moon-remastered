class_name WolfRemasteredWorld
extends Control
## WIDE CLASSIC: original scene painter and unmodified pixel-art assets.
## Project cell/group anchors over the wide window, retain uniform integer pixels
## inside each billboard/composite. Background coverage is tiled, never stretched.
var sprites: Dictionary
var last_revision: int=-1
var last_size: Vector2=Vector2.ZERO
var last_commands: Array=[]
var layers: Array[Node]=[]
var textures: Dictionary={}
var render_signature: String=""
var pixel_scale: float=1.0
var projection_origin: Vector2=Vector2.ZERO

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 clip_contents=true
 sprites=JSON.parse_string(FileAccess.get_file_as_string("res://data/sprites.json"))

func synchronize(state: Dictionary,_delta: float) -> void:
 if not state.get("world_ready",false) or not state.has("render_commands"):return
 var commands: Array=state.render_commands
 var revision: int=int(state.render_revision)
 if revision==last_revision and last_size==size:return
 last_revision=revision;last_size=size;last_commands=commands
 rebuild(commands)

func texture_for(id: int) -> Texture2D:
 if textures.has(id):return textures[id]
 var path: String="res://assets/sprites/%03d.png"%id
 if not ResourceLoader.exists(path):return null
 textures[id]=load(path)
 return textures[id]

func add_primitives(commands: Array[Dictionary],projection: Vector2) -> void:
 if commands.is_empty():return
 var layer: WolfPrimitiveLayer=WolfPrimitiveLayer.new()
 layer.commands=commands;layer.projection=projection;layer.origin=projection_origin
 add_child(layer);layers.append(layer)

func anchor_x(x: float,group: Vector2,projection: Vector2) -> float:
 return group.x*projection.x+(x-group.x)*pixel_scale if group.x>-9000 else x*projection.x

func image_node(parent: Control,texture: Texture2D,pos: Vector2,dims: Vector2) -> void:
 var image: TextureRect=TextureRect.new();image.texture=texture;image.position=pos.round();image.size=dims
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image)

func rebuild(commands: Array) -> void:
 for node: Node in layers:
  remove_child(node);node.queue_free()
 layers.clear()
 if size.x<=0 or size.y<=0:return
 pixel_scale=maxf(1.0,roundf(size.y/281.0))
 var projection: Vector2=Vector2(size.x/240.0,pixel_scale)
 projection_origin=Vector2(0,roundf((size.y-281.0*pixel_scale)*0.5))
 var batch: Array[Dictionary]=[]
 var tiled: Dictionary={}
 var sprite_count: int=0
 for cmd: Dictionary in commands:
  if cmd.kind!="sprite":batch.append(cmd);continue
  add_primitives(batch,projection);batch=[]
  var id: int=int(cmd.id)
  var meta: Dictionary=sprites.get(str(id),{})
  var tex: Texture2D=texture_for(id)
  if meta.is_empty() or tex==null:continue
  var rect: Array=meta.rect
  if int(rect[2])<=0 or int(rect[3])<=0:continue
  var clip: Rect2=Rect2(cmd.clip).intersection(Rect2(0,0,240,281))
  var coverage: Rect2=Rect2(cmd.get("coverage",Rect2i()))
  if not clip.has_area():continue
  var bounds: Rect2=Rect2(clip.position*projection+projection_origin,clip.size*projection)
  var fill_bounds: Rect2=bounds
  if id in [262,263,264,265] and coverage.has_area():
   var cell_clip: Rect2=clip.intersection(Rect2(coverage.position.x,clip.position.y,coverage.size.x,clip.size.y))
   fill_bounds=Rect2(cell_clip.position*projection+projection_origin,cell_clip.size*projection)
  var group: Vector2=cmd.group
  var pos: Vector2=Vector2(anchor_x(float(cmd.x),group,projection)-float(meta.origin[0])*pixel_scale,(float(cmd.y)-float(meta.origin[1]))*pixel_scale)+projection_origin
  var dims: Vector2=Vector2(float(rect[2]),float(rect[3]))*pixel_scale
  var container: Control=Control.new();container.position=bounds.position;container.size=bounds.size;container.clip_contents=true
  container.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(container);layers.append(container)
  if id==269:
   # Original cabin planks are a tiled material, not one stretched photograph.
   var tile_key: String=str(id)+str(clip)
   if tiled.has(tile_key):continue
   tiled[tile_key]=true
   for yy: int in range(0,int(bounds.size.y)+int(dims.y),int(dims.y)):
    for xx: int in range(0,int(bounds.size.x)+int(dims.x),int(dims.x)):
     image_node(container,tex,Vector2(xx,yy),dims)
     sprite_count+=1
  elif int(cmd.group_type)<0 and id in [262,263,264,265] and coverage.has_area() and fill_bounds.size.x>dims.x:
   # Rocky terrain owns the full projected cell. Repeat the source silhouettes
   # at their real pixel scale instead of widening rocks or leaving open seams.
   var step: float=roundf(dims.x*0.75/pixel_scale)*pixel_scale
   var first: float=pos.x
   while first>fill_bounds.position.x:first-=step
   var xx: float=first
   while xx<fill_bounds.end.x:
    image_node(container,tex,Vector2(xx-bounds.position.x,pos.y-bounds.position.y),dims)
    sprite_count+=1;xx+=step
  else:
   image_node(container,tex,pos-bounds.position,dims);sprite_count+=1
 add_primitives(batch,projection)
 render_signature="Wide Classic: %d commands / %d sprites / %dx pixels"%[commands.size(),sprite_count,int(pixel_scale)]
