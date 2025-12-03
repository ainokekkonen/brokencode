
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;

void fragment() {
    vec4 sum = vec4(0.0);
    vec2 pixel_size = SCREEN_PIXEL_SIZE * blur_amount;

    // Simple 9-sample blur
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(x), float(y)) * pixel_size);
        }
    }

    COLOR = sum / 9.0;
}
