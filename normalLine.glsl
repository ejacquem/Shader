precision mediump float;
#extension GL_OES_standard_derivatives : enable

uniform vec2 u_resolution;
varying vec4 v_normal;

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy; // [0, 1]
    
    
    vec3 color = v_normal.xyz;
    vec3 dy = dFdy(color);
    vec3 dx = dFdx(color);
    float epsilon = 0.02;
    if (length(dx) > epsilon || length(dy) > epsilon)
        color = vec3(1.0);
    gl_FragColor = vec4(color, 1.0);
}