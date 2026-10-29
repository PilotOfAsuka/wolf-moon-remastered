class_name WolfSceneLayer
extends Node2D
var plan: Array[Dictionary]=[]
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
func _draw() -> void:
	for item: Dictionary in plan:
		match item.kind:
			"texture":draw_texture_rect_region(item.texture,item.rect,item.source,Color.WHITE,false,false)
			"rect":draw_rect(item.rect,item.color)
			"line":draw_line(item.a,item.b,item.color,item.width,false)
			"polygon":draw_colored_polygon(item.points,item.color)
			"polyline":draw_polyline(item.points,item.color,item.width,false)
