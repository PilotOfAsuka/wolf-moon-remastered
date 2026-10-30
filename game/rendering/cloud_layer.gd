class_name WolfCloudLayer
extends Node2D
## Original cloud artwork, animated independently of the turn clock.
var clouds: Array[Dictionary]=[]
var pixel_scale: float=1.0
var animating: bool=true
var elapsed: float=0.0
var last_tick: int=0
var lighting: WolfLightPalette

func synchronize(next_clouds: Array[Dictionary],scale_factor: float) -> void:
	# Camera changes use the new scene immediately. No post-step interpolation.
	# Keep the independent drift clock running across background repaints.
	clouds=next_clouds;pixel_scale=scale_factor
	queue_redraw()

func _ready() -> void:
	# Subpixel filtering lets the existing pixel artwork drift without snapping.
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

func _process(_delta: float) -> void:
	var now: int=Time.get_ticks_usec()
	var step: float=float(now-last_tick)/1000000.0 if last_tick>0 else 0.0
	last_tick=now
	if not visible or not animating or clouds.is_empty():return
	# Wall time, independent of input, turn progression and scene revisions.
	elapsed+=step
	queue_redraw()

func _draw() -> void:
	for cloud: Dictionary in clouds:
		var original: Rect2=cloud.rect
		var clip: Rect2=cloud.clip
		var speed: float=(0.45+float(cloud.depth)*0.06)*pixel_scale
		var span: float=clip.size.x+original.size.x
		if span<=0:continue
		var x: float=clip.position.x+fposmod(original.position.x-clip.position.x+original.size.x-elapsed*speed,span)-original.size.x
		var moving: Rect2=Rect2(Vector2(x,original.position.y),original.size)
		var visible_rect: Rect2=moving.intersection(clip)
		if not visible_rect.has_area():continue
		var texels: Vector2=Vector2(cloud.texture.get_size())/moving.size
		var source: Rect2=Rect2((visible_rect.position-moving.position)*texels,visible_rect.size*texels)
		if lighting!=null:
			draw_texture_rect_region(cloud.day_texture,visible_rect,source)
			if lighting.cloud_night>0.001:draw_texture_rect_region(cloud.night_texture,visible_rect,source,Color(1,1,1,lighting.cloud_night))
		else:draw_texture_rect_region(cloud.texture,visible_rect,source)
