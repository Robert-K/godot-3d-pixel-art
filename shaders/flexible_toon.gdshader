shader_type spatial;

//render_mode ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0f);
uniform sampler2D albedo_texture : source_color;
uniform bool clamp_diffuse_to_max = false;

uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0f, 2.0f) = 0.0f;
uniform float steepness : hint_range(1.0f, 8.0f) = 1.0f;

uniform bool use_attenuation = true;

uniform bool use_specular = false;
uniform float specular_strength : hint_range(0.0f, 1.0f) = 1.0f;
uniform float specular_shininess : hint_range(0.0f, 32.0f) = 16.0f;
uniform sampler2D specular_map : source_color;

uniform bool use_rim = false;
uniform float rim_width : hint_range(0.0f, 16.0f) = 8.0f;
uniform vec4 rim_color : source_color = vec4(1.0f);

uniform bool use_ramp = false;
uniform sampler2D ramp : source_color;

uniform bool use_borders = false;
uniform float border_width = 0.01f;

varying vec3 vertex_pos;
varying vec3 normal;

float split_specular(float specular) {
	return step(0.5f, specular);
}

void vertex() {
	vertex_pos = VERTEX;
	normal = NORMAL;
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
}

void light() {
	// Attenuation.
	float attenuation = 1.0f;
	if (use_attenuation) {
		attenuation = ATTENUATION;
	}
	
	// Diffuse lighting.
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (attenuation - 1.0) + wrap;
	//float diffuse_amount = NdotL * attenuation + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0f / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);

	// Calculate borders.
	float border = 0.0f;
	if (use_borders) {
		float corr_border_width = length(cross(NORMAL, LIGHT)) * border_width * steepness;
		border = step(diffuse_stepped - corr_border_width, diffuse_amount)
				 - step(1.0 - corr_border_width, diffuse_amount);
	}
	
	// Apply diffuse result to different styles.
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	if (use_ramp) {
		diffuse *= texture(ramp, vec2(diffuse_stepped * (1.0f - border), 0.0f)).rgb;
	} else {
		diffuse *= diffuse_stepped * (1.0f - border);
	}
	
	if (clamp_diffuse_to_max) {
		// Clamp diffuse to max for multiple light sources.
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
	} else {
		DIFFUSE_LIGHT += diffuse;
	}
	
	// Specular lighting.
	if (use_specular) {
		vec3 H = normalize(LIGHT + VIEW);
		float NdotH = dot(NORMAL, H);
		float specular_amount = max(pow(NdotH, specular_shininess*specular_shininess), 0.0f)
							    * texture(specular_map, UV).r
								* attenuation;
		specular_amount = split_specular(specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}
	
	// Simple rim lighting.
	if (use_rim) {
		float NdotV = dot(NORMAL, VIEW);
		float rim_light = pow(1.0 - NdotV, rim_width);
		SPECULAR_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI; //Changed DIFFUSE_LIGHT to SPECULAR_LIGHT while migrating for similar result
	}
}