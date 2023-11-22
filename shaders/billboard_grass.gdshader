shader_type spatial;
render_mode depth_prepass_alpha, depth_draw_opaque;

uniform vec3 albedo : source_color = vec3(0.2, 0.9, 0.1);
uniform sampler2D alpha_texture : filter_nearest;
global uniform int cel_cuts : hint_range(1, 8, 1) = 3;
uniform int groups = 6;

uniform float emissive_threshold = 0.99;
uniform float unlit_threshold = 0.99;

global uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_enable;
global uniform float cloud_scale = 0.1;
global uniform vec2 cloud_speed = vec2(0.03);
uniform float noise_strength = 1.0;

uniform float fps = 2.0f;

varying mat4 world_mat;
varying vec3 _vertex;

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
	world_mat = INV_VIEW_MATRIX;
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
	_vertex = VERTEX;
}

void light() {
	// Diffuse lighting.
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (ATTENUATION - 1.0);

	if (LIGHT_IS_DIRECTIONAL) {
		//ray
		// p = ray_start + ray_dir * t
		vec3 ray_dir = -LIGHT; // in view space
		ray_dir = mat3(world_mat) * ray_dir; // in world space
		vec3 ray_start = (INV_VIEW_MATRIX * vec4(_vertex, 1.0f)).xyz;
		
		//plane
		// (p - p0) . n = 0
		vec3 n = vec3(0.0, 1.0, 0.0); 
		vec3 PO = vec3(0.0, 1.0, 0.0); // can make offset to the top
		vec3 v = PO - ray_start;

		// solve for parameter t
		// t = ((p0 - ray_start) . n) / (ray_dir . n)
		float t = dot(normalize(v), n) * length(v) / dot(ray_dir, n);
		vec3 P = ray_start + t * ray_dir;  // in world space
		
		vec2 uv = P.xz; // convert it to texture UV
		vec2 uv_offset = vec2(TIME, TIME) * cloud_speed;

		vec4 rg = texture( cloud_texture, uv * cloud_scale + uv_offset) * noise_strength;
		
		float clouds = smoothstep(0.2, 1.0, 1.0 - rg.r);

		//make it less dark, can skip it
		//clouds *= 0.9;
		//clouds += 0.1;
		
		//To sample shadow with different blur param, check the tutorial linked in the description
		//float blur = 1.;
		//if(clouds < 1.0) blur += 10. * smoothstep(0.2, 1.0, rg.r) ;	
		//float shadow = get_directional_shadow(LIGHT_INDEX, _vertex, blur);
		
		diffuse_amount -= clouds;
	}

	float cuts_inv = 1.0f / float(cel_cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);
	
	// Apply diffuse result to different styles.
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	diffuse *= diffuse_stepped;
	if (r >= 1.0 - unlit_threshold) {
		DIFFUSE_LIGHT += diffuse;
	}
}