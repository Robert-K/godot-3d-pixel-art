// ----- uniforms ----- //

group_uniforms clouds;
global uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_enable;
global uniform float cloud_scale = 0.1;
global uniform vec2 cloud_speed = vec2(0.03);
global uniform float cloud_strength = 1;

// ----- varyings ----- //

varying mat4 _world_matrix;
varying vec3 _vertex;

// ----- functions ----- //

float _cloud_shadow(bool _light_is_dir, vec3 _light, mat4 _inv_view, float _time) {
    if (_light_is_dir) {
		//ray
		// p = ray_start + ray_dir * t
		vec3 ray_dir = -_light; // in view space
		ray_dir = mat3(_world_matrix) * ray_dir; // in world space
		vec3 ray_start = (_inv_view * vec4(_vertex, 1.0f)).xyz;
		
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
		vec2 uv_offset = vec2(_time) * cloud_speed;

		vec4 rg = texture( cloud_texture, uv * cloud_scale + uv_offset);
		
		return smoothstep(0.2, 1.0, (1.0 - rg.r) * cloud_strength);
	}
	return 0.0;
}
#define cloud_shadow _cloud_shadow(LIGHT_IS_DIRECTIONAL, LIGHT, INV_VIEW_MATRIX, TIME)