// ----- uniforms ----- //

group_uniforms cel_shading;
uniform int cuts : hint_range(1, 8, 1) = 3;

// ----- functions ----- //

float diffuse_stepped(float diffuse_amount) {
    float cuts_inv = 1.0f / float(cuts);
	return clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);
}