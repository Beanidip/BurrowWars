shader_type spatial;
render_mode unshaded, cull_back;

// Opaque terrain. ChunkMesher merges runs of identical block faces into big
// quads (far fewer triangles), so the per-block detail those faces used to
// carry in their vertex colours is worked out here instead, from the world
// position: each block's slight brightness variation, the darkening deeper
// underground, and the 2x2 mottling of stone, brick and obsidian. The hashes
// are the same ones ChunkMesher uses, so merged and unmerged faces match.
//
// UV.x says how to shade a vertex: 0 = as given (carvings, liquids, gadget
// shapes...), 1 = block variation + depth, 2 = block variation only (glowing
// blocks: cheese, bases, paint...), 3 = rocky, 4 = obsidian. UV.y = face 0-5
// (+X -X +Y -Y +Z -Z).

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 face_normal(int f) {
	if (f == 0) return vec3(1.0, 0.0, 0.0);
	if (f == 1) return vec3(-1.0, 0.0, 0.0);
	if (f == 2) return vec3(0.0, 1.0, 0.0);
	if (f == 3) return vec3(0.0, -1.0, 0.0);
	if (f == 4) return vec3(0.0, 0.0, 1.0);
	return vec3(0.0, 0.0, -1.0);
}

void fragment() {
	vec3 col = COLOR.rgb;
	int mode = int(UV.x + 0.5);
	if (mode > 0) {
		int f = int(UV.y + 0.5);
		vec3 inside = world_pos - face_normal(f) * 0.5;
		ivec3 c = ivec3(floor(inside));
		uint ux = uint(c.x);
		uint uy = uint(c.y);
		uint uz = uint(c.z);
		float tint = 0.93 + 0.14 * float(((ux * 73856093u) ^ (uy * 19349663u) ^ (uz * 83492791u)) & 255u) / 255.0;
		col *= tint;
		if (mode != 2) {
			col *= clamp(0.58 + 0.42 * float(c.y) / 28.0, 0.58, 1.0);
		}
		if (mode >= 3) {
			// which quarter of the face: the same 2x2 split ChunkMesher._rocky_face used
			vec2 within;
			if (f < 2) {
				within = vec2(fract(inside.z), fract(inside.y));
			} else if (f < 4) {
				within = vec2(fract(inside.x), fract(inside.z));
			} else {
				within = vec2(fract(inside.x), fract(inside.y));
			}
			uint i = uint(within.x >= 0.5 ? 1 : 0) + 2u * uint(within.y >= 0.5 ? 1 : 0);
			uint seed_i = ux * 7u + uy * 13u + uz * 29u + uint(f);
			float h = float((((seed_i + i * 37u) * 2654435761u) >> 8u) & 255u) / 255.0;
			if (mode == 4 && h > 0.72) {
				col = vec3(col.r * 1.9 + 0.08, col.g * 1.1, col.b * 2.1 + 0.1);   // an obsidian glint
			} else {
				col *= 0.86 + 0.26 * h;
			}
		}
	}
	ALBEDO = col;
}
