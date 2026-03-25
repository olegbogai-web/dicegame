shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled, depth_draw_always;

void fragment() {
    float gradient = 0.5 - UV.x;
    float mask = smoothstep(0.0, 1.0, gradient);

    float min_alpha = 0.04;
    float max_alpha = 0.4;

    float final_alpha = mix(min_alpha, max_alpha, mask);

    // оранжевый цвет (можно настроить)
    vec3 orange = vec3(1.0, 0.35, 0.0);

    ALBEDO = orange;
    ALPHA = final_alpha;
}