shader_type spatial;

// Uniforms for wave parameters
uniform vec2 direction[3];
uniform float speed[3];
uniform float steepness[3];
uniform float amplitude[3];
uniform float wavelength[3];

// Wave roughness and randomness control
uniform float roughness_factor;  // Control via slider from 0 to 1

// Visual and physical properties
uniform vec4 albedo : source_color = vec4(0, 0.321569, 0.431373, 1);
uniform sampler2D texture_normal : source_color;
uniform float roughness = 0.02;
uniform float metallic = 0.0;

varying mat3 v_tbn;
varying vec3 world_pos;

// Function to get noise-based offset
float get_noise(vec3 position, float scale) {
    return fract(sin(dot(position.xyz, vec3(12.9898, 78.233, 54.53))) * 43758.5453) * scale;
}

// Gerstner wave calculation function
vec3 gerstner_wave(vec3 vertex, vec2 wave_direction, float time, float wave_speed, float wave_steepness, float wave_amplitude, float wave_wavelength) {
    float k = 2.0 * PI / wave_wavelength;
    float phase = wave_speed * k * time;
    float theta = k * dot(normalize(wave_direction), vertex.xz) + phase;

    float qx = wave_steepness * k * wave_amplitude * cos(theta);
    float qz = wave_steepness * k * wave_amplitude * sin(theta);
    float displaced_x = vertex.x + qx * wave_direction.x;
    float displaced_z = vertex.z + qz * wave_direction.y;
    float displaced_y = vertex.y + wave_amplitude * sin(theta);

    return vec3(displaced_x, displaced_y, displaced_z);
}

// Normal calculation for the Gerstner wave
vec3 gerstner_normal(vec3 vertex, vec2 wave_direction, float time, float wave_speed, float wave_steepness, float wave_amplitude, float wave_wavelength) {
    float k = 2.0 * PI / wave_wavelength;
    float phase = wave_speed * k * time;
    float theta = k * dot(normalize(wave_direction), vertex.xz) + phase;

    float cos_theta = cos(theta);
    float sin_theta = sin(theta);
    float factor = wave_steepness * k * wave_amplitude;

    vec3 normal;
    normal.x = -wave_direction.x * factor * cos_theta;
    normal.z = -wave_direction.y * factor * cos_theta;
    normal.y = 1.0 - factor * sin_theta;

    return normalize(normal);
}

// Vertex shader to apply multiple waves with noise
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; // Transform to world space
    vec3 T = normalize(TANGENT.xyz);
    vec3 B = normalize(BINORMAL.xyz);
    vec3 N = normalize(NORMAL);
    v_tbn = mat3(T, B, N);

    vec3 vertex = VERTEX;
    vec3 normal = vec3(0.0, 1.0, 0.0);
    vec2 uv = UV;
	vec3 position_noise = world_pos * 0.1;

    // Apply multiple waves with noise and accumulate their effects
 	for (int i = 0; i < 3; i++) {
        float noise_amp = get_noise(position_noise + vec3(float(i) * 123.4), 1.0); // Unique noise per wave set, casting i to float
        vec2 new_direction = direction[i] + vec2(get_noise(position_noise + vec3(float(i) * 76.5), 0.2), get_noise(position_noise + vec3(float(i) * 92.7), 0.2));
        float new_amplitude = amplitude[i] + noise_amp * roughness_factor;
        vertex = gerstner_wave(vertex, new_direction, TIME, speed[i], steepness[i], new_amplitude, wavelength[i]);
        normal += gerstner_normal(vertex, new_direction, TIME, speed[i], steepness[i], new_amplitude, wavelength[i]);
    }

    VERTEX = vertex;
    NORMAL = normalize(normal); // Normalize the final normal
}

void fragment() {
    vec3 view_dir = normalize(-VERTEX);
    vec3 normal_map_normal = texture(texture_normal, UV).rgb;
    normal_map_normal = 2.0 * normal_map_normal - 1.0;
    vec3 normal = normalize(v_tbn * normal_map_normal);

    // Use proper lighting calculations
    float fresnel_effect = pow(1.0 - max(dot(view_dir, normal), 0.0), 3.0);
    vec3 base_color = albedo.rgb;
    vec3 foam_color = vec3(1.0, 1.0, 1.0);
    vec3 color_mix = mix(base_color, foam_color, fresnel_effect * 0.5);

    float depth = length(CAMERA_POSITION_WORLD - world_pos);
    float attenuation = exp(-pow(depth * 0.01, 2.0));
    color_mix *= attenuation;

    ALBEDO = color_mix;
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
