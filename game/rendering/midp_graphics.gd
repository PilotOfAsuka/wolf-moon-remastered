class_name MidpGraphics
extends RefCounted
## Java ME raster bridge. All perspective geometry, order, clipping, palettes,
## sprite selection and random decoration remain in original i/h/c methods.
var surface: Image
var clip: Rect2i
var offset: Vector2i = Vector2i.ZERO
var color: Color = Color.WHITE
var font_bold: bool = false
var text_runs: Array[Dictionary] = []
var glyph_cache: Dictionary = {}
var fonts: Dictionary = {}
var atlas: Dictionary = {}
var dirty: bool = false
var commands: Array[Dictionary] = []
var pending_commands: Array[Dictionary] = []
var capture_depth: int = 0
var revision: int = 0
var suppress_capture: bool = false
var phase: String = ""

func begin_capture() -> void:
	if capture_depth==0: pending_commands.clear()
	capture_depth+=1

func end_capture() -> void:
	capture_depth=maxi(0,capture_depth-1)
	if capture_depth==0:
		commands=pending_commands
		pending_commands=[]
		revision+=1

func record(command: Dictionary) -> void:
	if capture_depth>0 and not suppress_capture:
		command.clip=clip
		command.color=color
		command.phase=phase
		pending_commands.append(command)

func record_sprite(id: int,x: int,y: int,group: Vector2,group_type: int,coverage: Rect2i=Rect2i()) -> void:
	record({"kind":"sprite","id":id,"x":x,"y":y,"group":group,"group_type":group_type,"coverage":coverage})

func _init(image: Image = null) -> void:
	surface = image if image != null else Image.create(240,320,false,Image.FORMAT_RGBA8)
	clip = Rect2i(Vector2i.ZERO,surface.get_size())
	surface.fill(Color.BLACK)
	for kind: String in ["regular","bold"]:
		fonts[kind] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fonts/"+kind+".json"))
		atlas[kind] = load("res://assets/fonts/"+kind+".png").get_image()

func set_color(rgb: int) -> void:
	color = Color8((rgb>>16)&255,(rgb>>8)&255,rgb&255)

func set_clip(x: int,y: int,w: int,h: int) -> void:
	clip = Rect2i(x+offset.x,y+offset.y,maxi(0,w),maxi(0,h)).intersection(Rect2i(Vector2i.ZERO,surface.get_size()))

func fill_rect(x: int,y: int,w: int,h: int) -> void:
	record({"kind":"rect","rect":Rect2i(x+offset.x,y+offset.y,w,h)})
	var rect: Rect2i = Rect2i(x+offset.x,y+offset.y,maxi(0,w),maxi(0,h)).intersection(clip)
	if rect.has_area():
		remove_occluded(rect)
		surface.fill_rect(rect,color)
		dirty = true
		if rect == Rect2i(Vector2i.ZERO,surface.get_size()): text_runs.clear()

func remove_occluded(rect: Rect2i) -> void:
	for n: int in range(text_runs.size()-1,-1,-1):
		var run: Dictionary = text_runs[n]
		var bounds: Rect2i = run.get("bounds",Rect2i(int(run.x),int(run.y),width(run.text,false),16))
		if rect.encloses(bounds): text_runs.remove_at(n)

func pixel(x: int,y: int) -> void:
	var pos: Vector2i = Vector2i(x,y)+offset
	if clip.has_point(pos): surface.set_pixelv(pos,color); dirty = true

func line(x: int,y: int,ex: int,ey: int) -> void:
	record({"kind":"line","a":Vector2(x,y)+Vector2(offset),"b":Vector2(ex,ey)+Vector2(offset)})
	if x==ex or y==ey:
		var rect: Rect2i=Rect2i(Vector2i(mini(x,ex),mini(y,ey))+offset,Vector2i(absi(ex-x)+1,absi(ey-y)+1)).intersection(clip)
		if rect.has_area():surface.fill_rect(rect,color);dirty=true
		return
	var dx: int = absi(ex-x); var dy: int = -absi(ey-y)
	var sx: int = 1 if x<ex else -1; var sy: int = 1 if y<ey else -1
	var err: int = dx+dy
	while true:
		pixel(x,y)
		if x==ex and y==ey: break
		var e2: int = err*2
		if e2>=dy: err+=dy; x+=sx
		if e2<=dx: err+=dx; y+=sy

func draw_rect(x: int,y: int,w: int,h: int) -> void:
	if w<0 or h<0: return
	line(x,y,x+w,y); line(x+w,y,x+w,y+h); line(x+w,y+h,x,y+h); line(x,y+h,x,y)

