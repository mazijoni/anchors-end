/*
Shader License – Dzsulio 2025

Copyright (c) 2025 Dzsulio

Allowed:
- You may use and modify this shader in games, including commercial releases.
- You may sell the game that includes this shader.

Restrictions:
1. You **cannot resell** this shader as a standalone file or as part of a shader pack.
2. You **cannot share** or distribute this shader publicly.

No Liability:
- The author (Dzsulio) **accepts no responsibility** for any issues or damages arising from the use of this shader.
*/

shader_type canvas_item;

uniform bool USE_NOISE_TEX = true;
uniform sampler2D NOISE_TEX : source_color, filter_linear, repeat_enable;
uniform vec2 NOISE_SCALE = vec2(1.0, 1.0);
uniform float STATIC_SPEED = 2.0;
uniform float NOISE_CONTRAST = 1.2;
uniform float GRAIN_STRENGTH = 0.8;
uniform float SCANLINE_INTENSITY = 0.25;
uniform float SCANLINE_SPEED = 1.0;
uniform float JITTER_STRENGTH = 0.004;
uniform float ABERRATION = 0.4;
uniform vec2 PIXEL_RESOLUTION = vec2(320.0, 180.0);

uniform sampler2D SCREEN_TEX : hint_screen_texture;

uniform vec4 BORDER_COLOR : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform float BORDER_LEFT = 0.05;
uniform float BORDER_RIGHT = 0.05;
uniform float BORDER_TOP = 0.05;
uniform float BORDER_BOTTOM = 0.05;
uniform float BORDER_STRENGTH = 0.7;
uniform float BORDER_JIGGLE = 2.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 grid = max(PIXEL_RESOLUTION, vec2(1.0, 1.0));
    vec2 uv_pix = floor(UV * grid) / grid;

    float frame_phase = floor(TIME * 4.0);
    float jitter = (hash21(vec2(frame_phase, 0.0)) * 2.0 - 1.0) * JITTER_STRENGTH;
    vec2 uv_jittered = uv_pix + vec2(jitter, 0.0);

    vec2 n_uv = uv_jittered * NOISE_SCALE + vec2(TIME * STATIC_SPEED, 0.0);
    float n;
    if (USE_NOISE_TEX) {
        n = texture(NOISE_TEX, n_uv).r;
    } else {
        vec2 cell = floor(n_uv * grid);
        n = hash21(cell);
    }
    n = clamp(pow(n, NOISE_CONTRAST), 0.0, 1.0);

    float scan = 0.5 + 0.5 * cos((uv_pix.y * grid.y * 3.14159) + TIME * SCANLINE_SPEED);
    float scan_dark = mix(1.0, 0.75, scan * SCANLINE_INTENSITY);

    vec2 px = 1.0 / grid;
    float ca = ABERRATION * px.x;
    float nr = USE_NOISE_TEX ? texture(NOISE_TEX, n_uv + vec2(+ca, 0.0)).r : hash21(floor((n_uv + vec2(+ca, 0.0)) * grid));
    float ng = n;
    float nb = USE_NOISE_TEX ? texture(NOISE_TEX, n_uv + vec2(-ca, 0.0)).r : hash21(floor((n_uv + vec2(-ca, 0.0)) * grid));
    nr = clamp(pow(nr, NOISE_CONTRAST), 0.0, 1.0);
    nb = clamp(pow(nb, NOISE_CONTRAST), 0.0, 1.0);
    vec3 noise_rgb = vec3(nr, ng, nb);

    vec3 screen_col = texture(SCREEN_TEX, SCREEN_UV).rgb;
    vec3 modulated = screen_col * (0.6 + (n - 0.5) * GRAIN_STRENGTH) * scan_dark * (0.9 + 0.2 * noise_rgb);

    float border_mask = 0.0;
    float jiggle = (hash21(floor(UV * 500.0) + TIME * BORDER_JIGGLE) - 0.5) * 0.1;

    if (UV.x + jiggle < BORDER_LEFT) border_mask = 1.0;
    if (UV.x - jiggle > 1.0 - BORDER_RIGHT) border_mask = 1.0;
    if (UV.y + jiggle < BORDER_TOP) border_mask = 1.0;
    if (UV.y - jiggle > 1.0 - BORDER_BOTTOM) border_mask = 1.0;

    modulated = mix(modulated, BORDER_COLOR.rgb, border_mask * BORDER_STRENGTH);

    COLOR = vec4(modulated, 0.5);
}
