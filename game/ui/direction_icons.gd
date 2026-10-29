class_name WolfDirectionIcons
extends RefCounted
## Explicit assets keep navigation legible without OS font fallback in Web.
static func apply(button: Button) -> void:
	var icons: Dictionary={"←":"left","→":"right","↑":"up","↓":"down","●":"action"}
	for glyph: String in icons:
		if not button.text.contains(glyph):continue
		button.icon=load("res://assets/ui/%s.svg"%icons[glyph])
		button.text=button.text.replace(glyph,"").strip_edges()
		button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER if button.text.is_empty() else HORIZONTAL_ALIGNMENT_RIGHT
		return
