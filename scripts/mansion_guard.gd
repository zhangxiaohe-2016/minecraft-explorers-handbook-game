class_name MansionGuard
extends CharacterBody3D

var expedition: Node3D
var guard_id: String
var caster:=false
var health:=3
var home_position: Vector3
var patrol_sign:=1.0
var cooldown:=1.0
var windup:=0.0
var attack_point:=Vector3.ZERO
var marker: MeshInstance3D
var model: Node3D
var arm: Node3D
var status: Label3D

func setup(owner_node: Node3D, id: String, local_pos: Vector3, magic: bool) -> void:
	expedition=owner_node
	guard_id=id
	caster=magic
	position=local_pos
	home_position=position
	set_meta("mansion_enemy",true)
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.34
	capsule.height=1.9
	shape.shape=capsule
	shape.position.y=0.95
	add_child(shape)
	model=Node3D.new()
	add_child(model)
	var art: ExplorerArt=expedition.game.art
	var skin:=art.color_mat(Color("959f99"))
	var robe:=art.color_mat(Color("263439") if caster else Color("55504b"))
	var black:=art.color_mat(Color("273236"))
	for x in [-0.17,0.17]:art.box(model,Vector3(x,0.25,0),Vector3(0.25,0.5,0.3),black)
	art.box(model,Vector3(0,1,0),Vector3(0.66,1.2,0.43),robe)
	art.box(model,Vector3(0,1.83,0),Vector3(0.62,0.65,0.53),skin)
	art.box(model,Vector3(0,1.62,0.38),Vector3(0.15,0.38,0.24),skin)
	for x in [-0.17,0.17]:
		art.box(model,Vector3(x,1.83,0.272),Vector3(0.13,0.08,0.025),art.color_mat(Color("426e62")))
		art.box(model,Vector3(x,1.94,0.28),Vector3(0.24,0.09,0.025),black)
	if caster:art.box(model,Vector3(0,1,0.23),Vector3(0.11,1.05,0.025),art.color_mat(Color("d2b565")))
	arm=Node3D.new()
	model.add_child(arm)
	arm.position=Vector3(0.46,1.45,0)
	art.box(arm,Vector3(0,-0.32,0),Vector3(0.22,0.7,0.24),robe)
	art.box(arm,Vector3(0,-0.7,0),Vector3(0.22,0.2,0.24),skin)
	if not caster:
		art.box(arm,Vector3(0,-0.55,0.4),Vector3(0.09,0.09,0.8),art.materials.log)
		art.box(arm,Vector3(0,-0.55,0.76),Vector3(0.42,0.38,0.12),art.materials.stone)
	status=art.label(self,"唤魔者" if caster else "卫道士",Vector3(0,2.65,0),Color("f1bd83"))
	status.pixel_size=0.0035
	marker=art.box(expedition,Vector3.ZERO,Vector3(2.2,0.025,2.2),art.color_mat(Color("df5a36"),true))
	marker.visible=false

func line_of_sight() -> bool:
	var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1.4,0),expedition.game.player.global_position+Vector3(0,1.2,0))
	query.exclude=[get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==expedition.game.player

func _physics_process(delta: float) -> void:
	if expedition==null:return
	if not expedition.game.player.active or not expedition.state.has_flag("mansion_started"):
		return
	var player: ExplorerPlayer=expedition.game.player
	var distance:=global_position.distance_to(player.global_position)
	var sees:=distance<10 and absf(global_position.y-player.global_position.y)<1.5 and line_of_sight()
	cooldown=maxf(0,cooldown-delta)
	if windup>0:
		windup-=delta
		arm.rotation.x=-2.0
		if windup<=0:
			if caster:
				expedition.show_fangs(attack_point)
				if Vector2(player.global_position.x-attack_point.x,player.global_position.z-attack_point.z).length()<1.25 and absf(player.global_position.y-attack_point.y)<1.5 and line_of_sight():
					expedition.hurt(3)
			else:
				if distance<2.3 and sees:expedition.hurt(2)
			marker.hide()
			cooldown=2.0
		return
	arm.rotation.x=0
	if sees:
		model.rotation.y=atan2(player.global_position.x-global_position.x,player.global_position.z-global_position.z)
		status.text="唤魔者 · 远离红色地面" if caster else "卫道士 · 抬斧时后退"
		if cooldown<=0 and distance<(8.5 if caster else 2.1):
			windup=1.2 if caster else 0.9
			attack_point=player.global_position
			if caster:
				marker.global_position=attack_point+Vector3(0,0.04,0)
				marker.show()
			expedition.game.tone(110,0.15,0.08)
			return
	else:status.text="唤魔者" if caster else "卫道士"
	velocity=Vector3.ZERO
	if not caster:
		if sees and distance>1.7:
			var direction: Vector3=(player.global_position-global_position).normalized()
			velocity=Vector3(direction.x,0,direction.z)*1.8
		elif not sees:
			if position.z>home_position.z+3:patrol_sign=-1
			if position.z<home_position.z-3:patrol_sign=1
			velocity.z=patrol_sign*0.9
		velocity.y=-5
		move_and_slide()

func strike() -> void:
	health-=1
	expedition.game.tone(180,0.07,0.1)
	if health<=0:
		expedition.state.flags["defeated_"+guard_id]=true
		expedition.state.save_game()
		marker.queue_free()
		expedition.game.hud.toast("已击退"+("唤魔者。" if caster else "卫道士。"))
		queue_free()
	else:
		windup=0
		marker.hide()
		cooldown=1.1
		expedition.game.hud.toast("命中守卫，剩余 %d 次命中可击退。"%health)
