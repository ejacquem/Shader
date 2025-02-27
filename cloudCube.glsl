#ifdef GL_ES
    precision mediump float;
#endif

#include "hash.glsl"

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform float u_mouseButton;

const float maxDist = 100.;
const float epsilon = 0.01;
const vec4 bgColor = vec4(0.15, 0.69, 0.86, 1.0);
const vec4 spColor = vec4(1.0);
const int steps = 200;
const vec3 lightDir = normalize(vec3(0.0, -1, 0.0));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);
const vec3 pointLight = vec3(0,0,-2);
const float pointLightI = 3.0; // intensity
const float cloudSize = 0.5;


const vec3 RAYLEIGH = vec3(0.12, 0.25, 0.5);

const vec3 sigmaScattering = 100.0 * RAYLEIGH;
const vec3 sigmaExtinction = 200.0 * RAYLEIGH;

mat2 rot2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

vec3 random3(vec3 st) {
  float d1 = dot(st, vec3(12.3, 32.1, 21.3));
  float d2 = dot(st, vec3(45.6, 65.4, 54.6));
  float d3 = dot(st, vec3(78.9, 98.7, 87.9));
  
  st = vec3(d1, d2, d3);
  return fract(sin(st) * 14.7) * 2.0 - 1.0;
}

// https://www.shadertoy.com/view/3s3GDn
float getGlow(float dist, float radius, float intensity){
	return max(0.0, pow(radius/max(dist, 1e-5), intensity));	
}

// return 0 to 1 value
float noise(vec3 uv) {
  vec3 i = floor(uv); // cellPos
  vec3 pos = fract(uv.xyz);

  float c1 = dot(random3(i + vec3(0,0,0)), vec3(pos - vec3(0,0,0)));
  float c2 = dot(random3(i + vec3(1,0,0)), vec3(pos - vec3(1,0,0)));
  float c3 = dot(random3(i + vec3(0,1,0)), vec3(pos - vec3(0,1,0)));
  float c4 = dot(random3(i + vec3(1,1,0)), vec3(pos - vec3(1,1,0)));
  float c5 = dot(random3(i + vec3(0,0,1)), vec3(pos - vec3(0,0,1)));
  float c6 = dot(random3(i + vec3(1,0,1)), vec3(pos - vec3(1,0,1)));
  float c7 = dot(random3(i + vec3(0,1,1)), vec3(pos - vec3(0,1,1)));
  float c8 = dot(random3(i + vec3(1,1,1)), vec3(pos - vec3(1,1,1)));
  
  vec3 suv = smoothstep(0.0, 1.0, pos);

  float cellVal1 = mix(mix(c1, c2, suv.x), mix(c3, c4, suv.x), suv.y);
  float cellVal2 = mix(mix(c5, c6, suv.x), mix(c7, c8, suv.x), suv.y);
  float cellVal = mix(cellVal1, cellVal2, pos.z);
  return cellVal;
}

float sampleDensity(vec3 pos)
{
    float time = 0.0;
    float cloudNoise = 0.0;
    float cloudShape = noise(pos * 3.0 + time * 0.2) * 2.0;
    cloudShape = smoothstep(0.0, 1.0, cloudShape);
    cloudNoise += cloudShape;
    // float n2 = noise(pos * 15.0 + time * 0.2);
    // return n1 - n2 * n1 * 1.0;
    if (cloudShape > 0.0)
    {
        float cloudDetail = noise(pos * 15.0 + time * 0.2) * 2.0;

        cloudNoise -= cloudDetail * cloudShape;
    }
    return max(cloudNoise, 0.005);
}

// https://gist.github.com/DomNomNom/46bb1ce47f68d255fd5d
// Compute the near and far intersections using the slab method.
// No intersection if tNear > tFar.
vec2 intersectAABB(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax) {
    vec3 tMin = (boxMin - rayOrigin) / rayDir;
    vec3 tMax = (boxMax - rayOrigin) / rayDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return vec2(tNear, tFar);
}

