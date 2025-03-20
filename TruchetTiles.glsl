/* Main function, uniforms & utils */
#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

bool inBounds(float x, float a, float b) {
    return x >= a && x <= b;
}

float inBoundsf(float x, float a, float b) {
    return float(x >= a && x <= b);
}

float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]

    // uv.y += 0.25;
    uv *= 5.0;
    vec2 pos = fract(uv);

    float g = 0.03; // grid width

    if (!(inBounds(pos.x, g, 1.0-g) && inBounds(pos.y, g, 1.0-g))){
        gl_FragColor = vec4(1,0,0, 1.0);
        return;
    }

    float c1 = 0.4;
    float c2 = 0.6;

    pos.y *= (hash12(floor(uv)) < 0.5) ? -1.0 : 1.0;
    float dist1 = distance(pos, floor(pos));
    float dist2 = distance(pos, ceil(pos));

    vec3 color = vec3(0);
    color += inBoundsf(dist1, 0.45, 0.55);
    color += inBoundsf(dist2, 0.45, 0.55);
    // color += vec3(distance(uv, ceil(uv)));

    gl_FragColor = vec4(color, 1.0);
}