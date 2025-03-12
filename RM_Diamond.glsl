#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const float maxDist = 1000.;
const float epsilon = 0.01;
const vec4 bgColor = vec4(0.14, 0.59, 0.73, 1.0);
const int steps = 2000;
const vec3 lightDir = normalize(vec3(1, 1, 1));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

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

// https://www.shadertoy.com/view/3s3GDn
float getGlow(float dist, float radius, float intensity){
	return max(0.0, pow(radius/max(dist, 1e-5), intensity));	
}

mat2 rot2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

float sdfOctahedron( vec3 p, float s)
{
  p = abs(p);
  return (p.x+p.y+p.z-s)*0.57735027;
}

float sdfSphere(vec3 pos, float s)
{
  return length(pos) - s;
}

float sdfBox(vec3 pos, vec3 box)
{
  vec3 q = abs(pos) - box;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdPlane(vec3 p, vec3 n, float h)
{
  // n must be normalized
  return dot(p,n) + h;
}

// return the given sdf cut by the plane
float sdfPlaneCut(float sdf, vec3 p, vec3 n, float h)
{
  // n must be normalized
  return max(sdf, dot(p,n) + h);
}

// #define N2 0.707106781 // 1/sqrt(2)
#define N2 1./sqrt(2.)
#define N3 1./sqrt(3.)
#define N5 1./sqrt(5.)
#define _2N5 2./sqrt(5.)
#define _2N2 2./sqrt(2.)

float sdFacetedGem(vec3 p) {
    p.y = abs(p.y);
    // float d = sdfOctahedron(p, 10.0);
    float d = sdfSphere(p, 10.0);
    float h;
    d = sdfPlaneCut(d, p, vec3(0, -1, 0), -2.0);  // bot cut
    d = sdfPlaneCut(d, p, vec3(0, +1, 0), -2.0);  // top cut
    d = sdfPlaneCut(d, p, vec3(-1, 0, 0), -4.0);  // Left cut
    d = sdfPlaneCut(d, p, vec3(+1, 0, 0), -4.0);  // Right cut
    d = sdfPlaneCut(d, p, vec3(0, 0, -1), -4.0);  // Front cut
    d = sdfPlaneCut(d, p, vec3(0, 0, +1), -4.0);  // Back cut

    h = -3.7;
    d = sdfPlaneCut(d, p, vec3(+N2, +N2, 0), h);  // topRight cut
    d = sdfPlaneCut(d, p, vec3(-N2, +N2, 0), h);  // topRight cut
    d = sdfPlaneCut(d, p, vec3(0, +N2, +N2), h);  // topBack cut
    d = sdfPlaneCut(d, p, vec3(0, +N2, -N2), h);  // topFront cut

    h = -4.7;
    d = sdfPlaneCut(d, p, vec3(-0.5, N2, +0.5), h);  // topRight corner cut
    d = sdfPlaneCut(d, p, vec3(+0.5, N2, +0.5), h);  // topRight corner cut
    d = sdfPlaneCut(d, p, vec3(-0.5, N2, -0.5), h);  // topRight corner cut
    d = sdfPlaneCut(d, p, vec3(+0.5, N2, -0.5), h);  // topRight corner cut

    h = -5.4;
    d = sdfPlaneCut(d, p, vec3(-N2, 0, +N2), h);  // Left cut
    d = sdfPlaneCut(d, p, vec3(+N2, 0, +N2), h);  // Left cut
    d = sdfPlaneCut(d, p, vec3(-N2, 0, -N2), h);  // Left cut
    d = sdfPlaneCut(d, p, vec3(+N2, 0, -N2), h);  // Left cut

    h = -3.1;
    d = sdfPlaneCut(d, p, vec3(+N5, +_2N5, 0), h);  // topRight cut
    d = sdfPlaneCut(d, p, vec3(-N5, +_2N5, 0), h);  // topRight cut
    d = sdfPlaneCut(d, p, vec3(0, +_2N5, +N5), h);  // topBack cut
    d = sdfPlaneCut(d, p, vec3(0, +_2N5, -N5), h);  // topFront cut
    // d = max(d, -sdPlane(p, vec3(0, -1, 0), -0.2)); // Bottom cut
    return d;
}

#define N normalize

float sdfCustomGem(vec3 p){
    // return sdFacetedGem(p);

    p.xz = abs(p.xz);
    // float d = sdfOctahedron(p, 10.0);
    // float d = sdfBox(p, vec3(5.0));
    float d = sdfSphere(p, 10.0);
    float h;
    d = sdfPlaneCut(d, p, vec3(0, +1, 0), -2.0);  // top cut
    d = sdfPlaneCut(d, p, N(vec3(1, 2, 2)), -5.0);  // top diag Left cut
    d = sdfPlaneCut(d, p, N(vec3(2, 2, 1)), -5.0);  // top diag right cut
    d = sdfPlaneCut(d, p, N(vec3(1, 3, 1)), -3.35);  // top front cut
    d = sdfPlaneCut(d, p, N(vec3(0, 3, 1)), -3.);  // top left cut
    d = sdfPlaneCut(d, p, N(vec3(1, 3, 0)), -3.0);  // top right cut
    // d = sdfPlaneCut(d, p, N(vec3(2, 3, 1)), -3.5);  // top front cut

    //bottom
    d = sdfPlaneCut(d, p, N(vec3(1, -1.8, 2.5)), -5.2);
    d = sdfPlaneCut(d, p, N(vec3(2.5, -1.8, 1)), -5.2);
    d = sdfPlaneCut(d, p, N(vec3(2., -2.5, 2.0)), -5.2);
    // d = sdfPlaneCut(d, p, N(vec3(1, -3.0, 2.5)), -5.2);
    return d;
}

float sdfMap(vec3 pos)
{
    return sdfCustomGem(pos);
    // pos.y += sin(u_time * 2.0);
    // pos.zx *= rot2D(u_time * 0.08);
    vec3 p = pos;

    float offset = 3.5; 

    float s1 = sdfOctahedron(p, 5.);
    // s1 = max(s1, -sdfOctahedron(p, 1.));
    // return s1;

    p = pos;
    p.y += offset;
    float s2 = sdfOctahedron(p, 2.);
    p = pos;
    p.y -= offset;
    float s3 = sdfOctahedron(p, 2.);

    return min(min(s1, s2),s3);

    p = pos;
    p.x += offset;
    float s4 = sdfOctahedron(p, 2.);
    p = pos;
    p.x -= offset;
    float s5 = sdfOctahedron(p, 2.);
    p = pos;
    p.z += offset;
    float s6 = sdfOctahedron(p, 2.);
    p = pos;
    p.z -= offset;
    float s7 = sdfOctahedron(p, 2.);

    return min(min(min(min(min(min(s1, s2),s3), s4), s5), s6), s7);
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

float specular(vec3 rayDir, vec3 normal, vec3 lightDir, float po){
    vec3 reflectDir = reflect(lightDir, normal);  

    float spec = pow(max(dot(rayDir, reflectDir), 0.0), po);
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
    bool first = true;

    vec3 SigmaE = vec3(0.1922, 0.7804, 0.749);
    // vec3 SigmaE = 1.0 - palette(rayDir.x, PAL7);
    // vec3 SigmaE = vec3(1.);

    for (int i = 0; i < steps; i++){
        prev_pos = pos;
        pos = rayOrigin + rayDir * t;
        prev_dist = m_dist;
        m_dist = sdfMap(pos);

        if (m_dist < 0.0){
            float density = 0.05 / refractionLoss;
            vec3 Tr = exp(-SigmaE * density * abs(m_dist));
            transmittance *= Tr;
        }

        if (sign(prev_dist) != sign(m_dist)){ // ray went through surface if sign flip
            vec3 normal = calculateNormal(pos);
            float dif = diffuse(normal, lightDir) * 1.0;
            if (prev_dist < 0.){ // if ray was inside the object, reflect
                reflexion++;
                if (reflexion > maxReflection)
                    break;
                rayDir = reflect(rayDir, normal);
                rayOrigin = prev_pos;
                t = 0.;
                // SigmaE = palette(rayDir.x, PAL2);
                refractionLoss *= .65;
                continue;
            }
            else if (first){
                first = false;
                rayDir = refract(rayDir, normal, 0.95);

                rayOrigin = prev_pos;
                t = 0.;
                // float spec = specular(rayDir, normal, lightDir, 100.) * 10.0;
                // scatteredLight += spec + dif;
            }
            float spec = specular(rayDir, normal, lightDir, 100.) * 10.0;
            scatteredLight += (spec + dif) * refractionLoss * transmittance;
        }

        if (m_dist > maxDist /*|| m_dist < epsilon*/) 
            break;

        t += max(abs(m_dist), epsilon);
    }
    return vec4(pos, m_dist);
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -15.);
    vec3 rayDir = normalize(vec3(uv, 1.0));

    mx*=4.0;
    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    vec3 scatteredLight = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    vec4 result = raymarch(rayOrigin, rayDir, transmittance, scatteredLight);

    vec3 background = vec3(.5);
    float mu = dot(rayDir, lightDir);
    background += getGlow(1.0-mu, 0.00015, .5);

    vec3 color = background;
    if (transmittance.r < 1.0)
        color = transmittance + (scatteredLight * 0.05);

    gl_FragColor = vec4(color, 1.0);
}