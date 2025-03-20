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
const vec3 lightDir = normalize(vec3(1.2, 1, -1.1));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

float sdfSphere(vec3 pos, vec3 center, float s)
{
  return length(pos - center) - s;
}

float sdfBox(vec3 pos, vec3 box)
{
  vec3 q = abs(pos) - box;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdTriPrism( vec3 p, vec2 h )
{
  vec3 q = abs(p);
  return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

mat2 rot2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

float sdfMap(vec3 pos)
{
    vec3 center = vec3(5.0);
    
    // float box = sdfSphere(pos, vec3(0), 10.0);
    float c;
    vec3 p = pos;
    p.xz *= rot2D(radians(60.));
    p.xy *= rot2D(radians(u_time * 20.0));
    c = sdTriPrism(p, vec2(5.0,5.0));

    return c;
}

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
    float eps = 0.0001;
    return clamp((sdfMap(pos+eps*lightDir)-sdfMap(pos))/eps,0.0,1.0);
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDir)
{
    float m_dist = maxDist;
    float t = 0.0; // total dist
    vec3 pos;

    for (int i = 0; i < steps; i++){
        pos = rayOrigin + rayDir * t;
        m_dist = sdfMap(pos);

        if (m_dist > maxDist || m_dist < epsilon) 
            break;

        t += m_dist;
    }
    return vec4(pos, m_dist);
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -20);
    vec3 rayDir = normalize(vec3(uv, 1.0));

    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    vec4 result = raymarch(rayOrigin, rayDir);
    vec3 pos = result.xyz;
    float m_dist = result.w;

    vec3 color;
    if (m_dist > maxDist)
        color = bgColor.xyz;
    else {
        float diffuse = calculateDiffuse(pos);

        color = lightColor * diffuse + ambientColor;
        // color *= exp( -0.1*t ); // fog 
    }
    gl_FragColor = vec4(color, 1.0);
}