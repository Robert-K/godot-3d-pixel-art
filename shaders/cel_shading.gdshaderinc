// ----- uniforms ----- //

group_uniforms cel_shading;
global uniform int cel_cuts : hint_range(1, 8, 1) = 3;

// ----- functions ----- //

float _diffuse_stepped(float _diffuse_amount) {
    float cuts_inv = 1.0 / float(cel_cuts);
	return clamp(_diffuse_amount + mod(1.0 - _diffuse_amount, cuts_inv), 0.0, 1.0);
}
#define diffuse_stepped _diffuse_stepped(diffuse_amount)