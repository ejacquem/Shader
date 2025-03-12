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
const vec3 lightDir = normalize(vec3(1, 1, 1));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

// https://iquilezles.org/articles/palettes/
// cosine based palette, 4 vec3 params
vec3 palette( in float t)
{
    vec3 a = vec3(0.5, 0.5, 0.5), 
        b = vec3(0.5, 0.5, 0.5), 
        c = vec3(1.0, 1.0, 1.0), 
        d = vec3(0.00, 0.33, 0.67);
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

float sdfOctahedron( vec3 p, float s)
{
  p = abs(p);
  return (p.x+p.y+p.z-s)*0.57735027;
}

float sdfMap(vec3 pos)
{
    // pos.y += sin(u_time * 2.0);
    // pos.zx *= rot2D(u_time * 0.8);
    vec3 p = pos;

    float offset = 3.5; 

    float s1 = sdfOctahedron(p, 5.);
    // s1 = max(s1, -sdfOctahedron(p, 1.));
    return s1;

    p = pos;
    p.y += offset;
    float s2 = sdfOctahedron(p, 2.);
    p = pos;
    p.y -= offset;
    float s3 = sdfOctahedron(p, 2.);

    // return min(min(s1, s2),s3);

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

float specular(vec3 rayDir, vec3 normal, vec3 lightDir){
    vec3 reflectDir = reflect(lightDir, normal);  

    float spec = pow(max(dot(rayDir, reflectDir), 0.0), 1280.);
    return spec;
}

//get the color based on the normal
vec3 get_color(vec3 normal){
    if(normal.x > 0. && normal.z > 0.)
        return palette(0.0);
    if(normal.x > 0. && normal.z < 0.)
        return palette(0.25);
    if(normal.x < 0. && normal.z > 0.)
        return palette(0.5);
    if(normal.x < 0. && normal.z < 0.)
        return palette(1.0);
}

const int maxReflection = 1;

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

    vec3 SigmaE = vec3(0.4,0.9,0.9);

    for (int i = 0; i < steps; i++){
        prev_pos = pos;
        pos = rayOrigin + rayDir * t;
        prev_dist = m_dist;
        m_dist = sdfMap(pos);

        if (sign(prev_dist) != sign(m_dist)){ // ray went through surface if sign flip
            vec3 normal = calculateNormal(pos);
            float dif = diffuse(normal, lightDir);
            float spec = specular(rayDir, normal, lightDir) * 10.0;
            scatteredLight += (spec + dif) * refractionLoss * transmittance;
            if (prev_dist < 0.){ // if ray was inside the object, reflect
                reflexion++;
                if (reflexion > maxReflection)
                    break;
                rayDir = reflect(rayDir, normal);
                rayOrigin = prev_pos;
                refractionLoss *= .2;
                t = 0.;
                continue;
            }
            else if (first){
                first = false;
                rayDir = refract(rayDir, normal, 0.95);
                // SigmaE = get_color(normal) * 1.2;
            }
        }

        if (m_dist < 0.0){
            float density = 0.05 / refractionLoss;

            // vec3 SigmaS = sigmaScattering * density;
            // vec3 SigmaE = sigmaExtinction * density;

            // vec3 S = (lightRay(pos,lightDir) * phase + ambient) * SigmaS;
            vec3 Tr = exp(-SigmaE * density * abs(m_dist));
            // vec3 Sint = (S - S * Tr) / SigmaE;
            // scatteredLight += transmittance * Sint * refractionLoss;
            transmittance *= Tr;
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

    vec3 rayOrigin = vec3(0, 0, -10.);
    vec3 rayDir = normalize(vec3(uv, 1.0));

    mx*=4.0;
    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    vec3 scatteredLight = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    vec4 result = raymarch(rayOrigin, rayDir, transmittance, scatteredLight);

    vec3 background = vec3(0);
    float mu = dot(rayDir, lightDir);
    background += getGlow(1.0-mu, 0.00015, 1.0);

    gl_FragColor = vec4(background + transmittance * scatteredLight, 1.0);
}