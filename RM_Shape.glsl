#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

float time = u_time;

#define PI05 1.570796326794897
#define PI	3.141592653589793
#define PI2 6.283185307179586

const float maxDist = 100.;
const float epsilon = 0.001;
const vec4 bgColor = vec4(0.14, 0.59, 0.73, 1.0);
const int steps = 200;
const vec3 lightDir = vec3(0,1,0);
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

mat2 rot2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

float sdfSphere(vec3 pos, float s)
{
  return length(pos) - s;
}

// https://www.shadertoy.com/view/MtSyRz
const float ARROW_RAD = 0.025;
vec2 ARROW_HEAD_SLOPE = normalize(vec2(1, 2));
    
const float ARROW_BODY_LENGTH = 0.3;
const float ARROW_HEAD_LENGTH = 0.1;
float sdArrow(vec3 p, vec3 d)
{
    float t = dot(p, d);
    float n = length(p - t*d);
    float dist = n - ARROW_RAD;
    t += 0.5*ARROW_HEAD_LENGTH;
    dist = max(dist, abs(t)-0.5*ARROW_BODY_LENGTH);
    t -= 0.5*ARROW_BODY_LENGTH;
    dist = min(dist, max(-t, dot(ARROW_HEAD_SLOPE, vec2(t-ARROW_HEAD_LENGTH, n))));
    return dist;
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sdHexPrism( vec3 p, vec2 h )
{
  const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
  p = abs(p);
  p.xy -= 2.0*min(dot(k.xy, p.xy), 0.0)*k.xy;
  vec2 d = vec2(
       length(p.xy-vec2(clamp(p.x,-k.z*h.x,k.z*h.x), h.x))*sign(p.y-h.x),
       p.z-h.y );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdStarBox( vec3 p, vec2 h )
{
    return min(
        sdBox(p, h.xxy), 
        sdBox(vec3(p.xy * rot2D(radians(45.)), p.z), h.xxy));
}

mat2 r2(float th){ vec2 a = sin(vec2(1.5707963, 0) + th); return mat2(a, -a.y, a.x); }
float Mobius(vec3 p){
    const float toroidRadius = 0.5; // The object's disc radius.
    float polRot = floor(4.)/4.; // Poloidal rotations.
    float a = atan(p.z, p.x);
    
    p.xz *= r2(a);
    p.x -= toroidRadius;
    p.xy *= r2(a*polRot + u_time * 0.5);  // Twisting about the poloidal direction (controlled by "polRot) as we sweep.
    
    p = abs(abs(p) - .10); // Change this to "p = abs(p)," and you'll see what it does.
    return sdfSphere(p, 0.10);
}
// Mobius equation from https://www.shadertoy.com/view/XldSDs
const float toroidRadius = 0.5; // The object's disc radius.
const float polRot = 3.; // Poloidal rotations.
const float ballnb = 5.0 * 4.0;
float sdfMobius(vec3 p, float a){
    p.xz *= rot2D(a);
    p.x -= toroidRadius;
    p.xy *= rot2D(a*polRot + time);

    p = abs(abs(p) - .06);
    return sdfSphere(p, .061);
}

float sdfSphereTorus(vec3 p, float a){
    float ia = (floor(ballnb*a/PI2) + .5)/ballnb*PI2; 

    p.xz *= rot2D(ia);
    p.x -= toroidRadius;

    return sdfSphere(abs(p), 0.05);
}

vec2 objId;

float sdRotatingTorus(vec3 pos){
    float r = 1.0;
    pos.x *= 1.25;
    vec3 p = pos;
    float sdfS, sdfT;

    // p.xz *= rot2D(radians(time * 10. * r));

    float a = atan(p.z, p.x);
    sdfT = sdfMobius(p, a);
    sdfS = sdfSphereTorus(p, a);

    objId[0] = min(sdfS, objId[0]);
    objId[1] = min(sdfT, objId[1]);

    return opSmoothUnion(sdfS, sdfT, 0.05);
}

float sdfMap(vec3 pos)
{
    float sdf;

    // pos.xy *= rot2D(radians(u_time * 100.));

    sdf = sdRotatingTorus(pos);

    return sdf;
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
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -1);
    vec3 rayDir = normalize(vec3(uv, 1));

    mx *= 4.0;
    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    float m_dist = maxDist;
    float t = 0.0; // total dist
    vec3 color;
    vec3 pos;

    for (int i = 0; i < steps; i++){
        pos = rayOrigin + rayDir * t;
        m_dist = sdfMap(pos);

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