shader_type sky;

uniform float time_scale : hint_range(0.0, 2.0) = 0.5;
uniform vec3 base_color : source_color = vec3(0.05, 0.05, 0.08);
uniform vec3 slime_color : source_color = vec3(0.15, 0.15, 0.2);
uniform vec3 highlight_color : source_color = vec3(0.3, 0.35, 0.4);
uniform float tendril_density : hint_range(0.0, 10.0) = 4.0;
uniform float tendril_thickness : hint_range(0.0, 1.0) = 0.3;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;
uniform float slime_wetness : hint_range(0.0, 5.0) = 0.7;

// Texture uniforms
uniform sampler2D noise_texture : hint_default_black, filter_linear, repeat_enable;
uniform sampler2D detail_texture : hint_default_black, filter_linear, repeat_enable;
uniform sampler2D highlight_texture : hint_default_black, filter_linear, repeat_enable;
uniform float texture_scale : hint_range(0.1, 5.0) = 1.0;

// Lightning uniforms
uniform vec3 lightning_color : source_color = vec3(0.6, 0.7, 1.0);
uniform float lightning_frequency : hint_range(0.0, 5.0) = 1.0;
uniform float lightning_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float lightning_branch_count : hint_range(1.0, 10.0) = 5.0;
uniform float lightning_thickness : hint_range(0.001, 0.1) = 0.02;

// Hash function for randomness
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Triplanar mapping - samples texture from 3 axes and blends
vec3 triplanar_sample(sampler2D tex, vec3 pos, vec3 normal) {
    vec3 blend = abs(normal);
    blend = normalize(max(blend, 0.00001));
    blend /= (blend.x + blend.y + blend.z);
    
    vec3 xaxis = texture(tex, pos.yz).rgb;
    vec3 yaxis = texture(tex, pos.xz).rgb;
    vec3 zaxis = texture(tex, pos.xy).rgb;
    
    return xaxis * blend.x + yaxis * blend.y + zaxis * blend.z;
}

