class_name ExplorerPlayer
extends CharacterBody3D

var camera: Camera3D
var hand: Node3D
var active := false
var sprint_allowed := true
var sensitivity := 0.0023
var walked := 0.0
var swing := 0.0
var held_id := ""

func _ready() -> void:
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	body.shape = capsule
	body.position.y = 0.9
	add_child(body)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.62, 0)
	camera.fov = 76
	camera.near = 0.05
	camera.far = 240.0
	add_child(camera)
	hand = Node3D.new()
	camera.add_child(hand)
	hand.position = Vector3(0.48, -0.43, -0.84)
	floor_snap_length = 0.35

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	if active:
		var input := Input.get_vector("left", "right", "forward", "back")
		var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
		var speed := 6.8 if Input.is_action_pressed("sprint") and sprint_allowed else 4.3
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = 7.0
		walked += Vector2(velocity.x, velocity.z).length() * delta
	else:
		velocity.x = 0
		velocity.z = 0
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
	swing = maxf(0.0, swing - delta * 4.0)
	hand.rotation = Vector3(-0.25 - sin(swing * PI) * 0.8, -0.3, -0.3 - sin(swing * PI) * 0.5)
	hand.position.y = -0.43 + (sin(walked * 3.0) * 0.014 if active else 0.0)

func hold(id: String) -> void:
	if held_id == id: return
	held_id = id
	for child in hand.get_children():
		child.queue_free()
	var path := "res://assets/models/" + id + ".glb"
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		hand.add_child(model)
		model.scale = Vector3.ONE * 0.55

func ray() -> Dictionary:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 5.5)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)
