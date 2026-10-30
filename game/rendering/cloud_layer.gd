class_name WolfCloudLayer
extends Node2D
## Original cloud artwork, animated independently of the turn clock.
var clouds: Array[Dictionary]=[]
var pixel_scale: float=1.0
var animating: bool=true
var elapsed: float=0.0
var facing: int=-1

func synchronize(next_clouds: Array[Dictionary],scale_factor: float,direction: int) -> void:
	var previous: Dictionary={}
	if facing==direction and is_equal_approx(pixel_scale,scale_factor):
		for cloud: Dictionary in clouds:
			var key: String=str(cloud.anchor)+str(cloud.clip)
			if not previous.has(key):previous[key]=[]
			previous[key].append(cloud)
	for cloud: Dictionary in next_clouds:
		var key: String=str(cloud.anchor)+str(cloud.clip)
		var old: Array=previous.get(key,[])
		cloud.current=old.pop_front().current if not old.is_empty() else cloud.rect
	clouds=next_clouds;pixel_scale=scale_factor;facing=direction
	queue_redraw()

func _ready() -> void:
	# Subpixel filtering lets the existing pixel artwork drift without snapping.
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	if not visible or not animating or clouds.is_empty():return
	var step: float=minf(delta,0.1)
	elapsed+=step
	for cloud: Dictionary in clouds:
		var current: Rect2=cloud.current;var target: Rect2=cloud.rect
		var blend: float=1.0-exp(-step*3.0)
		cloud.current=Rect2(current.position.lerp(target.position,blend),current.size.lerp(target.size,blend))
	queue_redraw()

func _draw() -> void:
	for cloud: Dictionary in clouds:
		var original: Rect2=cloud.current
		var clip: Rect2=cloud.clip
		var speed: float=(0.10+float(cloud.depth)*0.025)*pixel_scale
		var span: float=clip.size.x+original.size.x*2.0
		if span<=0:continue
		var x: float=clip.position.x+fposmod(original.position.x-clip.position.x+original.size.x-elapsed*speed,span)-original.size.x
		var moving: Rect2=Rect2(Vector2(x,original.position.y),original.size)
		var visible_rect: Rect2=moving.intersection(clip)
		if not visible_rect.has_area():continue
		var texels: Vector2=Vector2(cloud.texture.get_size())/moving.size
		var source: Rect2=Rect2((visible_rect.position-moving.position)*texels,visible_rect.size*texels)
		draw_texture_rect_region(cloud.texture,visible_rect,source)
