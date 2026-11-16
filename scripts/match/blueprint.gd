class_name Blueprint
extends RefCounted
## Pantograph clipboard: a box of material blocks with their carvings.
## Only building materials are ever captured, so a blueprint cannot carry
## cheese, scrap, explosives, traps or machines.

var size := Vector3i.ZERO
var cells: Array[Dictionary] = []   # {"o": Vector3i, "id": int, "mask": PackedByteArray or null}
var skipped := 0                    # blocks in the selection that could not be copied


static func capture(world: VoxelWorld, a: Vector3i, b: Vector3i) -> Blueprint:
	var bp := Blueprint.new()
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	bp.size = hi - lo + Vector3i.ONE
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				var c := Vector3i(x, y, z)
				var id := world.get_cell(c)
				if id == Blocks.AIR or id == Blocks.WATER or id == Blocks.LAVA:
					continue
				if not Blocks.COPYABLE.has(id) or not VoxelWorld.in_bounds(c):
					bp.skipped += 1
					continue
				var mask: Variant = null
				if world.has_micro(c):
					mask = (world.micro[c] as PackedByteArray).duplicate()
				bp.cells.append({"o": c - lo, "id": id, "mask": mask})
	return bp


func rotated() -> Blueprint:
	## Quarter turn about the vertical axis; carvings turn with their block.
	var out := Blueprint.new()
	out.size = Vector3i(size.z, size.y, size.x)
	out.skipped = skipped
	var m := Blocks.MICRO
	for e in cells:
		var o: Vector3i = e["o"]
		var mask: Variant = null
		if e["mask"] != null:
			var src: PackedByteArray = e["mask"]
			var dst := PackedByteArray()
			dst.resize(Blocks.MICRO_COUNT)
			for y in m:
				for z in m:
					for x in m:
						dst[(m - 1 - z) + m * (x + m * y)] = src[x + m * (z + m * y)]
			mask = dst
		out.cells.append({"o": Vector3i(size.z - 1 - o.z, o.y, o.x), "id": e["id"], "mask": mask})
	return out


func mirrored() -> Blueprint:
	## Left-right mirror image (across the blueprint's own x axis); carvings too.
	return _remap(func(o: Vector3i) -> Vector3i: return Vector3i(size.x - 1 - o.x, o.y, o.z),
		func(x: int, y: int, z: int) -> int: return (Blocks.MICRO - 1 - x) + Blocks.MICRO * (z + Blocks.MICRO * y))


func flipped() -> Blueprint:
	## Upside down; carvings too.
	return _remap(func(o: Vector3i) -> Vector3i: return Vector3i(o.x, size.y - 1 - o.y, o.z),
		func(x: int, y: int, z: int) -> int: return x + Blocks.MICRO * (z + Blocks.MICRO * (Blocks.MICRO - 1 - y)))


func _remap(cell_map: Callable, micro_index: Callable) -> Blueprint:
	var out := Blueprint.new()
	out.size = size
	out.skipped = skipped
	var m := Blocks.MICRO
	for e in cells:
		var mask: Variant = null
		if e["mask"] != null:
			var src: PackedByteArray = e["mask"]
			var dst := PackedByteArray()
			dst.resize(Blocks.MICRO_COUNT)
			for y in m:
				for z in m:
					for x in m:
						dst[int(micro_index.call(x, y, z))] = src[x + m * (z + m * y)]
			mask = dst
		out.cells.append({"o": cell_map.call(e["o"]), "id": e["id"], "mask": mask})
	return out


func inverted() -> Blueprint:
	## Inside out: every empty spot in the box becomes a block of the
	## blueprint's most-used material, every full block becomes empty, and
	## carved blocks keep exactly the microvoxels that were carved away.
	var out := Blueprint.new()
	out.size = size
	out.skipped = skipped
	var tally := {}
	var at := {}
	for e in cells:
		at[e["o"]] = e
		tally[e["id"]] = int(tally.get(e["id"], 0)) + 1
	var fill := Blocks.DIRT
	var best := -1
	for id: int in tally:
		if int(tally[id]) > best:
			best = int(tally[id])
			fill = id
	for y in size.y:
		for z in size.z:
			for x in size.x:
				var o := Vector3i(x, y, z)
				if not at.has(o):
					out.cells.append({"o": o, "id": fill, "mask": null})
					continue
				var e: Dictionary = at[o]
				if e["mask"] == null:
					continue
				var src: PackedByteArray = e["mask"]
				var dst := PackedByteArray()
				dst.resize(Blocks.MICRO_COUNT)
				for i in Blocks.MICRO_COUNT:
					dst[i] = 1 if src[i] == 0 else 0
				if dst.count(1) == 0:
					continue
				out.cells.append({"o": o, "id": e["id"], "mask": null if dst.count(1) == Blocks.MICRO_COUNT else dst})
	return out


func cost() -> Dictionary:
	## Material name -> microvoxels needed (343 per uncarved block).
	var need := {}
	for e in cells:
		var mat := Blocks.mat_of(int(e["id"]))
		var n := Blocks.MICRO_COUNT if e["mask"] == null else (Blocks.MICRO_COUNT - (e["mask"] as PackedByteArray).count(0))
		need[mat] = int(need.get(mat, 0)) + n
	return need


func cost_text() -> String:
	var parts := PackedStringArray()
	var need := cost()
	for mat: String in need:
		parts.append("%s %.1f" % [mat, float(need[mat]) / float(Blocks.MICRO_COUNT)])
	return ", ".join(parts)


func validate() -> String:
	## The authority never trusts a blueprint handed to it.
	var limit := Config.PANTOGRAPH_MAX
	if size.x < 1 or size.y < 1 or size.z < 1 or size.x > limit or size.y > limit or size.z > limit:
		return "Blueprint is larger than %d blocks on a side" % limit
	if cells.is_empty():
		return "Blueprint is empty"
	if cells.size() > limit * limit * limit:
		return "Blueprint has too many blocks"
	var seen := {}
	for e in cells:
		if not (e.get("o") is Vector3i) or not (e.get("id") is int):
			return "Blueprint is malformed"
		var o: Vector3i = e["o"]
		if o.x < 0 or o.y < 0 or o.z < 0 or o.x >= size.x or o.y >= size.y or o.z >= size.z or seen.has(o):
			return "Blueprint is malformed"
		seen[o] = true
		if not Blocks.COPYABLE.has(int(e["id"])):
			return "Blueprint contains something that cannot be copied"
		var mask: Variant = e.get("mask")
		if mask != null and (not (mask is PackedByteArray) or (mask as PackedByteArray).size() != Blocks.MICRO_COUNT \
				or (mask as PackedByteArray).count(0) == Blocks.MICRO_COUNT):
			return "Blueprint is malformed"
	return ""
