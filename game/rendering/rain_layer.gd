class_name WolfRainLayer
extends Node2D
## Visual rain only. Original weather, time, RNG and saves stay in the game core.
var view_size: Vector2=Vector2.ZERO
var pixel_scale: float=1.0
var strength: float=0.0
var target_strength: float=0.0
var wind: float=0.0
var target_wind: float=0.0
var night: bool=false
var animating: bool=true
var elapsed: float=0.0

func configure(state: Dictionary,dimensions: Vector2,scale_factor: float) -> void:
	view_size=dimensions;pixel_scale=scale_factor
	var exposed: bool=state.get("weather_exposed",false)
	visible=exposed and not state.get("full_map",false)
	animating=state.get("screen","") in ["i","b"]
	target_strength=float(state.get("rain_strength",0.0)) if exposed else 0.0
	target_wind=float(state.get("rain_wind",0.0))*0.22
	var hour: int=int(state.get("hour",12));night=hour>=19 or hour<=4
	if not exposed and strength>0.0:
		strength=0.0
		queue_redraw()

func _process(delta: float) -> void:
	if not visible or not animating:return
	var step: float=minf(delta,0.1)
	if strength<=0.001 and target_strength<=0.001:return
	elapsed+=step
	strength=move_toward(strength,target_strength,step*0.8)
	wind=lerpf(wind,target_wind,1.0-exp(-step*2.0))
	queue_redraw()

static func seed_value(index: int,salt: int) -> float:
	# Independent deterministic visual seeds never consume the original RNG.
	var value: int=((index*73856093)^(salt*19349663))&0x7fffffff
	value=((value^(value>>13))*1274126177)&0x7fffffff
	return float(value^(value>>16))/2147483647.0

func _draw() -> void:
	if strength<=0.001 or view_size.x<=0 or view_size.y<=0:return
	var per_layer: int=clampi(int(view_size.x/18.0),20,120)
	var tint: Color=Color(0.43,0.55,0.69) if night else Color(0.72,0.80,0.86)
	for layer: int in 3:
		var tails: PackedVector2Array=[];var bodies: PackedVector2Array=[];var heads: PackedVector2Array=[]
		var alpha: float=(0.13+layer*0.085)*strength
		var width: float=maxf(0.65,pixel_scale*(0.18+layer*0.1))
		for drop: int in per_layer:
			var index: int=drop+layer*131
			var fraction: float=seed_value(index,7)
			var speed: float=(125.0+layer*100.0+fraction*65.0)*pixel_scale
			var length: float=(2.5+layer*2.0+fraction*3.5)*pixel_scale
			var y: float=fposmod(seed_value(index,17)*(view_size.y+length*2)+elapsed*speed,view_size.y+length*2)-length
			var margin: float=length+absf(wind)*view_size.y
			var x: float=fposmod(seed_value(index,31)*(view_size.x+margin*2)+wind*y,view_size.x+margin*2)-margin
			var head: Vector2=Vector2(x,y);var streak: Vector2=Vector2(wind*length,length)
			tails.append_array(PackedVector2Array([head-streak,head-streak*0.65]))
			bodies.append_array(PackedVector2Array([head-streak*0.65,head-streak*0.25]))
			heads.append_array(PackedVector2Array([head-streak*0.25,head]))
		draw_multiline(tails,Color(tint,alpha*0.3),width,true)
		draw_multiline(bodies,Color(tint,alpha*0.65),width,true)
		draw_multiline(heads,Color(tint,alpha),width,true)
