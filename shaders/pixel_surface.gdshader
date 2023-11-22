shader_type spatial;

// ----- settings ----- //

#define USE_CEL_SHADING 1
#define USE_OUTLINE 1
#define USE_CLOUD_SHADOWS 1

// ----- uniforms ----- //

uniform vec3 albedo : source_color = vec3(0.6, 0.5, 0.5);
uniform sampler2D albedo_texture : source_color;

#if USE_CEL_SHADING
	#include "res://shaders/cel_shading.gdshaderinc"
#endif

#if USE_OUTLINE
	#include "res://shaders/outline.gdshaderinc"
#endif

#if USE_CLOUD_SHADOWS
	#include "res://shaders/cloud_shadows.gdshaderinc"
#endif

// ----- functions ----- //

void vertex() {
	#if USE_CLOUD_SHADOWS
		_world_matrix = INV_VIEW_MATRIX; // Varying from cloud_shadows.gdshaderinc
	#endif
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	#if USE_OUTLINE
		outline_frag; // Included from outline.gdshaderinc
	#endif
	#if USE_CLOUD_SHADOWS
		_vertex = VERTEX; // Varying from cloud_shadows.gdshaderinc
	#endif
}

void light() {
	// Diffuse lighting.
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (ATTENUATION - 1.0);

	#if USE_CLOUD_SHADOWS
		diffuse_amount -= cloud_shadow; // Included from cloud_shadows.gdshaderinc
	#endif

	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;

	#if USE_CEL_SHADING
		diffuse *= diffuse_stepped; // Included from cel_shading.gdshaderinc
	#else
		diffuse *= clamp(0.0, 1.0, diffuse_amount);
	#endif

	DIFFUSE_LIGHT += diffuse;
}