func arc(args: Array, filled: bool) -> void:
	record({"kind":"arc","args":args.duplicate(),"filled":filled,"offset":offset})
	var x: int = args[0]; var y: int = args[1]; var w: int = args[2]; var h: int = args[3]
	if w<=0 or h<=0: return
	var start: float = float(args[4]); var extent: float = float(args[5])
	for yy: int in range(h+1):
		for xx: int in range(w+1):
			var nx: float = (float(xx)-w*0.5)/(w*0.5)
			var ny: float = (float(yy)-h*0.5)/(h*0.5)
			var radius: float = nx*nx+ny*ny
			if radius>1.05 or (not filled and radius<1.0-3.0/maxf(w,h)): continue
			var angle: float = fposmod(rad_to_deg(atan2(-ny,nx))-start,360.0)
			if absf(extent)>=360.0 or (extent>=0.0 and angle<=extent) or (extent<0.0 and angle>=360.0+extent): pixel(x+xx,y+yy)

func blit(image: Image, x: int,y: int,anchor: int = 20, occludes_text: bool = true) -> void:
	if image==null: return
	var dims: Vector2i = image.get_size()
	if anchor & 1: x -= dims.x/2
	elif anchor & 8: x -= dims.x
	if anchor & 2: y -= dims.y/2
	elif anchor & 32: y -= dims.y
	var dest: Rect2i = Rect2i(Vector2i(x,y)+offset,dims)
	var visible: Rect2i = dest.intersection(clip)
	record({"kind":"image","image":image,"rect":dest})
	if visible.has_area():
		if occludes_text: remove_occluded(visible)
		surface.blend_rect(image,Rect2i(visible.position-dest.position,visible.size),visible.position)
		dirty = true

func font_data(bold: bool) -> Dictionary:
	return fonts["bold" if bold else "regular"]

func width(text: String,bold: bool) -> int:
	var result: int = 0
	var data: Dictionary = font_data(bold)
	for ch: String in text:
		result += int(data.glyphs.get(str(ch.unicode_at(0)),data.glyphs["63"]).advance)
	return result

func glyph(ch: String,bold: bool) -> Image:
	var kind: String = "bold" if bold else "regular"
	var key: String = kind+str(color.to_rgba32())+ch
	if glyph_cache.has(key): return glyph_cache[key]
	var data: Dictionary = fonts[kind].glyphs.get(str(ch.unicode_at(0)),fonts[kind].glyphs["63"])
	var r: Array = data.rect
	var im: Image = atlas[kind].get_region(Rect2i(r[0],r[1],r[2],r[3]))
	im.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = im.get_data()
	for n: int in range(0,pixels.size(),4):
		pixels[n] = int(color.r*255); pixels[n+1] = int(color.g*255); pixels[n+2] = int(color.b*255)
	im = Image.create_from_data(im.get_width(),im.get_height(),false,Image.FORMAT_RGBA8,pixels)
	glyph_cache[key] = im
	return im

func string(text: String,x: int,y: int,anchor: int) -> void:
	var w: int = width(text,font_bold)
	var fd: Dictionary = font_data(font_bold)
	if anchor & 1: x -= w/2
	elif anchor & 8: x -= w
	if anchor & 32: y -= int(fd.height)
	elif anchor & 64: y -= int(fd.ascent)
	if color != Color.BLACK and not text.is_empty():
		var run: Dictionary = {"text":text,"x":x+offset.x,"y":y+offset.y,"clip":clip,"bounds":Rect2i(x+offset.x,y+offset.y,w,int(fd.height)).intersection(clip)}
		if clip.intersects(Rect2i(x+offset.x,y+offset.y,w,int(fd.height))):
			var replaced: bool = false
			for n: int in text_runs.size():
				if text_runs[n].x==run.x and text_runs[n].y==run.y:
					text_runs[n]=run; replaced=true; break
			if not replaced: text_runs.append(run)
	for ch: String in text:
		blit(glyph(ch,font_bold),x,y,20,false)
		x += width(ch,font_bold)

func transcript() -> String:
	var rows: Dictionary = {}
	for run: Dictionary in text_runs:
		var row: String = str(run.y)
		if not rows.has(row): rows[row] = []
		if not run.text in rows[row]: rows[row].append(run.text)
	var keys: Array = rows.keys()
	keys.sort_custom(func(a: String,b: String) -> bool: return int(a)<int(b))
	var result: PackedStringArray = []
	for key: String in keys: result.append(" ".join(rows[key]))
	return "\n".join(result)
