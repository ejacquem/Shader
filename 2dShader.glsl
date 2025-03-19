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

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]

    vec2 p = fract(uv * 10.0) - 0.5;
    p *= 10.0;

    float dist = length(p);
    dist += abs(0.01
        * dot(p, vec2(0.,1.))
        * dot(p, vec2(1.,0.))
        * dot(p, (vec2(1.,1.)))
        * dot(p, normalize(vec2(1.,-1.)))
        // * dot(p, vec2(cos(radians(22.5)),sin(radians(22.5))))
        // * dot(p, vec2(cos(radians(67.5)),sin(radians(67.5))))
        // * dot(p, vec2(cos(radians(-22.5)),sin(radians(-22.5))))
        // * dot(p, vec2(cos(radians(-67.5)),sin(radians(-67.5))))
        );
    float offset = (uv.x * 5.0) - (uv.y * 5.0);
    float c = sin(dist + u_time + offset);

    vec3 color = vec3(c * palette(c*c + u_time * 0.1 + offset * 0.5, PAL1)); 

    gl_FragColor = vec4(1.0 - color, 1.0);
}