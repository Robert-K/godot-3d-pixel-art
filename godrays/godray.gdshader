shader_type spatial;
render_mode skip_vertex_transform, depth_draw_never, cull_disabled;

// ----- settings ----- //

#define USE_CLOUD_SHADOWS 0

// ----- uniforms ----- //

//uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec3 ray_color : source_color = vec3(1.0, 0.9, 0.5);

uniform float start_depth = 14.0;
//uniform float gap = 1.0;
//uniform int instance_count = 8;
uniform float alpha = 0.02;

global uniform vec3 sun_direction;

varying vec3 vertex_w;
varying float depth_fade;
varying float instance_fade;

#if USE_CLOUD_SHADOWS
	#include "res://shaders/cloud_shadows.gdshaderinc"
#endif

#define UP vec3(0, 1, 0)

// ----- functions ----- //

void vertex() {
	vertex_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	EMISSION = ray_color;

	float dist = length(VERTEX);

	depth_fade = clamp(dist / start_depth, 0, 1);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		//vec3 light = world_from_view_dir(LIGHT);
		//vec3 pos = vertex_w * (light_w * (-vertex_w.y - light_w.y) / light_w.y);
		//float clouds = sample_clouds(pos, 0.0);
		float attenuation = ATTENUATION;
		#if USE_CLOUD_SHADOWS
			attenuation -= cloud_shadow;
		#endif

		ALPHA = alpha;
		ALPHA *= attenuation;
		//ALPHA *= instance_fade;
		ALPHA *= depth_fade;
		ALPHA *= max(0, dot(sun_direction, -UP));
		//ALPHA *= pow(clamp(0.66 * dot(LIGHT, vec3(0, 0, -1)), 0, 1), 0.5);
		//ALPHA *= clamp(FRAGCOORD.z / 0.1, 0, 1);
	}
}