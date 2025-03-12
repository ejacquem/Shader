/* Main function, uniforms & utils */
#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;

#define PAL1 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67)
#define PAL2 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.10,0.20) 
#define PAL3 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.3,0.20,0.20)
#define PAL4 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,0.5),vec3(0.8,0.90,0.30)
#define PAL5 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,0.7,0.4),vec3(0.0,0.15,0.20)
#define PAL6 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25)
#define PAL7 vec3(0.8,0.5,0.4),vec3(0.2,0.4,0.2),vec3(2.0,1.0,1.0),vec3(0.0,0.25,0.25)
// https://iquilezles.org/articles/palettes/
// cosine based palette, 4 vec3 params
vec3 palette(float t,vec3 a,vec3 b,vec3 c,vec3 d )
{
    return a + b*cos( 6.283185*(c*t+d) );
}

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