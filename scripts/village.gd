class_name PlainsVillage
extends Node3D

const CENTER := Vector3(-25,2,-24)
var art: ExplorerArt
var state: ExpeditionProgress
var actors: Array[Node3D]=[]
var crops: Dictionary={}
var workbenches: Array[Vector3]=[]
var actor_time:=0.0

func setup(library: ExplorerArt,progress: ExpeditionProgress) -> void:
	art=library
	state=progress
	house(Vector3(-34,2,-32),"旅人小屋",true)
	house(Vector3(-22,2,-36),"制图师之家",false)
	house(Vector3(-36,2,-20),"农夫的家",false)
	# The reference village has paths, a central well and yellow-white market awnings.
	for p in [Vector3(-29,2.025,-24),Vector3(-25,2.025,-29),Vector3(-20,2.025,-23)]:
		art.box(self,p,Vector3(5.5,0.05,3.5),art.materials.sand)
	for x in [-1,0,1]:
		for z in [-1,0,1]:
			if x==0 and z==0: continue
			art.box(self,CENTER+Vector3(x,0.45,z),Vector3(1,0.9,1),art.materials.stone,true)
	art.box(self,CENTER+Vector3(0,0.65,0),Vector3(1,0.08,1),art.color_mat(Color("479ba8")))
	for x in [-1.25,1.25]:
		for z in [-1.25,1.25]:art.box(self,CENTER+Vector3(x,1.5,z),Vector3(0.16,3,0.16),art.materials.plank)
	art.box(self,CENTER+Vector3(0,3.05,0),Vector3(3.3,0.2,3.3),art.materials.roof)
	market(Vector3(-19,2,-17))
	market(Vector3(-29,2,-15))
	# Stone tower visible from the trail; surrounding battlements reference p.26.
	for x in range(4):
		for z in range(4):
			if x in [0,3] or z in [0,3]:
				var h:=6.0 if (x+z)%2==0 else 5.5
				art.box(self,Vector3(-37+x,2+h/2,-38+z),Vector3(1,h,1),art.materials.stone,true)
	art.torch(self,Vector3(-35.5,8,-36.5))
	var farmer:=art.villager(self,Vector3(-19,2,-16.5),"farmer")
	var farmer_label:=art.label(farmer,"农夫\nE  交谈与交易",Vector3(0,2.7,0))
	farmer_label.pixel_size=0.004
	actors.append(farmer)
	var cartographer:=art.villager(self,Vector3(-19.5,2,-28.8),"cartographer")
	var cartographer_label:=art.label(cartographer,"制图师\nE  购买地图",Vector3(0,2.7,0))
	cartographer_label.pixel_size=0.004
	actors.append(cartographer)
	art.cartography_table(self,Vector3(-17.8,2,-28.8))
	art.label(self,"平原村庄",Vector3(-25,8,-29))
	art.label(self,"村庄 ↖",Vector3(-8,3.5,-12))
	art.label(self,"营地 ↘",Vector3(-14,3.5,-16))
	for p in [Vector3(-8,2,-12),Vector3(-14,2,-16)]:
		art.box(self,p+Vector3(0,0.5,0),Vector3(0.14,1,0.14),art.materials.plank)
		art.torch(self,p+Vector3(0,1,0))
	farm()

func house(pos: Vector3,title: String,has_bed: bool) -> void:
	var node:=Node3D.new()
	add_child(node)
	node.position=pos
	art.box(node,Vector3(2,0.04,2),Vector3(5,0.08,5),art.materials.plank)
	for x in range(5):
		for z in range(5):
			if x not in [0,4] and z not in [0,4]:continue
			for y in range(3):
				if z==4 and x==2 and y<2: continue
				if y==1 and ((x in [0,4] and z==2) or (z==0 and x==2)):
					art.box(node,Vector3(x,y+0.5,z),Vector3(0.95,0.95,0.95),art.color_mat(Color(0.65,0.8,0.78,0.25)))
					continue
				var mat: Material=art.materials.log if x in [0,4] and z in [0,4] else (art.materials.stone if y==0 else art.materials.plank)
				art.box(node,Vector3(x,y+0.5,z),Vector3.ONE,mat,true)
	for layer in range(4):
		art.box(node,Vector3(2,3.0+layer*0.5,2),Vector3(6.4-layer*1.5,0.5,6),art.materials.roof)
	art.torch(node,Vector3(0.9,1.5,4.55))
	art.torch(node,Vector3(3.1,1.5,4.55))
	art.label(node,title,Vector3(2,3.3,4.75))
	if has_bed: art.bed(node,Vector3(3,0,1.4),"village")
	else:
		var bench:=art.bench(node,Vector3(1,0,1))
		art.mark(bench,"workbench")
		workbenches.append(pos+Vector3(1,0,1))

func market(pos: Vector3) -> void:
	for x in [-1.2,1.2]:
		for z in [-0.8,0.8]:art.box(self,pos+Vector3(x,1.3,z),Vector3(0.13,2.6,0.13),art.materials.plank)
	for i in range(4):
		art.box(self,pos+Vector3(-1.2+i*0.8,2.65,0),Vector3(0.8,0.15,2.3),art.materials.wool if i%2 else art.materials.cloth)
	art.box(self,pos+Vector3(0,0.75,-0.55),Vector3(2.5,0.15,0.5),art.materials.plank)

func farm() -> void:
	var origin:=Vector3(-16,2,-23)
	art.box(self,origin+Vector3(2,0.07,2),Vector3(6,0.14,6),art.materials.log_top)
	art.box(self,origin+Vector3(2,0.16,2),Vector3(5,0.18,5),art.materials.soil)
	art.box(self,origin+Vector3(2,0.26,2),Vector3(0.55,0.03,5),art.color_mat(Color("318faa")))
	for i in range(16):
		var node:=Node3D.new()
		add_child(node)
		node.position=origin+Vector3([0.3,1.1,2.9,3.7][i%4],0.25,(i/4)*1.05+0.3)
		var id:="wheat_%d"%i
		for x in [-0.18,0.0,0.18]:
			art.box(node,Vector3(x,0.35,0),Vector3(0.045,0.7,0.045),art.color_mat(Color("948b3e")))
			art.box(node,Vector3(x,0.67,0),Vector3(0.13,0.3,0.1),art.color_mat(Color("d6b54f")))
		var body:=StaticBody3D.new()
		var shape:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(0.65,0.8,0.65)
		shape.shape=box
		shape.position.y=0.4
		body.add_child(shape)
		body.collision_layer=2
		node.add_child(body)
		art.mark(node,"crop",id)
		crops[id]=node
	var crop_label:=art.label(self,"成熟小麦\n对准麦穗按 E 收获",origin+Vector3(2,2,2))
	crop_label.pixel_size=0.004

func _process(delta: float) -> void:
	actor_time+=delta
	for i in actors.size():
		actors[i].rotation.y=sin(actor_time*0.35+i)*0.18
	if state==null:return
	for id in crops:
		var ready:=float(state.journey.time)-float(state.journey.crops.get(id,-1000))>=90
		crops[id].visible=ready
		crops[id].get_child(crops[id].get_child_count()-1).collision_layer=2 if ready else 0
