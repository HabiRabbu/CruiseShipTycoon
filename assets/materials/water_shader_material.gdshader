shader_type spatial;

// Uniforms for three different wave sets
uniform vec2 direction1 = vec2(1.0, 0.2);
uniform vec2 direction2 = vec2(0.7, 0.7);
uniform vec2 direction3 = vec2(-0.4, 1.0);
uniform vec2 direction5 = vec2(-0.8, 1.0);
uniform vec2 direction6 = vec2(-0.1, 5);

uniform float speed1 = 1.0;
uniform float speed2 = 0.7;
uniform float speed3 = 1.2;

uniform float steepness1 = 0.8;
uniform float steepness2 = 0.6;
uniform float steepness3 = 0.7;

uniform float amplitude1 = 0.5;
uniform float amplitude2 = 0.3;
uniform float amplitude3 = 0.4;

uniform float wavelength1 = 10.0;
uniform float wavelength2 = 15.0;
uniform float wavelength3 = 8.0;


uniform vec4 albedo : source_color = vec4(0, 0.321569, 0.431373, 1);
uniform sampler2D texture_normal : source_color;
uniform float roughness = 0.02;
uniform float metallic = 0.0;
uniform vec4 edge_color : source_color = vec4(1, 1, 1, 1);
uniform float edge_scale = 0.1;
uniform float beers_law = 2.0;

varying mat3 v_tbn;
varying vec3 world_pos;

// Gerstner wave calculation function
vec3 gerstner(vec3 vertex, vec2 direction, float time, float speed, float steepness, float amplitude, float wavelength) {
    float k = 2.0 * PI / wavelength;  // Wavenumber
    float phase = speed * k * time;
    float theta = k * dot(normalize(direction), vertex.xz) + phase;

    float qx = steepness * k * amplitude * cos(theta);
    float qz = steepness * k * amplitude * sin(theta);
    float displaced_x = vertex.x + qx * direction.x;
    float displaced_z = vertex.z + qx * direction.y;
    float displaced_y = vertex.y + amplitude * sin(theta);

    return vec3(displaced_x, displaced_y, displaced_z);
}

// Normal calculation for the Gerstner wave
vec3 gerstner_normal(vec3 vertex, vec2 direction, float time, float speed, float steepness, float amplitude, float wavelength) {
    float k = 2.0 * PI / wavelength;
    float phase = speed * k * time;
    float theta = k * dot(normalize(direction), vertex.xz) + phase;

    float cos_theta = cos(theta);
    float sin_theta = sin(theta);
    float factor = steepness * k * amplitude;

    vec3 normal;
    normal.x = -direction.x * factor * cos_theta;
    normal.z = -direction.y * factor * cos_theta;
    normal.y = 1.0 - factor * sin_theta;

    return normalize(normal);
}

// Vertex shader to apply multiple waves
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; // Transform to world space
	vec3 T = normalize(TANGENT.xyz);
    vec3 B = normalize(BINORMAL.xyz);
    vec3 N = normalize(NORMAL);

    // Construct the TBN matrix
    v_tbn = mat3(T, B, N);

    vec3 vertex = VERTEX;
    vec3 normal = vec3(0.0, 1.0, 0.0);

    // Apply multiple waves and accumulate their effects
    vertex = gerstner(vertex, direction1, TIME, speed1, steepness1, amplitude1, wavelength1);
    normal += gerstner_normal(vertex, direction1, TIME, speed1, steepness1, amplitude1, wavelength1);

    vertex = gerstner(vertex, direction2, TIME, speed2, steepness2, amplitude2, wavelength2);
    normal += gerstner_normal(vertex, direction2, TIME, speed2, steepness2, amplitude2, wavelength2);

    vertex = gerstner(vertex, direction3, TIME, speed3, steepness3, amplitude3, wavelength3);
    normal += gerstner_normal(vertex, direction3, TIME, speed3, steepness3, amplitude3, wavelength3);

    VERTEX = vertex;
    NORMAL = normalize(normal); // Normalize the final normal

}

void fragment() {
    vec3 view_dir = normalize(-VERTEX);
	vec3 normal_map_normal = texture(texture_normal, UV).rgb;
    normal_map_normal = 2.0 * normal_map_normal - 1.0; // Convert from [0,1] to [-1,1]

    // Normal mapping
    vec3 base_normal = vec3(0.0, 1.0, 0.0);
    vec3 new_texture_normal = texture(texture_normal, UV).rgb * 2.0 - 1.0;
	vec3 normal = normalize(v_tbn * normal_map_normal);

    // Fresnel effect
	float fresnel_effect = pow(1.0 - max(dot(view_dir, normal), 0.0), 3.0);
    vec3 base_color = albedo.rgb;
    vec3 foam_color = vec3(1.0, 1.0, 1.0);
    vec3 color_mix = mix(base_color, foam_color, fresnel_effect * 0.5);

    // Depth-based color attenuation
	vec3 cam_pos = CAMERA_POSITION_WORLD;
    float depth = length(cam_pos - world_pos);
    float attenuation = exp(-pow(depth * 0.01, 2.0));
    color_mix *= attenuation;

    ALBEDO = color_mix;
    ROUGHNESS = roughness;
    METALLIC = metallic;
}