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
const vec3 lightDir = vec3(0,1,0);
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

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

    return opSmoothUnion(ground, opSmoothUnion(s1, s2, 0.5), 0.5);
}

// vec3 calculateNormal(vec3 p) {
//     float epsilon = 0.001;
//     vec3 ex = vec3(epsilon, 0.0, 0.0);
//     vec3 ey = vec3(0.0, epsilon, 0.0);
//     vec3 ez = vec3(0.0, 0.0, epsilon);
    
//     float dx = sdfMap(p + ex) - sdfMap(p - ex);
//     float dy = sdfMap(p + ey) - sdfMap(p - ey);
//     float dz = sdfMap(p + ez) - sdfMap(p - ez);
    
//     return normalize(vec3(dx, dy, dz));
// }

vec3 calculateNormal(vec3 pos)
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.001;
    return normalize( e.xyy*sdfMap( pos + e.xyy ) + 
					  e.yyx*sdfMap( pos + e.yyx ) + 
					  e.yxy*sdfMap( pos + e.yxy ) + 
					  e.xxx*sdfMap( pos + e.xxx ) );
}

float calculateDiffuse(vec3 pos)
{
    float eps = 0.001;
    return clamp((sdfMap(pos+eps*lightDir)-sdfMap(pos))/eps,0.0,1.0);
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]

    vec3 rayOrigin = vec3(0, 0, -5);
    vec3 rayDir = normalize(vec3(uv, 1));

    float m_dist = maxDist;
    float t = 0.0; // total dist
    vec3 color;
    vec3 pos;

    for (int i = 0; i < steps; i++){
        pos = rayOrigin + rayDir * t;
        m_dist = sdfMap(pos);

        // color = vec3(i) / float(steps);

        if (m_dist > maxDist || m_dist < epsilon) break;

        t += m_dist;
    }
    color = 1.0 - vec3(t / 15.0);
    vec3 N = calculateNormal(rayOrigin + rayDir * t);
    float diffuse = max(dot(N, lightDir), 0.0); // angle between lightDir and the normal
    diffuse = clamp(diffuse, 0., 1.);
    diffuse = calculateDiffuse(pos);
    color = lightColor * diffuse + ambientColor;
    // color *= exp( -0.1*t ); // fog 
    gl_FragColor = vec4(color, 1.0);
    if (m_dist > maxDist || m_dist > epsilon * 10.)
        gl_FragColor = bgColor;
}