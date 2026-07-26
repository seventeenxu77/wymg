shader_type spatial;
render_mode unshaded;

uniform sampler2D floor_tex : source_color;
uniform vec3 light_position = vec3(0.0, 0.0, 0.0);
uniform float light_max_dist : hint_range(1.0, 20.0) = 4.8;
uniform float dark_factor : hint_range(0.0, 1.0) = 0.15;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 base = texture(floor_tex, UV);
	float dx = world_pos.x - light_position.x;
	float dz = world_pos.z - light_position.z;
	float dist = sqrt(dx * dx + dz * dz);
	float t = clamp(dist / light_max_dist, 0.0, 1.0);
	t = t * t;
	float brightness = mix(1.0, dark_factor, t);
	ALBEDO = base.rgb * brightness;
}
