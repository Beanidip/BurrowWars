// Effect sprite recoloured towards a block's colour (FxSprite with a tint).
// Each pixel keeps its brightness and alpha, takes the block's hue, and is no
// more colourful than the block (give or take), so grey stone throws grey
// sparks, dirt brown ones, ice pale blue ones, paint its own colour.
// `colorize` goes further: it blends towards the block's own colour scaled by
// each pixel's brightness, so even white-hot cores and highlights take the
// block's colour (a light shade of it), with a floor so dark blocks still show.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform float hue = 0.0;
uniform float sat = 0.0;
uniform vec3 block_rgb = vec3(1.0);
uniform float colorize = 0.0;
uniform vec2 shade = vec2(0.45, 1.3);   // colourised: block colour times this, from the darkest pixel to the brightest

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	// face the camera, like a billboard Sprite3D
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec3 hsv = rgb2hsv(c.rgb);
	float lum = hsv.z;
	hsv.x = hue;
	hsv.y = min(hsv.y, sat * 1.2);
	vec3 base = max(block_rgb, vec3(0.22));                // very dark blocks still throw visible sparks
	vec3 painted = clamp(base * mix(shade.x, shade.y, lum) + vec3(0.12) * lum * lum * step(1.2, shade.y), 0.0, 1.0);
	ALBEDO = mix(hsv2rgb(hsv), painted, colorize);
	ALPHA = c.a;
}
