#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform float u_mouseButton;

const float maxDist = 100.;
const float epsilon = 0.01;
const vec4 bgColor = vec4(0.15, 0.69, 0.86, 1.0);
const vec4 spColor = vec4(1.0);
const int steps = 200;
const vec3 lightDir = normalize(vec3(1.2, 1, -1.1));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);
const vec3 pointLight = vec3(0,0,-2);
const float pointLightI = 3.0; // intensity
const float cloudSize = 0.5;

// https://www.shadertoy.com/view/4djSRW
vec3 hash33(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);

}

// https://www.shadertoy.com/view/4djSRW
float hash13(vec3 p3)
{
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float hash11(float p)
{
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash( in float n )
{
    return fract(sin(n)*43758.5453);
}

mat2 rot2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

bool insideCloud(vec3 pos)
{
    float l = 0.5; //len
    return pos.x < l && pos.y < l && pos.z < l &&
           pos.x > -l && pos.y > -l && pos.z > -l;
}

vec3 random3(vec3 st) {
  float d1 = dot(st, vec3(12.3, 32.1, 21.3));
  float d2 = dot(st, vec3(45.6, 65.4, 54.6));
  float d3 = dot(st, vec3(78.9, 98.7, 87.9));
  
  st = vec3(d1, d2, d3);
  return fract(sin(st) * 14.7) * 2.0 - 1.0;
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

float density(vec3 pos)
{
    return noise(pos);
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

vec4 raymarch(vec3 rayOrigin, vec3 rayDir)
{
    vec2 nearFar = intersectAABB(rayOrigin, rayDir, vec3(-cloudSize), vec3(cloudSize));
    if(nearFar.x >= nearFar.y) return vec4(0);
    vec3 pos = vec3(0);
    float den = 0.0;
    float stepSize = 0.01;
    float sampleNb = 0.0;
    float t = nearFar.x; // tot dist from ray origin (starts at near intersection)

    for (int i = 0; i < 300; i++)
    {
        pos += rayOrigin + rayDir * t;
        den += density(pos);
        if(t > nearFar.y)
            break;
        sampleNb++;
        // t += stepSize;
    }
    den /= sampleNb * 0.1;
    return vec4(vec3(den), 1.0);
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -2);
    vec3 rayDir = normalize(vec3(uv, 1.0));

    // mx = vec2(u_time,-0.5);
    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    if (gl_FragCoord.x < 150.0 && gl_FragCoord.y < 150.0){
        gl_FragColor = vec4(vec3(noise(vec3(uv * 15.0, 0.0))), 1.0);
        return;
    }
    if (gl_FragCoord.x < 300.0 && gl_FragCoord.y < 150.0){
        gl_FragColor = vec4(vec3(density(vec3(uv * 15.0, 0.0))), 1.0);
        return;
    }

    //test noise
    // gl_FragColor = vec4(vec3(noise(vec3(uv * 2.0, 0))), 1.0);
    // return;
    vec4 color = raymarch(rayOrigin, rayDir);
    gl_FragColor = color;
}