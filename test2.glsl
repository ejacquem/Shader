/* Main function, uniforms & utils */
#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

#define PI				3.141592653589793

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]

    // uv *= 1.;

    uv = fract(uv * 5.0) - .5;
    float dist = length(uv * 1000. * (
        dot(uv, vec2(1.0, 0.0)) *
        dot(uv, vec2(0.0, 1.0)) *
        dot(uv, vec2(1.0, 1.0)) *
        dot(uv, vec2(1.0, -1.0))
        ));

    vec3 color = vec3(sin(dist), 0.0, 0.0);

    gl_FragColor = vec4(1.0 - color, 1.0);
}

// 12.57 -> .57
// -1.4 -> .4