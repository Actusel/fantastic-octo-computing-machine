shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


uniform float desaturation : hint_range(0.0, 1.0) = 0.5;
uniform float contrast : hint_range(0.0, 2.0) = 0.8;
uniform float brightness : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform vec3 tint_color : source_color = vec3(0.7, 0.9, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.1;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.05;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 color = texture(SCREEN_TEXTURE, uv);

    // Desaturation
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desat = mix(color.rgb, vec3(gray), desaturation);

    // Contrast adjustment
    vec3 avg_lum = vec3(0.5);
    vec3 contrasted = mix(avg_lum, desat, contrast);

    // Brightness adjustment
    vec3 bright = contrasted * brightness;

    // Tint (cold tone)
    vec3 tinted = mix(bright, tint_color, tint_strength);

    // Vignette
    vec2 center = vec2(0.5);
    float dist = distance(uv, center);
    float vignette = smoothstep(0.7, 1.0, dist);
    tinted *= mix(1.0, 1.0 - vignette_intensity, vignette);

    // Film grain (simple pseudo-random noise)
    float grain = fract(sin(dot(uv * vec2(800.0, 600.0), vec2(12.9898, 78.233))) * 43758.5453);
    tinted += (grain - 0.5) * grain_strength;

    COLOR = vec4(tinted, color.a);
}