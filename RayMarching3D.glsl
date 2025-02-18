#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const float maxDist = 100.;
const float epsilon = 0.01;
const vec4 bgColor = vec4(0.14, 0.59, 0.73, 1.0);
const int steps = 200;

float sdfSphere(vec3 pos, vec3 center, float s)
{
  return length(pos - center) - s;
}

float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

float sdfMap(vec3 pos)
{
    vec3 s1Center = vec3(cos(u_time + 3.14) * 2. ,sin(u_time + 3.14) * 2.,5);
    float s1Size = 3.;
    vec3 s2Center = vec3(cos(u_time) * 2. ,sin(cos(u_time)) * 2.,5);
    float s2Size = 3.;
    float s1 = sdfSphere(pos, s1Center, s1Size);
    float s2 = sdfSphere(pos, s2Center, s2Size);

    float ground = pos.y + 2.0;

    return min(ground, opSmoothUnion(s1, s2, 0.5));
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    // vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0; // [-1; 1]
    // uv.x *= u_resolution.x / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -3);
    vec3 rayDir = normalize(vec3(uv, 1));

    float m_dist = maxDist;
    float t = 0.0; // total dist
    vec3 color;

    for (int i = 0; i < steps; i++){
        vec3 pos = rayOrigin + rayDir * t;
        m_dist = sdfMap(pos);

        // color = vec3(i) / float(steps);

        if (m_dist > maxDist || m_dist < epsilon) break;

        t += m_dist;
    }
    color = 1.0 - vec3(t / 15.0);
    gl_FragColor = vec4(color, 1.0);
    if (m_dist > maxDist || m_dist > epsilon * 10.)
        gl_FragColor = bgColor;
}