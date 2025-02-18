precision mediump float;

uniform vec2 u_resolution;
varying vec4 v_normal;

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy; // [0, 1]
    gl_FragColor = vec4(v_normal);
}