class_name World
extends RefCounted
## Builds the scenery in code: a meadow with a sunken pond, trees, rocks, flowers, reeds and lotus.

const POND_R := 7.0
const WATER_Y := 0.34
const GROUND_Y := 0.5

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform vec4 shallow : source_color = vec4(0.42, 0.80, 0.74, 0.62);
uniform vec4 deep : source_color = vec4(0.07, 0.38, 0.46, 0.86);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = length(wpos.xz) / 7.0;
	float w = sin(wpos.x * 2.2 + TIME * 1.3) * cos(wpos.z * 2.6 - TIME * 1.1);
	float w2 = sin((wpos.x + wpos.z) * 4.0 + TIME * 2.0);
	vec4 c = mix(deep, shallow, smoothstep(0.5, 1.0, d));
	float sparkle = smoothstep(0.78, 1.0, w * 0.6 + w2 * 0.4);
	ALBEDO = c.rgb + sparkle * 0.2;
	ALPHA = c.a;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
}
"""

static func mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

## The pond is a wobbly circle: its radius at an angle.
static func pond_radius(angle: float) -> float:
	return POND_R * (1.0 + 0.08 * sin(angle * 3.0) + 0.05 * cos(angle * 5.0 + 1.0))

static func in_pond(p: Vector3, margin: float = 0.0) -> bool:
	return Vector2(p.x, p.z).length() < pond_radius(atan2(p.z, p.x)) - margin

static func mesh_node(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi

## A cylinder between two points (limbs, rods, stems).
static func limb(a: Vector3, b: Vector3, r: float, m: Material, r_top: float = -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = a.distance_to(b)
	c.radial_segments = 8
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	return mi

static func build(root: Node3D, rng: RandomNumberGenerator) -> void:
	obstacles.clear()
	root.add_child(_ground())
	root.add_child(_bed())
	root.add_child(_water())
	_trees(root, rng)
	_rocks(root, rng)
	_flowers(root, rng)
	_reeds(root, rng)
	_lotus(root, rng)

static func _ground() -> MeshInstance3D:
	# Rings from the pond bed up the bank and out across the meadow, coloured per ring.
	var rings := [
		[-1.3, -0.45, Color(0.36, 0.33, 0.24)],
		[-0.25, 0.26, Color(0.80, 0.70, 0.48)],
		[0.45, GROUND_Y, Color(0.52, 0.72, 0.30)],
		[5.0, GROUND_Y, Color(0.38, 0.64, 0.26)],
		[70.0, GROUND_Y, Color(0.28, 0.52, 0.22)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 72
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for j in rings.size() - 1:
			var quad := [[a0, j], [a1, j], [a0, j + 1], [a1, j], [a1, j + 1], [a0, j + 1]]
			for v in quad:
				var ang: float = v[0]
				var ring: Array = rings[v[1]]
				var r: float = pond_radius(ang) + float(ring[0])
				st.set_color(ring[2])
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(cos(ang) * r, float(ring[1]), sin(ang) * r))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mesh_node(st.commit(), m)

static func _bed() -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = POND_R
	c.bottom_radius = POND_R
	c.height = 0.05
	return mesh_node(c, mat(Color(0.20, 0.30, 0.28)), Vector3(0, -0.47, 0))

static func _water() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 72
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for v in [Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)) * (pond_radius(a0) - 0.12), Vector3(cos(a1), 0, sin(a1)) * (pond_radius(a1) - 0.12)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	return mesh_node(st.commit(), sm, Vector3(0, WATER_Y, 0))

static func _trees(root: Node3D, rng: RandomNumberGenerator) -> void:
	var trunk := mat(Color(0.42, 0.29, 0.18))
	var greens := [Color(0.16, 0.42, 0.26), Color(0.20, 0.50, 0.30), Color(0.13, 0.36, 0.24)]
	for i in 90:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(11.5, 44.0)
		var p := Vector3(cos(ang) * dist, GROUND_Y, sin(ang) * dist)
		# Keep the view from the camera (south) open.
		if (p.z > 6.0 and absf(p.x) < 9.0) or reserved(p):
			continue
		var tree := Node3D.new()
		tree.position = p
		var s := rng.randf_range(0.9, 1.7)
		tree.scale = Vector3.ONE * s
		obstacles.append(Vector3(p.x, p.z, 0.42 * s))
		tree.add_child(limb(Vector3.ZERO, Vector3(0, 1.2, 0), 0.16, trunk, 0.11))
		var leaf := mat(greens[rng.randi() % greens.size()])
		for k in 3:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.15 - k * 0.28
			cone.height = 1.5
			cone.radial_segments = 7
			tree.add_child(mesh_node(cone, leaf, Vector3(0, 1.6 + k * 0.85, 0)))
		root.add_child(tree)

static func _rocks(root: Node3D, rng: RandomNumberGenerator) -> void:
	var cols := [Color(0.78, 0.66, 0.56), Color(0.66, 0.60, 0.54), Color(0.72, 0.62, 0.50)]
	for i in 16:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(8.3, 22.0)
		var sp := SphereMesh.new()
		sp.radial_segments = 6
		sp.rings = 3
		sp.radius = 0.6
		sp.height = 1.2
		var rp := Vector3(cos(ang) * dist, GROUND_Y + 0.1, sin(ang) * dist)
		if reserved(rp):
			continue
		var rock := mesh_node(sp, mat(cols[rng.randi() % cols.size()]), rp)
		rock.scale = Vector3(rng.randf_range(0.8, 2.0), rng.randf_range(0.6, 1.4), rng.randf_range(0.8, 1.8))
		obstacles.append(Vector3(rp.x, rp.z, 0.6 * maxf(rock.scale.x, rock.scale.z)))
		rock.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
		root.add_child(rock)

static func _flowers(root: Node3D, rng: RandomNumberGenerator) -> void:
	var sp := SphereMesh.new()
	sp.radius = 0.07
	sp.height = 0.14
	sp.radial_segments = 6
	sp.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sp
	mm.instance_count = 700
	var cols := [Color(1, 1, 0.95), Color(1.0, 0.86, 0.35), Color(0.98, 0.72, 0.78), Color(1, 1, 1)]
	for i in mm.instance_count:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(8.0, 44.0)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(ang) * dist, GROUND_Y + 0.07, sin(ang) * dist)))
		mm.set_instance_color(i, cols[rng.randi() % cols.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	root.add_child(mmi)

static func _reeds(root: Node3D, rng: RandomNumberGenerator) -> void:
	var green := mat(Color(0.33, 0.52, 0.24))
	var brown := mat(Color(0.45, 0.30, 0.16))
	for i in 34:
		var ang := rng.randf() * TAU
		# Leave the bank in front of the camera and around Valluvar clear.
		if sin(ang) > 0.55 or (cos(ang) < -0.75 and absf(sin(ang)) < 0.5):
			continue
		var r := pond_radius(ang) - rng.randf_range(0.1, 0.5)
		var base := Vector3(cos(ang) * r, WATER_Y - 0.1, sin(ang) * r)
		var h := rng.randf_range(0.9, 1.6)
		var top := base + Vector3(rng.randf_range(-0.12, 0.12), h, rng.randf_range(-0.12, 0.12))
		root.add_child(limb(base, top, 0.025, green))
		root.add_child(limb(top - Vector3(0, 0.22, 0), top, 0.05, brown))

static func _lotus(root: Node3D, rng: RandomNumberGenerator) -> void:
	var pad := mat(Color(0.24, 0.52, 0.30))
	var pink := mat(Color(0.96, 0.62, 0.74))
	var heart := mat(Color(0.98, 0.84, 0.36))
	for i in 9:
		var ang := rng.randf() * TAU
		var r := pond_radius(ang) - rng.randf_range(0.9, 2.2)
		var p := Vector3(cos(ang) * r, WATER_Y + 0.015, sin(ang) * r)
		var c := CylinderMesh.new()
		c.top_radius = rng.randf_range(0.32, 0.5)
		c.bottom_radius = c.top_radius
		c.height = 0.02
		c.radial_segments = 10
		root.add_child(mesh_node(c, pad, p))
		if i % 2 == 0:
			var flower := Node3D.new()
			flower.position = p + Vector3(0.1, 0.02, 0.05)
			for k in 7:
				var petal := CylinderMesh.new()
				petal.top_radius = 0.0
				petal.bottom_radius = 0.07
				petal.height = 0.26
				petal.radial_segments = 5
				var pm := mesh_node(petal, pink)
				var pa := TAU * k / 7.0
				pm.position = Vector3(cos(pa) * 0.09, 0.1, sin(pa) * 0.09)
				pm.rotation = Vector3(sin(pa) * 0.6, 0, -cos(pa) * 0.6)
				flower.add_child(pm)
			var core := SphereMesh.new()
			core.radius = 0.05
			core.height = 0.1
			flower.add_child(mesh_node(core, heart, Vector3(0, 0.08, 0)))
			root.add_child(flower)

# ---------- the wider map: places, paths, and what is solid ----------

## Things Valluvar cannot walk through: Vector3(x, z, radius).
static var obstacles: Array[Vector3] = []

const SPAWN := Vector3(0, GROUND_Y, 13.0)
const SCHOOL := Vector3(21.0, GROUND_Y, -11.0)
const HUT := Vector3(-21.0, GROUND_Y, -13.0)

## Where Valluvar sits to fish, on the west bank.
static func seat_pos() -> Vector3:
	var ang := PI * 0.93
	var r := pond_radius(ang) + 1.0
	return Vector3(cos(ang) * r, GROUND_Y, sin(ang) * r)

## Where he stands to enter each place.
static func entries() -> Dictionary:
	var seat := seat_pos()
	return {
		"pond": seat + Vector3(-1.6, 0, 1.4),
		"school": SCHOOL + Vector3(-1.0, 0, 4.6),
		"hut": HUT + Vector3(1.2, 0, 4.2),
	}

static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (ap - ab * t).length()

## True where scenery must not grow: on a path or at a place.
static func reserved(p: Vector3) -> bool:
	var e := entries()
	for key: String in e:
		if _dist_to_segment(p, SPAWN, e[key]) < 2.4:
			return true
	if Vector2(p.x - SCHOOL.x, p.z - SCHOOL.z).length() < 8.5:
		return true
	if Vector2(p.x - HUT.x, p.z - HUT.z).length() < 7.0:
		return true
	return Vector2(p.x - SPAWN.x, p.z - SPAWN.z).length() < 4.0

static func build_places(root: Node3D, font: Font) -> void:
	var e := entries()
	var sand := mat(Color(0.82, 0.72, 0.5))
	for key: String in e:
		var a := SPAWN
		var b: Vector3 = e[key]
		var strip := BoxMesh.new()
		strip.size = Vector3(1.7, 0.02, a.distance_to(b))
		var n := mesh_node(strip, sand, (a + b) * 0.5 + Vector3(0, 0.012, 0))
		n.rotation.y = atan2(b.x - a.x, b.z - a.z)
		root.add_child(n)
	_school(root)
	_hut(root)
	root.add_child(_sign(e["pond"] + Vector3(-1.4, 0, 0.4), "குளம்", font))
	root.add_child(_sign(e["school"] + Vector3(2.2, 0, 0.6), "பள்ளி", font))
	root.add_child(_sign(e["hut"] + Vector3(-2.2, 0, 0.4), "ஏடகம்", font))

static func _sign(pos: Vector3, text: String, font: Font) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	var wood := mat(Color(0.45, 0.3, 0.17))
	n.add_child(limb(Vector3.ZERO, Vector3(0, 1.7, 0), 0.07, wood))
	var board := BoxMesh.new()
	board.size = Vector3(1.5, 0.55, 0.08)
	n.add_child(mesh_node(board, mat(Color(0.86, 0.74, 0.48)), Vector3(0, 1.75, 0)))
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 56
	l.pixel_size = 0.0058
	l.modulate = Color(0.25, 0.14, 0.05)
	l.outline_size = 0
	l.position = Vector3(0, 1.75, 0.05)
	n.add_child(l)
	obstacles.append(Vector3(pos.x, pos.z, 0.3))
	return n

## The school under the banyan tree: a stone platform, the great tree, slates for the pupils.
static func _school(root: Node3D) -> void:
	var n := Node3D.new()
	n.position = SCHOOL
	var stone := mat(Color(0.72, 0.68, 0.62))
	var plat := CylinderMesh.new()
	plat.top_radius = 4.2
	plat.bottom_radius = 4.5
	plat.height = 0.25
	plat.radial_segments = 14
	n.add_child(mesh_node(plat, stone, Vector3(0, 0.12, 0)))
	var bark := mat(Color(0.40, 0.29, 0.20))
	n.add_child(limb(Vector3(0, 0.2, -1.0), Vector3(0, 4.6, -1.0), 0.95, bark, 0.6))
	var leaf_cols := [Color(0.15, 0.40, 0.22), Color(0.19, 0.47, 0.25), Color(0.12, 0.34, 0.20)]
	var spots := [Vector3(0, 6.0, -1), Vector3(2.6, 5.3, -0.4), Vector3(-2.7, 5.4, -1.3), Vector3(0.6, 5.5, 1.6), Vector3(-0.8, 5.6, -3.4), Vector3(2.2, 6.4, -2.6), Vector3(-2.2, 6.5, 0.8)]
	for i in spots.size():
		var sp := SphereMesh.new()
		sp.radius = 2.4
		sp.height = 3.6
		sp.radial_segments = 8
		sp.rings = 4
		n.add_child(mesh_node(sp, mat(leaf_cols[i % 3]), spots[i]))
	# Aerial roots hanging from the canopy.
	for r in [Vector3(2.4, 0, 0.3), Vector3(-2.5, 0, -0.6), Vector3(1.4, 0, -3.0), Vector3(-1.2, 0, -3.3), Vector3(3.0, 0, -1.8)]:
		n.add_child(limb(r + Vector3(0, 0.25, 0), r + Vector3(0, 4.6, 0), 0.07, bark))
	# The teacher's seat and the pupils' slates.
	var seat := BoxMesh.new()
	seat.size = Vector3(1.3, 0.3, 0.9)
	n.add_child(mesh_node(seat, mat(Color(0.62, 0.17, 0.14)), Vector3(0, 0.4, 0.6)))
	for i in 5:
		var ang := PI * (0.2 + 0.15 * i)
		var slate := BoxMesh.new()
		slate.size = Vector3(0.5, 0.04, 0.36)
		var s := mesh_node(slate, mat(Color(0.16, 0.18, 0.2)), Vector3(cos(ang) * 2.7, 0.28, 0.6 + sin(ang) * 2.4))
		s.rotation.y = -ang + PI / 2
		n.add_child(s)
	root.add_child(n)
	obstacles.append(Vector3(SCHOOL.x, SCHOOL.z - 1.0, 1.5))

## The scribe's hut: mud walls, a thatched roof, and palm leaves drying on a rack.
static func _hut(root: Node3D) -> void:
	var n := Node3D.new()
	n.position = HUT
	var wall := CylinderMesh.new()
	wall.top_radius = 2.3
	wall.bottom_radius = 2.4
	wall.height = 2.1
	wall.radial_segments = 12
	n.add_child(mesh_node(wall, mat(Color(0.82, 0.62, 0.42)), Vector3(0, 1.05, 0)))
	var band := CylinderMesh.new()
	band.top_radius = 2.42
	band.bottom_radius = 2.44
	band.height = 0.5
	band.radial_segments = 12
	n.add_child(mesh_node(band, mat(Color(0.62, 0.2, 0.14)), Vector3(0, 0.25, 0)))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 3.3
	roof.height = 2.4
	roof.radial_segments = 12
	n.add_child(mesh_node(roof, mat(Color(0.78, 0.63, 0.32)), Vector3(0, 3.2, 0)))
	var door := BoxMesh.new()
	door.size = Vector3(0.9, 1.6, 0.12)
	n.add_child(mesh_node(door, mat(Color(0.25, 0.15, 0.08)), Vector3(0.6, 0.8, 2.28)))
	# The drying rack.
	var wood := mat(Color(0.45, 0.3, 0.17))
	var leaf := mat(Color(0.85, 0.74, 0.46))
	var base := Vector3(3.6, 0, 2.2)
	n.add_child(limb(base + Vector3(-1.1, 0, 0), base + Vector3(-1.1, 1.5, 0), 0.05, wood))
	n.add_child(limb(base + Vector3(1.1, 0, 0), base + Vector3(1.1, 1.5, 0), 0.05, wood))
	n.add_child(limb(base + Vector3(-1.2, 1.45, 0), base + Vector3(1.2, 1.45, 0), 0.035, wood))
	for i in 6:
		var olai := BoxMesh.new()
		olai.size = Vector3(0.16, 0.9, 0.015)
		n.add_child(mesh_node(olai, leaf, base + Vector3(-0.9 + i * 0.36, 0.98, 0)))
	root.add_child(n)
	obstacles.append(Vector3(HUT.x, HUT.z, 2.8))
	obstacles.append(Vector3(HUT.x + 3.6, HUT.z + 2.2, 1.1))
