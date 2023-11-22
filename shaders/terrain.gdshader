shader_type spatial;

//render_mode ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0f);
uniform sampler2D albedo_texture : source_color;
uniform bool clamp_diffuse_to_max = false;
uniform vec3 cliff_color : source_color = vec3(1.0f);

global uniform int cel_cuts : hint_range(1, 8) = 3;
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

global uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_enable;
global uniform float cloud_scale = 0.1;
global uniform vec2 cloud_speed = vec2(0.03);
uniform float noise_strength = 1.0;

varying vec3 vertex_pos;
varying vec3 normal;
varying mat4 world_mat;
varying vec3 _vertex;

float split_specular(float specular) {
	return step(0.5f, specular);
}

void vertex() {
	vertex_pos = VERTEX;
	normal = NORMAL;
	world_mat = INV_VIEW_MATRIX;
}

void fragment() {
	_vertex = VERTEX;
	ALBEDO = mix(cliff_color, albedo.rgb * texture(albedo_texture, UV).rgb, dot(normal, vec3(0,1,0)));
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

	//float diffuse_amount = NdotL * attenuation + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0f / float(cel_cuts);
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