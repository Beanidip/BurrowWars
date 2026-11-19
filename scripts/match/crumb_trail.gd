class_name CrumbTrail
extends MultiMeshInstance3D
## Cheese crumbs on the ground behind everyone carrying cheese (and behind
## Wind-up Decoys). The authority sends one "crumb" effect every
## Config.CRUMB_EVERY blocks a carrier covers, so anyone can follow the trail.
## Each crumb is a little cluster of cheese bits that lies for
## Config.CRUMB_TIME seconds and then shrinks away. One MultiMesh draws them
## all. Presentation only.

const CAP := 1024          # crumbs on the ground at once; the oldest make room
const FADE := 4.0          # seconds of shrinking at the end of a crumb's life
const BITS := [            # one cluster: [offset, size]
	[Vector3(0.0, 0.0, 0.0), 0.12],
	[Vector3(0.17, 0.0, 0.07), 0.085],
	[Vector3(-0.1, 0.0, 0.16), 0.075],
	[Vector3(-0.14, 0.0, -0.12), 0.09],
	[Vector3(0.08, 0.0, -0.19), 0.065],
	[Vector3(0.24, 0.0, -0.08), 0.05],
]
const SHADES := [Color(1.0, 0.84, 0.25), Color(0.98, 0.74, 0.16), Color(1.0, 0.9, 0.45), Color(0.93, 0.66, 0.12)]

var _born := PackedFloat32Array()    # per slot: when it landed (-1 = empty)
var _place: Array[Transform3D] = []  # per slot: its full-size transform
var _next := 0
var _t := 0.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _cluster()
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	_born.resize(CAP)
	_born.fill(-1.0)
	_place.resize(CAP)


func add(pos: Vector3) -> void:
	var slot := _next % CAP
	_next += 1
	var basis := Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(0.8, 1.25))
	var at := pos + Vector3(randf_range(-0.12, 0.12), 0.004, randf_range(-0.12, 0.12))
	_place[slot] = Transform3D(basis, at)
	_born[slot] = _t
	multimesh.set_instance_transform(slot, _place[slot])
	multimesh.visible_instance_count = mini(_next, CAP)


func count() -> int:
	## Crumbs on the ground right now.
	var n := 0
	for b in _born:
		if b >= 0.0:
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	var fade_from := Config.CRUMB_TIME - FADE
	for i in mini(_next, CAP):
		var born := _born[i]
		if born < 0.0:
			continue
		var age := _t - born
		if age < fade_from:
			continue
		var xf := _place[i]
		if age >= Config.CRUMB_TIME:
			_born[i] = -1.0
			xf.basis = xf.basis.scaled(Vector3.ZERO)
		else:
			xf.basis = xf.basis.scaled(Vector3.ONE * ((Config.CRUMB_TIME - age) / FADE))
		multimesh.set_instance_transform(i, xf)


static func _cluster() -> ArrayMesh:
	## A handful of little cheese cubes, lit from above (tops light, sides darker).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in BITS.size():
		var at: Vector3 = BITS[k][0]
		var h: float = BITS[k][1]
		var c: Color = SHADES[k % SHADES.size()]
		var lo := at - Vector3(h, 0, h) * 0.5
		var hi := at + Vector3(h * 0.5, h * 0.8, h * 0.5)
		_box(st, lo, hi, c)
	return st.commit()


static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, c: Color) -> void:
	var faces := [
		[Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), 1.12],   # top
		[Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z), 0.86],   # +z
		[Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), 0.8],    # -z
		[Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), 0.74],   # +x
		[Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z), 0.92],   # -x
	]
	for f: Array in faces:
		var shade: float = f[4]
		st.set_color(Color(minf(c.r * shade, 1.0), minf(c.g * shade, 1.0), minf(c.b * shade, 1.0)))
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(f[idx])
