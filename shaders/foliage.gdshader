shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec3 albedo : source_color = vec3(0.5, 0.6, 0.4);
uniform int cuts : hint_range(1, 8, 1) = 3;

void fragment() {
	ALBEDO = albedo;
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
	DIFFUSE_LIGHT += diffuse;
}