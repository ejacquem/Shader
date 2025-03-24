#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const float maxDist = 100.;
const float epsilon = 0.001;
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

float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}
// IQ's smooth minium function. 
float smin(float a, float b , float s){
    
    float h = clamp( 0.5 + 0.5*(b-a)/s, 0. , 1.);
    return mix(b, a, h) - h*(1.0-h)*s;
}
mat2 r2(float th){ vec2 a = sin(vec2(1.5707963, 0) + th); return mat2(a, -a.y, a.x); }
float Mobius(vec3 p){
    const float toroidRadius = 1.25; // The object's disc radius.
    float polRot = floor(4.)/4.; // Poloidal rotations.
    float a = atan(p.z, p.x);
    
    p.xz *= r2(a);
    p.x -= toroidRadius;
    p.xy *= r2(a*polRot + u_time * 0.5);  // Twisting about the poloidal direction (controlled by "polRot) as we sweep.
    
    p = abs(abs(p) - .2); // Change this to "p = abs(p)," and you'll see what it does.
    return sdfSphere(p, vec3(0), 0.25);
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
    
    float box = Mobius(pos);
    
    return box;
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

    vec3 rayOrigin = vec3(0, 0, -3);
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