vec3 lightRay(vec3 rayOrigin, vec3 rayDir)
{
    vec2 nearFar = intersectAABB(rayOrigin, rayDir, vec3(-cloudSize), vec3(cloudSize));
    if(nearFar.x >= nearFar.y) return vec3(0.);
    vec3 pos = vec3(0);
    float dist = 0.0;
    float stepSize = nearFar.y / 7.0;
    vec3 transmittence = vec3(1.0);

    for (int i = 1; i <= 7; i++)
    {
        pos = rayOrigin + rayDir * stepSize * float(i);
        float den = sampleDensity(pos);
        transmittence *= exp(-stepSize * (den * sigmaExtinction));
    }
    return transmittence * 10.0;
}

float HenyeyGreenstein(float g, float costh){
	return (1.0 / (4.0 * 3.1415))  * ((1.0 - g * g) / pow(1.0 + g*g - 2.0*g*costh, 1.5));
}

/*
sampleSigmaS = sigmaScattering∗density
sampleSigmaE = sigmaExtinction∗density
ambient = gradient∗precipitation∗globalAmbientColor
S = (evaluateLight(directionToSun,position)∗phase+ambient)∗sampleSigmaS
Tr = exp(−sampleSigmaE ∗ stepSize)
/∗ Analytical integration of light / transmittance between the steps ∗/
Sint = (S − S ∗ Tr) / sampleSigmaE
scatteredLight += transmittance ∗ Sint
transmittance ∗= Tr
*/
void raymarch(vec3 rayOrigin, vec3 rayDir, out vec3 transmittance, out vec3 scatteredLight)
{
    scatteredLight = vec3(0.0);
    transmittance = vec3(1.0);

    vec2 nearFar = intersectAABB(rayOrigin, rayDir, vec3(-cloudSize), vec3(cloudSize));
    if(nearFar.x >= nearFar.y) return;
    vec3 pos = vec3(0);
    float stepSize = 0.01;
    float t = nearFar.x + stepSize * hash11(nearFar.y / nearFar.x *0.1); // tot dist from ray origin (starts at near intersection)


    float ambient = 0.0;
    float phase = HenyeyGreenstein(0.3, dot(rayDir, lightDir));

    for (int i = 0; i < 1000; i++)
    {
        pos = rayOrigin + rayDir * t;
        float density = sampleDensity(pos);

        vec3 SigmaS = sigmaScattering * density;
        vec3 SigmaE = sigmaExtinction * density;

        vec3 S = (lightRay(pos,-lightDir) * phase + ambient) * SigmaS;
        vec3 Tr = exp(-SigmaE * stepSize);
        vec3 Sint = (S - S * Tr) / SigmaE;
        scatteredLight += transmittance * Sint;
        transmittance *= Tr;

        t += stepSize;
        if(t > nearFar.y)
            break;
    }
    // return bgColor * transmittance + scatteredLight;
    return;
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -2);
    vec3 rayDir = normalize(vec3(uv, 1.0));

    // mx = vec2(u_time,-0.5);
    mx *= 4.0;
    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    if (gl_FragCoord.x < 150.0 && gl_FragCoord.y < 150.0){
        gl_FragColor = vec4(vec3(noise(vec3(uv * 15.0, 0.0))), 1.0);
        return;
    }
    if (gl_FragCoord.x < 300.0 && gl_FragCoord.y < 150.0){
        gl_FragColor = vec4(vec3(sampleDensity(vec3(uv * 2.0, 0.0))), 1.0);
        return;
    }

    //test noise
    // gl_FragColor = vec4(vec3(noise(vec3(uv * 2.0, 0))), 1.0);
    // return;
    vec3 transmittance;
    vec3 scatteredLight;
    raymarch(rayOrigin, rayDir, transmittance, scatteredLight);

    vec3 background = 0.05 * vec3(0.09, 0.33, 0.81);

    float mu = dot(rayDir, -lightDir);
    background += getGlow(1.0-mu, 0.00015, 0.9);

    vec4 color = vec4(vec3(background * transmittance + scatteredLight), 1.0);

    gl_FragColor = color;
}