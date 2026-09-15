class_name ExplorationMap
extends Control

var world: ExplorerWorld
var state: ExpeditionProgress
var player: ExplorerPlayer
var game: Node3D

func toggle_waypoint(pixel: Vector2) -> Dictionary:
	if state.count("map")==0 or not Rect2(0,0,480,480).has_point(pixel):
		return {"ok":false,"reason":"outside"}
	var cell:=Vector2i(floori(pixel.x/20),floori(pixel.y/20))
	var key:=str(cell.x)+","+str(cell.y)
	if key not in state.journey.explored:
		return {"ok":false,"reason":"unexplored"}
	if key in state.journey.waypoints:
		state.journey.waypoints.erase(key)
		state.save_game()
		queue_redraw()
		return {"ok":true,"removed":true}
	if state.journey.waypoints.size()>=12:
		return {"ok":false,"reason":"full"}
	state.journey.waypoints.append(key)
	state.save_game()
	queue_redraw()
	return {"ok":true,"removed":false}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var result:=toggle_waypoint(event.position)
		if game!=null and not result.ok:
			match result.reason:
				"unexplored":game.hud.toast("只能在已探索的格子上放置旗标。先走过附近区域。")
				"full":game.hud.toast("旗标已满 12 个。先点掉一个，再放置新的。")
		accept_event()

func _draw() -> void:
	if world==null:return
	var tile:=20.0
	draw_rect(Rect2(-12,-12,504,504),Color("9d7948"))
	draw_rect(Rect2(-7,-7,494,494),Color("e9d9ac"))
	for x in range(24):
		for z in range(24):
			var p:=Vector2(x*tile,z*tile)
			var known: bool=str(x)+","+str(z) in state.journey.explored
			var color:=Color("c9b990")
			if known:
				var wx:=x*4-46
				var wz:=z*4-46
				color=Color("78935b") if world.height_at(wx,wz)<6 else Color("66765b")
				if absf(wx-world.river_x(wz))<5:color=Color("488995")
				if world.village_area(wx,wz):color=Color("9baf69")
				if world.mansion_area(wx,wz):color=Color("563f32")
				if world.forest_area(wx,wz):color=Color("4c6545") if wz>22 else (Color("94ae71") if wz>10 else Color("adba72"))
				if world.journey_road(wx,wz):color=Color("d5bd85")
				for house in [Vector2(-34,-32),Vector2(-22,-36),Vector2(-36,-20)]:
					if Rect2(house-Vector2(0.5,0.5),Vector2(5,5)).has_point(Vector2(wx,wz)):color=Color("8c653f")
				if abs(wx+25)<2 and abs(wz+24)<2:color=Color("488995")
			draw_rect(Rect2(p,Vector2(tile,tile)),color)
	var camp:=Vector2(44,49)*5
	for key in state.journey.waypoints:
		var parts: PackedStringArray=str(key).split(",")
		if parts.size()!=2:continue
		var p:=Vector2(int(parts[0])*20+10,int(parts[1])*20+10)
		draw_line(p-Vector2(0,7),p+Vector2(0,7),Color("b84185"),3)
		draw_colored_polygon(PackedVector2Array([p-Vector2(0,7),p+Vector2(9,-3),p]),Color("b84185"))
	draw_rect(Rect2(camp-Vector2(5,5),Vector2(10,10)),Color("f3d279"))
	if state.has_flag("village_found"):
		var village:=Vector2(23,24)*5
		draw_circle(village,7,Color("efe4c6"))
	var location:=Vector2(player.position.x+48,player.position.z+48)*5
	if state.has_flag("temperate_landmark"):
		draw_rect(Rect2(Vector2(16,44)*5-Vector2(4,4),Vector2(8,8)),Color("b78449"))
	for entry in [["flower",4],["birch",16],["dark",28]]:
		if state.has_flag("forest_"+entry[0]):draw_circle(Vector2(18,48+entry[1])*5,4,Color("b8e68b"))
	var direction:=Vector2(-sin(player.rotation.y),-cos(player.rotation.y))
	var side:=Vector2(-direction.y,direction.x)
	draw_colored_polygon(PackedVector2Array([location+direction*10,location-direction*6+side*5,location-direction*6-side*5]),Color("a94031"))

func _process(_delta: float) -> void:
	queue_redraw()
