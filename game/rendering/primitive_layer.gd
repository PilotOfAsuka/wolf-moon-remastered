class_name WolfPrimitiveLayer
extends Node2D
## Replays the original painter's primitives at the current display resolution.
var commands: Array[Dictionary]=[]
var projection: Vector2=Vector2.ONE
var origin: Vector2=Vector2.ZERO
var image_cache: Dictionary={}

func project(p: Vector2) -> Vector2:return p*projection+origin

func _draw() -> void:
	for cmd: Dictionary in commands:
		var clip: Rect2=Rect2(cmd.clip).intersection(Rect2(0,0,240,281))
		if not clip.has_area():continue
		var color: Color=cmd.color
		match cmd.kind:
			"rect":
				var r: Rect2=Rect2(cmd.rect).intersection(clip)
				if r.has_area():draw_rect(Rect2(project(r.position),r.size*projection),color)
			"line":
				var a: Vector2=cmd.a;var b: Vector2=cmd.b
				# Liang-Barsky clipping in original logical coordinates.
				var d: Vector2=b-a;var lo: float=0;var hi: float=1;var valid: bool=true
				var ps: Array[float]=[-d.x,d.x,-d.y,d.y]
				var qs: Array[float]=[a.x-clip.position.x,clip.end.x-a.x,a.y-clip.position.y,clip.end.y-a.y]
				for n: int in 4:
					if is_zero_approx(ps[n]):
						if qs[n]<0:valid=false
					else:
						var t: float=qs[n]/ps[n]
						if ps[n]<0:lo=maxf(lo,t)
						else:hi=minf(hi,t)
				if valid and lo<=hi:draw_line(project(a+d*lo),project(a+d*hi),color,maxf(1,projection.y),false)
			"arc":
				var args: Array=cmd.args
				var center: Vector2=Vector2(float(args[0])+float(args[2])*0.5,float(args[1])+float(args[3])*0.5)+Vector2(cmd.offset)
				var points: PackedVector2Array=[]
				if cmd.filled:points.append(project(center))
				for n: int in 49:
					var angle: float=deg_to_rad(float(args[4])+float(args[5])*float(n)/48.0)
					points.append(project(center+Vector2(cos(angle)*float(args[2])*0.5,-sin(angle)*float(args[3])*0.5)))
				if cmd.filled and points.size()>=3:draw_colored_polygon(points,color)
				elif points.size()>1:draw_polyline(points,color,maxf(1,projection.y),true)
			"image":
				var image: Image=cmd.image
				var id: int=image.get_instance_id()
				if not image_cache.has(id):image_cache[id]=ImageTexture.create_from_image(image)
				var rect: Rect2=Rect2(cmd.rect);var visible: Rect2=rect.intersection(clip)
				if visible.has_area():draw_texture_rect_region(image_cache[id],Rect2(project(visible.position),visible.size*projection),Rect2(visible.position-rect.position,visible.size))
