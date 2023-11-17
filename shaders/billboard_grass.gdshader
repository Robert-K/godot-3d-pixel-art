shader_type spatial;
render_mode depth_prepass_alpha, depth_draw_opaque;

uniform vec3 albedo : source_color = vec3(0.2, 0.9, 0.1);
uniform sampler2D alpha_texture : filter_nearest;
uniform int cuts : hint_range(1, 8, 1) = 3;
uniform int groups = 6;

uniform float emissive_threshold = 0.99;
uniform float unlit_threshold = 0.99;

uniform float fps = 2.0f;

float random (vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

varying vec3 lighting_position_world;
varying float r;
void vertex()
{
	// Get a random number based on world position
	r = random(NODE_POSITION_WORLD.xz);
	float g = floor(r * float(groups)) / float(groups);
	// Animate sway at low frame rate
	float t = floor((TIME + g * 10.0) * fps) / fps;
	// Sway is stronger at the top
	VERTEX.x += sin(PI * t) * VERTEX.y * 0.2;
	// Billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	// Pass lighting_position_world to fragment shader
	lighting_position_world = NODE_POSITION_WORLD + vec3(0.0, 0.07, 0.0);
	// Make normal point up
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// Calculate sprite uv offset based on random number
	float x = mod(floor(r * 9.0), 3.0);
	float y = floor(r * 3.0);
	// There's 3x3 sprites packed in the texture
	ALPHA = texture(alpha_texture, (UV + vec2(x,y)) / vec2(3.0)).a;
	ALBEDO = albedo * vec3(COLOR[0],COLOR[1],COLOR[2]);
	if (r>emissive_threshold) {
		EMISSION = albedo;
	}
	// Set vertex coordinate to the lighting_position
	// This will cause the whole billboard to be shaded the same
	VERTEX =  (VIEW_MATRIX * vec4(lighting_position_world, 1.0)).xyz;
}

void light() {
	// Diffuse lighting.
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (ATTENUATION - 1.0);
	float cuts_inv = 1.0f / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);
	
	// Apply diffuse result to different styles.
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	diffuse *= diffuse_stepped;
	if (r >= 1.0 - unlit_threshold) {
		DIFFUSE_LIGHT += diffuse;
	}
}