shader_type spatial;
render_mode depth_prepass_alpha;

// ----- settings ----- //

#define USE_CEL_SHADING
#define USE_OUTLINE
//#define USE_CLOUD_SHADOWS

// ----- uniforms ----- //

uniform vec3 albedo : source_color = vec3(0.6, 0.5, 0.5);
uniform sampler2D albedo_texture : source_color;

#ifdef USE_CEL_SHADING
	#include "res://shaders/cel_shading.gdshaderinc"
#endif

#ifdef USE_OUTLINE
	#include "res://shaders/outline.gdshaderinc"
#endif

#ifdef USE_CLOUD_SHADOWS
	#include "res://shaders/clouds.gdshaderinc"
#endif

// ----- functions ----- //

void vertex() {
	#ifdef USE_CLOUD_SHADOWS
		_world_matrix = INV_VIEW_MATRIX; // Varying from cloud_shadows.gdshaderinc
	#endif
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	#ifdef USE_OUTLINE
		outline_frag; // Included from outline.gdshaderinc
	#endif
	#ifdef USE_CLOUD_SHADOWS
		_vertex = VERTEX; // Varying from cloud_shadows.gdshaderinc
	#endif
}

void light() {
	// Diffuse lighting.
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (ATTENUATION - 1.0);

	#ifdef USE_CLOUD_SHADOWS
		diffuse_amount *= cloud_shadow(); // Included from cloud_shadows.gdshaderinc
	#endif

	// Apply diffuse result to different styles.
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;

	#ifdef USE_CEL_SHADING
		diffuse *= diffuse_stepped(diffuse_amount); // Included from cel_shading.gdshaderinc
	#endif

	DIFFUSE_LIGHT += diffuse;
}