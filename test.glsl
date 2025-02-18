#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;

void main() {
    // vec2 uv = gl_FragCoord.xy / u_resolution.xy; // [0, 1]
    vec2 uv = gl_FragCoord.xy / u_resolution.xy; // [0, 1]
    // uv.x *= u_resolution.x / u_resolution.y;
    uv = uv * 10.0;
    float dist = distance(fract(uv), vec2(0.5));
    gl_FragColor = vec4(vec3(dist), 1.0);
}