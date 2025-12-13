shader_type canvas_item;
render_mode blend_mix;

uniform vec4 outline_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_thickness : hint_range(0, 10) = 1.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    if (color.a == 0.0) {
        // Sample neighbors to find outline
        vec2 pixel_size = TEXTURE_PIXEL_SIZE;
        vec4 neighbor_color;
        float alpha_sum = 0.0;
        for (float x = -outline_thickness; x <= outline_thickness; x++) {
            for (float y = -outline_thickness; y <= outline_thickness; y++) {
                if (x == 0.0 && y == 0.0) continue;
                vec2 offset = vec2(x, y) * pixel_size;
                neighbor_color = texture(TEXTURE, UV + offset);
                if (neighbor_color.a > 0.0) {
                    alpha_sum += 1.0;
                }
            }
        }
        // Draw outline if near a solid pixel
        if (alpha_sum > 0.0) {
            COLOR = outline_color;
        } else {
            COLOR = color;
        }
    } else {
        COLOR = color;
    }
}
