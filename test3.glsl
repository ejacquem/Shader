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
    uv = uv * 0.5 + 0.5;

    vec3 color = vec3(uv.x, 0,0) * 2.0;

    gl_FragColor = vec4(color, 1.0);
}

// 12.57 -> .57
// -1.4 -> .4