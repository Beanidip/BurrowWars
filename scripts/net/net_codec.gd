class_name NetCodec
## Compact wire format for the 20 Hz snapshot's rats: 27 bytes each instead
## of a Variant array with the name and class spelled out every time (about a
## sixth of the size). Positions are kept to 1/128 of a block, velocities to
## 1/256 block/s, timers to 1/50 s; names travel separately (see NetServer
## roster), as they hardly ever change.
##
## A record decodes back to the array NetClient always used:
## [id, team, class_id, name, flags, position, vel, yaw, action, action_t,
##  carried, stun, knock, operating]

const RAT_BYTES := 27
const POS_SCALE := 128.0
const VEL_SCALE := 256.0
const TIME_SCALE := 50.0
const CLASSES := ["digger", "scout", "builder", "saboteur", "maestro"]
const ACTIONS := ["", "idle", "run", "jump", "dig", "attack", "hurt", "build", "use", "down"]


static func _s16(v: float) -> int:
	return clampi(roundi(v), -32768, 32767)


static func _u8(v: float) -> int:
	return clampi(roundi(v), 0, 255)


static func encode_rats(rats: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(rats.size() * RAT_BYTES)
	var o := 0
	for r: Rat in rats:
		var f := (1 if r.on_floor else 0) | (2 if r.on_ladder else 0) | (4 if r.in_water else 0) | (8 if r.flying else 0) \
			| (16 if r.is_bot else 0) | (32 if r.team == 1 else 0)
		out.encode_u16(o, r.id & 0xFFFF)
		out.encode_u8(o + 2, f)
		out.encode_u8(o + 3, maxi(0, CLASSES.find(r.class_id)))
		out.encode_s16(o + 4, _s16(r.position.x * POS_SCALE))
		out.encode_s16(o + 6, _s16(r.position.y * POS_SCALE))
		out.encode_s16(o + 8, _s16(r.position.z * POS_SCALE))
		out.encode_s16(o + 10, _s16(r.vel.x * VEL_SCALE))
		out.encode_s16(o + 12, _s16(r.vel.y * VEL_SCALE))
		out.encode_s16(o + 14, _s16(r.vel.z * VEL_SCALE))
		out.encode_u16(o + 16, posmod(roundi(fposmod(r.yaw, TAU) / TAU * 65536.0), 65536))
		out.encode_u8(o + 18, maxi(0, ACTIONS.find(r.anim_action)))
		out.encode_u8(o + 19, _u8(r.anim_action_t * TIME_SCALE))
		out.encode_u8(o + 20, clampi(r.carried, 0, 255))
		out.encode_u8(o + 21, _u8(r.stun * TIME_SCALE))
		out.encode_u8(o + 22, _u8(r.knock * TIME_SCALE))
		out.encode_s32(o + 23, r.operating)
		o += RAT_BYTES
	return out


static func decode_rats(data: PackedByteArray, names: Dictionary) -> Array:
	## Malformed data decodes to nothing rather than to garbage.
	var out: Array = []
	if data.size() % RAT_BYTES != 0:
		return out
	for o in range(0, data.size(), RAT_BYTES):
		var id := data.decode_u16(o)
		var f := data.decode_u8(o + 2)
		var cls: String = CLASSES[mini(data.decode_u8(o + 3), CLASSES.size() - 1)]
		var pos := Vector3(data.decode_s16(o + 4), data.decode_s16(o + 6), data.decode_s16(o + 8)) / POS_SCALE
		var vel := Vector3(data.decode_s16(o + 10), data.decode_s16(o + 12), data.decode_s16(o + 14)) / VEL_SCALE
		var yaw := float(data.decode_u16(o + 16)) / 65536.0 * TAU
		var act: String = ACTIONS[mini(data.decode_u8(o + 18), ACTIONS.size() - 1)]
		out.append([id, 1 if (f & 32) != 0 else 0, cls, String(names.get(id, "Rat")), f & 31, pos, vel, yaw, act,
			float(data.decode_u8(o + 19)) / TIME_SCALE, data.decode_u8(o + 20), float(data.decode_u8(o + 21)) / TIME_SCALE,
			float(data.decode_u8(o + 22)) / TIME_SCALE, data.decode_s32(o + 23)])
	return out