// Multi-octave texture sampling with triplanar mapping
float fbm_texture(sampler2D tex, vec3 dir, float time) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 3; i++) {
        vec3 pos = dir * texture_scale * frequency;
        vec2 offset = vec2(time * animation_speed * 0.2 * float(i + 1), 
                           time * animation_speed * 0.15 * float(i + 1));
        
        // Apply offset to position
        pos.xy += offset;
        
        value += amplitude * triplanar_sample(tex, pos, dir).r;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// Lightning flash timing
float lightning_flash(float time) {
    float flash_time = time * lightning_frequency;
    float flash_id = floor(flash_time);
    float flash_progress = fract(flash_time);
    
    // Random flash pattern
    float rand = hash(flash_id);
    
    // Only flash sometimes
    if (rand > 0.3) return 0.0;
    
    // Quick flash with multiple strikes
    float intensity = 0.0;
    
    // Main flash
    if (flash_progress < 0.05) {
        intensity = smoothstep(0.0, 0.02, flash_progress) * smoothstep(0.05, 0.03, flash_progress);
    }
    // Secondary flash
    else if (flash_progress > 0.1 && flash_progress < 0.13) {
        intensity = smoothstep(0.1, 0.11, flash_progress) * smoothstep(0.13, 0.12, flash_progress) * 0.6;
    }
    // Tertiary flash (sometimes)
    else if (rand > 0.7 && flash_progress > 0.18 && flash_progress < 0.2) {
        intensity = smoothstep(0.18, 0.185, flash_progress) * smoothstep(0.2, 0.195, flash_progress) * 0.4;
    }
    
    return intensity;
}

// Generate lightning bolts
float lightning_bolt(vec3 dir, float time) {
    float bolt = 0.0;
    float flash_time = time * lightning_frequency;
    float flash_id = floor(flash_time);
    
    // Generate multiple lightning branches
    for (float i = 0.0; i < lightning_branch_count; i++) {
        // Random start and end points for this branch
        float seed = flash_id + i * 123.456;
        vec2 start = vec2(hash(seed) * 2.0 - 1.0, hash(seed + 1.0) * 0.5 + 0.3);
        vec2 end = vec2(hash(seed + 2.0) * 2.0 - 1.0, hash(seed + 3.0) * 0.5 - 1.0);
        
        // Convert direction to 2D sky coordinates
        vec2 sky_pos = vec2(atan(dir.z, dir.x) / 3.14159, dir.y);
        
        // Distance to lightning bolt line
        vec2 bolt_dir = end - start;
        float bolt_length = length(bolt_dir);
        bolt_dir = normalize(bolt_dir);
        
        vec2 to_pos = sky_pos - start;
        float proj = dot(to_pos, bolt_dir);
        proj = clamp(proj, 0.0, bolt_length);
        
        vec2 closest = start + bolt_dir * proj;
        float dist = length(sky_pos - closest);
        
        // Add jagged variation using noise
        float jagged = triplanar_sample(noise_texture, dir * 10.0 + vec3(time * 2.0), dir).r;
        dist += jagged * 0.02;
        
        // Create bolt with glow
        float bolt_core = smoothstep(lightning_thickness * 2.0, lightning_thickness * 0.5, dist);
        float bolt_glow = smoothstep(lightning_thickness * 8.0, lightning_thickness, dist) * 0.3;
        
        bolt += bolt_core + bolt_glow;
    }
    
    return clamp(bolt, 0.0, 1.0);
}

float tendrils(vec3 dir, float time) {
    // Use triplanar mapping for seamless pattern
    float pattern = fbm_texture(noise_texture, dir, time);
    
    // Add detail layer
    vec3 detail_pos = dir * texture_scale * 2.0;
    detail_pos.xy += vec2(time * animation_speed * 0.3, -time * animation_speed * 0.2);
    pattern += triplanar_sample(detail_texture, detail_pos, dir).r * 0.5;
    
    // Create sharp tendril edges
    float tendrils = smoothstep(0.4 - tendril_thickness, 0.4, pattern);
    tendrils *= smoothstep(0.4 + tendril_thickness * 2.0, 0.4 + tendril_thickness, pattern);
    
    return tendrils;
}

float slime_highlight(vec3 dir, float time) {
    vec3 pos = dir * texture_scale * 0.5;
    
    // Animate the highlight texture
    vec2 offset = vec2(sin(time * animation_speed * 0.5) * 0.1,
                       cos(time * animation_speed * 0.3) * 0.1);
    pos.xy += offset;
    
    float highlight = triplanar_sample(highlight_texture, pos, dir).r;
    highlight = pow(highlight, 3.0);
    
    return highlight * slime_wetness;
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    float time = TIME * time_scale;
    
    // Base slimy black color
    vec3 color = base_color;
    
    // Add tendril patterns
    float tendril_pattern = tendrils(dir, time);
    color = mix(color, slime_color, tendril_pattern);
    
    // Add glossy slime highlights
    float highlight = slime_highlight(dir, time);
    color = mix(color, highlight_color, highlight);
    
    // Add some depth variation based on view angle
    float edge_darkness = pow(1.0 - abs(dir.y), 2.0);
    color *= 1.0 + edge_darkness * 0.3;
    
    // Add subtle animated distortion at edges
    vec3 dist_pos = dir * texture_scale * 5.0;
    dist_pos.xy += vec2(time * animation_speed * 0.1);
    float edge_distortion = triplanar_sample(noise_texture, dist_pos, dir).r;
    edge_distortion *= edge_darkness;
    color += edge_distortion * 0.05;
    
    // Add lightning
    float flash = lightning_flash(TIME);
    float bolt = lightning_bolt(dir, TIME);
    
    // Apply lightning to sky
    color += lightning_color * bolt * flash * lightning_intensity;
    
    // Add ambient flash illumination
    color += lightning_color * flash * 0.15 * lightning_intensity;
    
    COLOR = color;
}