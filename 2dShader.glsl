/* Main function, uniforms & utils */
#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

#define PAL1 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67)

vec3 palette(float t,vec3 a,vec3 b,vec3 c,vec3 d )
{
    return a + b*cos( 6.283185*(c*t+d) );
}

vec2 vecDeg(float angle){
    return vec2(cos(radians(angle)), sin(radians(angle)));
}

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]

    vec2 p = (fract(uv * 10.) - 0.5) * 10.;

    float time = u_time;

    float dist = length(p);
    p = abs(p); // mirror x and y axis
    dist += abs(0.01
        * dot(p, vecDeg(0.))
        * dot(p, vecDeg(-22.5))
        * dot(p, vecDeg(-45.0))
        * dot(p, vecDeg(-67.5))
        * dot(p, vecDeg(-90.0))
        * dot(p, vecDeg(45.)) // this one shouldn't be needed but creates cool decorations
        );
    float offset = (uv.x - uv.y) * 5.0;
    float c = sin(dist + time + offset);

    vec3 color = vec3(c * palette(c + time * 0.1 + offset * 0.5, PAL1)); 

    gl_FragColor = vec4(1.0 - color, 1.0);
}