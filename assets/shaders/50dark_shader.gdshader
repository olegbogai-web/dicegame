shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;
uniform sampler2D background : source_color;
void fragment() {
    vec4 tex = texture(background, UV);
    float gradient = 1.0 - UV.x;
    float mask = smoothstep(0.0, 0.7, gradient);
    float min_dark = 0.2;
    float max_dark = 0.93;
    float final_alpha = mix(min_dark, max_dark, mask);
    vec3 darkened = tex.rgb * (1.0 - final_alpha);
    ALBEDO = darkened;
    ALPHA = tex.a;
}