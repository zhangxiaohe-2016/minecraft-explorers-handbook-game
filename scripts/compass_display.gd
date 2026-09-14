class_name CompassDisplay
extends Control

const WORLD_SPAWN := Vector3(-0.5, 2.15, 12)
var player: ExplorerPlayer
var state: ExpeditionProgress
var caption: Label

static func direction_at(pos: Vector3, yaw: float) -> Vector2:
	var offset := Vector2(WORLD_SPAWN.x-pos.x, WORLD_SPAWN.z-pos.z)
	return offset.rotated(yaw).normalized()

func _process(_delta: float) -> void:
	visible = state.count("compass") > 0
	if visible:
		var distance := Vector2(player.position.x-WORLD_SPAWN.x,player.position.z-WORLD_SPAWN.z).length()
		caption.text = "已到世界出生点" if distance<1.5 else "红针 → 世界出生点\n距离 %d 米 · C 使用说明" % int(distance)
		queue_redraw()

func _draw() -> void:
	# Stepped grey rim, charcoal face and red needle follow printed page 18.
	var widths := [4,8,10,12,12,12,12,12,12,10,8,4]
	for row in range(12):
		var width: int = widths[row]
		draw_rect(Rect2(60-width*5, row*10, width*10,10),Color("92999b"))
		if row>0 and row<11:
			draw_rect(Rect2(70-width*5,row*10,(width-2)*10,10),Color("292e32"))
	var direction := direction_at(player.position,player.rotation.y)
	var center := Vector2(60,60)
	var side := Vector2(-direction.y,direction.x)
	draw_colored_polygon(PackedVector2Array([center+direction*43,center+side*7,center-side*7]),Color("ed3d3d"))
	draw_colored_polygon(PackedVector2Array([center-direction*30,center+side*7,center-side*7]),Color("b7bdbe"))
	draw_rect(Rect2(56,56,8,8),Color("666b70"))
