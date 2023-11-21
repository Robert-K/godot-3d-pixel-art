shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec3 albedo : source_color = vec3(0.6, 0.5, 0.5);
uniform int cuts : hint_range(1, 8, 1) = 3;

group_uniforms outline;
uniform float outline_intensity : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec3 outline_color : source_color = vec3(0.1, 0.1, 0.2);
uniform float depth_threshold : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float depth_normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float depth_normal_threshold_scale = 2.0;

group_uniforms edges;
uniform float edge_intensity : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform vec3 edge_color : source_color = vec3(0.7, 0.6, 0.6);
uniform float convex_threshold = 0.1;

global uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_enable;
global uniform float cloud_scale = 0.1;
global uniform vec2 cloud_speed = vec2(0.03);
uniform float noise_strength = 1.0;

// a little function/macro to encapsulate getting the view position
vec3 _view_from_screen(vec2 _uv, float _depth, mat4 _inv_proj) {
	vec4 _upos = _inv_proj * vec4(_uv * 2.0 - 1.0, _depth, 1.0);
	return _upos.xyz / _upos.w;
}
#define view_from_screen(uv, depth_tex) _view_from_screen((uv), textureLod((depth_tex), (uv), 0.0).r, INV_PROJECTION_MATRIX)

varying mat4 world_mat;
varying vec3 _vertex;

void vertex() {
	world_mat = INV_VIEW_MATRIX;
}

void fragment() {
	ALBEDO = albedo;
	// fragment position in view space
	vec3 vpos = view_from_screen(SCREEN_UV, depth_texture);
	// fragment normal in view space
	vec3 normal = texture(normal_roughness_texture, SCREEN_UV).xyz * 2.0 - 1.0;
	
	// directly connected neighbouring texel uv, view positions, and normals
	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	vec2 uv_t = SCREEN_UV + vec2(0.0, -texel_size.y);
	vec2 uv_b = SCREEN_UV + vec2(0.0,  texel_size.y);
	vec2 uv_l = SCREEN_UV + vec2(-texel_size.x, 0.0);
	vec2 uv_r = SCREEN_UV + vec2( texel_size.x, 0.0);
	vec3 vpos_t = view_from_screen(uv_t, depth_texture);
	vec3 vpos_b = view_from_screen(uv_b, depth_texture);
	vec3 vpos_l = view_from_screen(uv_l, depth_texture);
	vec3 vpos_r = view_from_screen(uv_r, depth_texture);
	vec3 normal_t = texture(normal_roughness_texture, uv_t).xyz * 2.0 - 1.0;
	vec3 normal_b = texture(normal_roughness_texture, uv_b).xyz * 2.0 - 1.0;
	vec3 normal_l = texture(normal_roughness_texture, uv_l).xyz * 2.0 - 1.0;
	vec3 normal_r = texture(normal_roughness_texture, uv_r).xyz * 2.0 - 1.0;
	
	// thresholding the view direction
	// NOTE(david): in orthogonal projections, normal.z is equivalent to dot(normal, -view_forward)
	float normal_diff = 1.0 - normal.z;
	float normal_threshold01 = clamp((normal_diff - depth_normal_threshold) / (1.0 - depth_normal_threshold), 0.0, 1.0);
	float normal_threshold = normal_threshold01 * depth_normal_threshold_scale + 1.0;
	
	// final depth threshold
	float depth_thresh = depth_threshold * normal_threshold;

	// crosses to get convexity/concavity (mostly)
	vec3 edge_t = cross(normal, normal_t);
	vec3 edge_b = cross(normal, normal_b);
	vec3 edge_l = cross(normal, normal_l);
	vec3 edge_r = cross(normal, normal_r);
	
	// ===== edge ===== //
	// top edge
	if (
		// ensure we're below the depth threshold
		abs(vpos.z - vpos_b.z) < depth_thresh &&
		// is the normal more oblique; less aligned with the camera (takes priority when even)
		normal.z <= normal_b.z &&
		// convex edge on the bottom
		edge_b.r > convex_threshold
	) {
		ALBEDO = mix(ALBEDO, edge_color, edge_intensity);
	}
	// bottom edge
	if (
		abs(vpos.z - vpos_t.z) < depth_thresh &&
		normal.z < normal_t.z &&
		-edge_t.r > convex_threshold
	) {
		ALBEDO = mix(ALBEDO, edge_color, edge_intensity);
	}
	// right edge
	if (
		abs(vpos.z - vpos_l.z) < depth_thresh &&
		normal.z <= normal_l.z &&
		-edge_l.g > convex_threshold
	) {
		ALBEDO = mix(ALBEDO, edge_color, edge_intensity);
	}
	// left edge
	if (
		abs(vpos.z - vpos_r.z) < depth_thresh &&
		normal.z < normal_r.z &&
		edge_r.g  > convex_threshold
	) {
		ALBEDO = mix(ALBEDO, edge_color, edge_intensity);
	}
	
	 // ===== outline ===== //
	if (
		vpos.z - vpos_b.z > depth_thresh ||
		vpos.z - vpos_t.z > depth_thresh ||
		vpos.z - vpos_r.z > depth_thresh ||
		vpos.z - vpos_l.z > depth_thresh
	) {
		ALBEDO = mix(ALBEDO, outline_color, outline_intensity);
	}
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

	float cuts_inv = 1.0f / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);
	
	// Apply diffuse result to different styles.
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	diffuse *= diffuse_stepped;
	DIFFUSE_LIGHT += diffuse;
}