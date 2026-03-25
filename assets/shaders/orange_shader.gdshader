shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled, depth_draw_always;

uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float gradient = 0.5 - UV.x;
    float mask = smoothstep(0.0, 1.0, gradient);

    float min_alpha = 0.04;
    float max_alpha = 0.4;
    float hover_alpha_boost = 0.16;

    float final_alpha = mix(min_alpha, max_alpha, mask) + hover_alpha_boost * hover_strength;

    vec3 orange = vec3(1.0, 0.35, 0.0);
    vec3 yellow = vec3(1.0, 0.9, 0.2);
    vec3 final_color = mix(orange, yellow, hover_strength);

    ALBEDO = final_color;
    ALPHA = clamp(final_alpha, 0.0, 1.0);
}
