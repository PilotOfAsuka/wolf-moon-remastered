class_name WolfLightPalette
extends RefCounted
## Presentation-only interpolation of the original environmental palette.
const DURATION: float=1.15
var current: Array[Color]=[]
var target: Array[Color]=[]
var origin: Array[Color]=[]
var foliage: Vector3=Vector3.ZERO
var foliage_target: Vector3=Vector3.ZERO
var foliage_origin: Vector3=Vector3.ZERO
var cloud_night: float=0.0
var cloud_target: float=0.0
var cloud_origin: float=0.0
var progress: float=1.0

static func column(hour: int) -> int:
	match hour:
		5:return 2
		6:return 3
		7:return 4
		17:return 5
		18:return 6
		19:return 7
	return 1 if hour>7 and hour<17 else 0

func synchronize(state: Dictionary,delta: float) -> bool:
	var next_palette: Array=state.get("light_palette",[])
	if next_palette.size()!=12:return false
	var hour: int=int(state.get("hour",12))
	var next_foliage: Vector3=Vector3(0,0,1) if hour>=20 or hour<=4 else (Vector3(1,0,0) if hour>=8 and hour<=16 else Vector3(0,1,0))
	var next_cloud: float=1.0 if hour>=19 or hour<=4 else 0.0
	if current.is_empty():
		current.assign(next_palette);target.assign(next_palette);origin.assign(next_palette)
		foliage=next_foliage;foliage_target=next_foliage;cloud_night=next_cloud;cloud_target=next_cloud
		return true
	if target!=next_palette or foliage_target!=next_foliage or cloud_target!=next_cloud:
		origin=current.duplicate();target.assign(next_palette)
		foliage_origin=foliage;foliage_target=next_foliage
		cloud_origin=cloud_night;cloud_target=next_cloud;progress=0.0
	if progress>=1.0:return false
	progress=minf(1.0,progress+delta/DURATION)
	var blend: float=progress*progress*(3.0-2.0*progress)
	for index: int in 12:current[index]=origin[index].lerp(target[index],blend)
	foliage=foliage_origin.lerp(foliage_target,blend)
	cloud_night=lerpf(cloud_origin,cloud_target,blend)
	if progress>=1.0:
		current=target.duplicate();foliage=foliage_target;cloud_night=cloud_target
	return true

func color_for(item: Dictionary) -> Color:
	var native: Color=item.color
	if current.size()!=12 or not item.has("lighting"):return native
	var hint: Dictionary=item.lighting
	var shift_from: Color=current[int(hint.from)]-Color(hint.source_from)
	var shift_to: Color=current[int(hint.to)]-Color(hint.source_to)
	var shift: Color=shift_from.lerp(shift_to,float(hint.amount))
	return Color(clampf(native.r+shift.r,0,1),clampf(native.g+shift.g,0,1),clampf(native.b+shift.b,0,1),native.a)
