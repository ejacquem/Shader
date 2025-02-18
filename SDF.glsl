#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

vec3 bgColor = vec3(0.0);
vec3 frontColor = vec3(1.0, 0.3, 0.3);

float sdfCircle(vec2 pos, vec2 center, float r)
{
    return length(pos - center) - r;
}

float sdfCircleEmpty(vec2 pos, vec2 center, float r)
{
    return abs(length(pos - center) - r);
}

float sdfBox(vec2 pos, vec2 center, in vec2 b)
{
    vec2 d = abs(pos - center)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

// #define mx coord(u_mouse)

void main() {
    vec2 uv = gl_FragCoord.xy; // [0, 1]

    vec2 pos_c1 = vec2(u_resolution * 0.5);
    float r_c1 = 100.0;
    vec2 pos_c2 = vec2(100, 200);
    float r_c2 = 50.0;
    vec2 pos_b1 = vec2(50, 25);
    vec2 s_b1 = vec2(300, 200);
    // vec2 mx = (vec2(sin(u_time), cos(u_time)) * 0.5 + 0.5) * 700.0;
    vec2 mx = u_mouse;

    float c = sdfCircle(uv, pos_c1, r_c1);
    float c1 = sdfCircle(uv, pos_c2, r_c2);
    float b1 = sdfBox(uv, s_b1, pos_b1);
    float mouseSdf = sdfCircle(uv, mx, 2.0);

    float distc = sdfCircle(mx, pos_c1, r_c1);
    float distc1 = sdfCircle(mx, pos_c2, r_c2);
    float distb1 = sdfBox(mx, s_b1, pos_b1);
    float m_dist = min(min(distc, distc1), distb1);
    float c3 = sdfCircleEmpty(uv, mx, m_dist);
    
    float t = min(min(min(c, mouseSdf), c3), c1);
    t = min(t, b1);
    t = clamp(t, 0.0, 1.0);
    gl_FragColor = vec4(mix(frontColor, bgColor, t), 1.0);
}