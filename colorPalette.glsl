/* Main function, uniforms & utils */
#ifdef GL_ES
    precision mediump float;
#endif

#include "Palette.glsl"

uniform vec2 u_resolution;

void main() {
    vec2 p = gl_FragCoord.xy / u_resolution.xy;
    vec3                col = palette( p.x, PAL1);
    if( p.y>(1.0/7.0) ) col = palette( p.x, PAL2);
    if( p.y>(2.0/7.0) ) col = palette( p.x, PAL3);
    if( p.y>(3.0/7.0) ) col = palette( p.x, PAL4);
    if( p.y>(4.0/7.0) ) col = palette( p.x, PAL5);
    if( p.y>(5.0/7.0) ) col = palette( p.x, PAL6);
    if( p.y>(6.0/7.0) ) col = palette( p.x, PAL7);

    gl_FragColor = vec4(col, 1.0);
}