#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const float maxDist = 1000.;
const float epsilon = 0.01;
const vec4 bgColor = vec4(0.14, 0.59, 0.73, 1.0);
const int steps = 200;
const vec3 lightDir = normalize(vec3(0, 1, -0.2));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

// https://www.shadertoy.com/view/3s3GDn
float getGlow(float dist, float radius, float intensity){
	return max(0.0, pow(radius/max(dist, 1e-5), intensity));	
}

float sdfSphere(vec3 pos, vec3 center, float s)
{
  return length(pos - center) - s;
}

float sdfBox(vec3 pos, vec3 box)
{
  vec3 q = abs(pos) - box;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - 0.5;
}

float sdfOctahedron( vec3 p, float s)
{
  p = abs(p);
  return (p.x+p.y+p.z-s)*0.57735027;
}

float sdfHexPrism( vec3 p, vec2 h )
{
  const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
  p = abs(p);
  p.xy -= 2.0*min(dot(k.xy, p.xy), 0.0)*k.xy;
  vec2 d = vec2(
       length(p.xy-vec2(clamp(p.x,-k.z*h.x,k.z*h.x), h.x))*sign(p.y-h.x),
       p.z-h.y );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
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

vec3 angularRepeat(vec3 m, float n) {
   
  float astep  = 2.*3.1415/n; 
  float origin = -astep*0.5;
  float angle  = atan(m.z, m.x) - origin;

  angle = origin + mod(angle, astep);

  float r = length(m.xz);

  return vec3(cos(angle)*r, m.y, sin(angle)*r);
}

const float radius = 3.;
const float subdivision = 8.;
const float bottom_height = 4.;
const float top_height = 3.;
const float top_cut = 0.33;
// https://www.shadertoy.com/view/dsyBDD
float sdfDiamond(vec3 m) {
    m = angularRepeat(m, subdivision);

    vec2 p = m.xy;

    float h1 = bottom_height;
    float h2 = top_height;

    vec2 origin = vec2(radius,0);
    vec2 normal1 = normalize(vec2(h1,-radius));
    vec2 normal2 = normalize(vec2(h2,radius));
    
    float d1 = dot(p-origin, normal1);
    float d2 = dot(p-origin, normal2);    
    
    float d = max(d1, d2);
    float vdist = max(m.y - h2*top_cut, -h1-m.y);
    
    return max(d, vdist);
}

float sdfMap(vec3 pos)
{
    // pos.y += sin(u_time * 2.0);
    vec3 boxSize = vec3(2.0);
    
    // float box = sdfSphere(pos, vec3(0), 3.0);
    float box = sdfBox(pos, boxSize);
    // float box = sdfOctahedron(pos, 3.0);
    // float box = sdfHexPrism(pos, vec2(2,2));
    // float box = sdfDiamond(pos);


    vec3 s1Center = vec3(cos(u_time + 3.14) * 2. ,sin(u_time + 3.14) * 2.,5);
    float s1Size = 3.;
    vec3 s2Center = vec3(cos(u_time) * 2. ,sin(cos(u_time)) * 2.,5);
    float s2Size = 4.;
    float s3 = sdfBox(pos, boxSize);
    pos.zx *= rot2D(u_time * 0.8);
    float s1 = sdfSphere(pos, s1Center, s1Size);
    float s2 = sdfSphere(pos, s2Center, s2Size);


    return opSmoothUnion(opSmoothUnion(s1, s2, 0.5), s3, 0.5);
    
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

float diffuse(vec3 normal, vec3 lightDir){
    return max(dot(normal, lightDir), 0.0);
}

float specular(vec3 rayDir, vec3 normal, vec3 lightDir){
    vec3 reflectDir = reflect(lightDir, normal);  

    float spec = pow(max(dot(rayDir, reflectDir), 0.0), 1280.);
    return spec;
}

const int maxReflection = 5;

vec4 raymarch(vec3 rayOrigin, vec3 rayDir, inout vec3 transmittance, inout vec3 scatteredLight)
{
    float m_dist = maxDist;
    float t = 0.0; // total dist
    vec3 pos;
    float prev_dist;
    vec3 prev_pos;
    int reflexion = 0;
    float refractionLoss = 1.0;

    for (int i = 0; i < steps; i++){
        prev_pos = pos;
        pos = rayOrigin + rayDir * t;
        prev_dist = m_dist;
        m_dist = sdfMap(pos);

        if (sign(prev_dist) != sign(m_dist)){ // ray went through surface if sign flip
            vec3 normal = calculateNormal(pos);
            float dif = diffuse(normal, lightDir);
            float spec = specular(rayDir, normal, lightDir);
            scatteredLight += (5.0 * spec + dif) * refractionLoss;
            if (sign(prev_dist) == -1.0){ // if ray was inside the object, reflect
                reflexion++;
                if (reflexion > maxReflection)
                    break;
                rayDir = reflect(rayDir, normal);
                rayOrigin = prev_pos;
                refractionLoss *= .7;
                t = 0.;
                continue;
            }
        }

        if (m_dist < 0.0){
            float density = 0.05 / refractionLoss;
            // float density = pow(2.0, u_time);

            // vec3 SigmaS = sigmaScattering * density;
            // vec3 SigmaE = sigmaExtinction * density;

            // vec3 S = (lightRay(pos,lightDir) * phase + ambient) * SigmaS;
            vec3 Tr = exp(-vec3(0.4,0.9,0.9) * density * abs(m_dist));
            // vec3 Sint = (S - S * Tr) / SigmaE;
            // scatteredLight += transmittance * Sint * refractionLoss;
            transmittance *= Tr;
        }
        if (m_dist > maxDist /*|| m_dist < epsilon*/) 
            break;

        // if (abs(m_dist) < epsilon) {
        //     t += epsilon;
        // }
        // else {
        //     t += abs(m_dist);
        // }
        t += max(abs(m_dist), epsilon);
    }
    return vec4(pos, m_dist);
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -0.1);
    vec3 rayDir = normalize(vec3(uv, 0.5));

    mx*=4.0;
    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    vec3 scatteredLight = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    vec4 result = raymarch(rayOrigin, rayDir, transmittance, scatteredLight);
    vec3 pos = result.xyz;
    float m_dist = result.w;

    vec3 background = vec3(0);
    float mu = dot(rayDir, lightDir);
    background += getGlow(1.0-mu, 0.00015, 1.0);

    gl_FragColor = vec4(background + transmittance * scatteredLight, 1.0);
}