shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms color;
uniform vec4 outline_color : source_color = vec4(0, 0, 1, 1);
uniform vec4 edge_color : source_color = vec4(1, 0, 0, 1);

group_uniforms outline;
uniform float depth_threshold : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float depth_normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float depth_normal_threshold_scale = 2.0;

group_uniforms edge;
uniform float convex_threshold = 0.1;

// a little function/macro to encapsulate getting the view position
vec3 _view_from_screen(vec2 _uv, float _depth, mat4 _inv_proj) {
	vec4 _upos = _inv_proj * vec4(_uv * 2.0 - 1.0, _depth, 1.0);
	return _upos.xyz / _upos.w;
}
#define view_from_screen(uv, depth_tex) _view_from_screen((uv), textureLod((depth_tex), (uv), 0.0).r, INV_PROJECTION_MATRIX)

varying float is_outline;

void fragment() {
	ALPHA = 0.0;
	
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
		EMISSION = edge_color.rgb;
		ALPHA = edge_color.a;
		ALBEDO = edge_color.rgb;
	}
	// bottom edge
	if (
		abs(vpos.z - vpos_t.z) < depth_thresh &&
		normal.z < normal_t.z &&
		-edge_t.r > convex_threshold
	) {
		EMISSION = edge_color.rbg;
		ALPHA = edge_color.a;
		ALBEDO = edge_color.rgb;
	}
	// right edge
	if (
		abs(vpos.z - vpos_l.z) < depth_thresh &&
		normal.z <= normal_l.z &&
		-edge_l.g > convex_threshold
	) {
		EMISSION = edge_color.rgb;
		ALPHA = edge_color.a;
		ALBEDO = edge_color.rgb;
	}
	// left edge
	if (
		abs(vpos.z - vpos_r.z) < depth_thresh &&
		normal.z < normal_r.z &&
		edge_r.g  > convex_threshold
	) {
		EMISSION = edge_color.rgb;
		ALPHA = edge_color.a;
		ALBEDO = edge_color.rgb;
	}
	is_outline = 0;
	 // ===== outline ===== //
	if (
		vpos.z - vpos_b.z > depth_thresh ||
		vpos.z - vpos_t.z > depth_thresh ||
		vpos.z - vpos_r.z > depth_thresh ||
		vpos.z - vpos_l.z > depth_thresh
	) {
		EMISSION = outline_color.rgb;
		ALPHA = outline_color.a;
		ALBEDO = outline_color.rgb;
		is_outline = 1;
	}

	light() {
		EMISSION = vec3(is_outline); // just a test
	}
}
