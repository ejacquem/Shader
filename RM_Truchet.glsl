#ifdef GL_ES
    precision mediump float;
#endif


uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

#define PI05 1.570796326794897
#define PI	3.141592653589793
#define PI2 6.283185307179586

const float maxDist = 50.;
const float epsilon = 0.001;
// const vec4 bgColor = vec4(0.14, 0.59, 0.73, 1.0);
const vec4 bgColor = vec4(1.0);
const int steps = 200;
const vec3 lightDir = normalize(vec3(1.2, 1, -1.1));
const vec3 lightColor = vec3(1.0,0.9,0.8);

const vec3 ambientColor = vec3(0.5);

#define PAL1 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67)
#define PAL2 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.10,0.20) 
#define PAL3 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.3,0.20,0.20)
#define PAL4 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,0.5),vec3(0.8,0.90,0.30)
#define PAL5 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,0.7,0.4),vec3(0.0,0.15,0.20)
#define PAL6 vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25)
#define PAL7 vec3(0.8,0.5,0.4),vec3(0.2,0.4,0.2),vec3(2.0,1.0,1.0),vec3(0.0,0.25,0.25)

vec3 palette(float t,vec3 a,vec3 b,vec3 c,vec3 d )
{
    return a + b*cos( 6.283185*(c*t+d) );
}

vec3 hash33(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

float hash13(vec3 p3)
{
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float sdfSphere(vec3 pos, float s)
{
  return length(pos) - s;
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

mat2 rot2D(float angle)
{
    // float c = cos(angle);
    // float s = sin(angle);
    // return mat2(c, s, -s, c);
    vec2 a = sin(vec2(1.5707963, 0) + angle); 
    return mat2(a, -a.y, a.x);
}

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
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

const float toroidRadius = 0.5; // The object's disc radius.
const float polRot = floor(3. * 4.0)/4.; // Poloidal rotations.
const float ballnb = 5.0 * 4.0;
float Mobius(vec3 p){
    float a = atan(p.z, p.x);

    p.xz *= rot2D(a);
    p.x -= toroidRadius;
    p.xy *= rot2D(a*polRot + u_time);

    p = abs(abs(p) - .07);
    return sdfSphere(p, .071);
}

float sdfsphereTorus(vec3 p){
    float a = atan(p.z, p.x);
    float ia = (floor(ballnb*a/PI2) + .5)/ballnb*PI2; 

    p.xz *= rot2D(ia);
    p.x -= toroidRadius;

    return sdfSphere(abs(p), 0.05);
}

vec2 objId;

float sdRotatingTorus(vec3 pos){
    float r = 1.0;
    vec3 p = pos;
    float sdfS, sdfT;

    p.xz *= rot2D(radians(u_time * 10. * r));

    sdfT = Mobius(pos);
    sdfS = sdfsphereTorus(p);

    objId[0] = min(sdfS, objId[0]);
    objId[1] = min(sdfT, objId[1]);

    return opSmoothUnion(sdfS, sdfT, 0.00);
}

float sdfMap(vec3 pos)
{
    // Find center of nearest cell
    vec3 ctr = floor(pos);
    // Alternating sign on each axis
    vec3 sn = sign(mod(ctr, 2.0) - 0.5);
    pos.xz *= sn.y;
    pos.xy *= sn.z;
    pos.zy *= sn.x;

    vec3 mpos = fract(pos) - 0.5;

    vec3 p = mpos;
    float sdf = maxDist;
    float d = 0.5; // circle offset

    objId[0] = maxDist;
    objId[1] = maxDist;

    p = mpos + vec3(d,0,d);
    sdf = min(sdf, sdRotatingTorus(p));

    p = mpos + vec3(0,d,-d);
    p.xy *= rot2D(radians(90.));
    sdf = min(sdf, sdRotatingTorus(p));

    p = mpos + vec3(-d,-d,0);
    p.zy *= rot2D(radians(-90.));
    sdf = min(sdf, sdRotatingTorus(p));
    
    return sdf;
}

vec3 calculateNormal(vec3 pos)
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.001;
    return normalize( e.xyy*sdfMap( pos + e.xyy ) + 
					  e.yyx*sdfMap( pos + e.yyx ) + 
					  e.yxy*sdfMap( pos + e.yxy ) + 
					  e.xxx*sdfMap( pos + e.xxx ) );
}

float gridIntersectionDistance(vec3 rayOrigin, vec3 rayDir) {
    vec3 t = (step(0.0, rayDir) - fract(rayOrigin)) / rayDir;
    return min(min(t.x, t.y), t.z);
}

float time = 0.;

vec3 arrowColor(vec3 pos)
{
    vec3 ip = fract(pos + 0.25);

    if (ip.x < ip.y && ip.x < ip.z)
        return vec3(1,0,0);
    if (ip.y < ip.z)
        return vec3(0,1,0);
    return vec3(0,0,1);
}

float trilinearInterpolation(vec3 p) {
    vec3 gridPos = floor(p);
    vec3 frac = p - gridPos;

    // sample the 8 surrounding points
    float c000 = hash13(gridPos + vec3(0,0,0));
    float c100 = hash13(gridPos + vec3(1,0,0));
    float c010 = hash13(gridPos + vec3(0,1,0));
    float c110 = hash13(gridPos + vec3(1,1,0));
    float c001 = hash13(gridPos + vec3(0,0,1));
    float c101 = hash13(gridPos + vec3(1,0,1));
    float c011 = hash13(gridPos + vec3(0,1,1));
    float c111 = hash13(gridPos + vec3(1,1,1));

    float c00 = mix(c000, c100, frac.x);
    float c01 = mix(c001, c101, frac.x);
    float c10 = mix(c010, c110, frac.x);
    float c11 = mix(c011, c111, frac.x);

    float c0 = mix(c00, c10, frac.y);
    float c1 = mix(c01, c11, frac.y);

    return mix(c0, c1, frac.z);
}

vec3 sdfColor(vec3 pos){
    vec3 c, c1, c2;
    c1 = palette(trilinearInterpolation(pos) * 2.0, PAL1);
    c2 = vec3(1);
    // float d = abs(objId[0] - objId[1]);
    // c = mix(c1, c2, );
    // return c;
    if (objId[0] < objId[1])
        return c1;
    else
        return c2;
}

float diffuse(vec3 normal, vec3 lightDir){
    return max(dot(normal, lightDir), 0.0);
}

float specular(vec3 rayDir, vec3 normal, vec3 lightDir, float po){
    vec3 reflectDir = reflect(lightDir, normal);  

    float spec = pow(max(dot(rayDir, reflectDir), 0.0), po);
    return spec;
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDir){
    float m_dist = maxDist;
    float t = 0.0; // total dist
    float prev_t = t;
    vec3 pos = vec3(+0);
    vec3 startPos = rayOrigin;
    int j = 0;
    float max_t = gridIntersectionDistance(startPos, rayDir);
    float min_m_dist = maxDist;

    for (int i = 0; i < steps; i++){
        pos = startPos + rayDir * t;

        m_dist = sdfMap(pos);
        // if(m_dist < -epsilon){ // Error detection
        //     gl_FragColor = vec4(vec3(abs(sin(u_time * 3.))),1);
        //     return vec4(pos, 0.);
        // }
        min_m_dist = min(min_m_dist, max(-0., m_dist));

        if (m_dist < epsilon || m_dist > maxDist) 
            break;

        prev_t = t;
        t += m_dist;
        // if (t > max_t){
        //     startPos = startPos + rayDir * (max_t + 0.001);
        //     max_t = gridIntersectionDistance(startPos, rayDir);
        //     t = 0.0;
        // }
        j++;
    }
    return vec4(pos, float(j));
}

//https://www.shadertoy.com/view/3s3GDn
float getGlow(float dist, float radius, float intensity){
    return pow(radius/dist, intensity);
}

const float intensity = 1.3;
const float radius = 0.015;
void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0,0,0);
    vec3 rayDir = normalize(vec3(uv, 0.99));

    mx *= 4.0;
    // rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);
    // rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    vec4 result = raymarch(rayOrigin, rayDir);
    vec3 pos = result.xyz;
    float j = result.w;
    if (j == 0.0)
        return;

    float dist = distance(pos, rayOrigin);
    float depth = 1.0 - (dist / (maxDist*0.1)) * 0.7;
    vec3 vdepth = vec3(1,1,1) * depth;
    vec3 N = calculateNormal(pos);
    float diff, spec;
    diff = diffuse(N, lightDir) * 0.4;
    spec = specular(rayDir, N, lightDir, 16.) * 0.5;

    // vec3 rand = hash33(floor(pos));
    // vec3 sphereColor = rand;
    // vec3 sphereColor = palette(depth * 1.0, PAL2);
    vec3 sphereColor = sdfColor(pos);
    // sphereColor = arrowColor(pos);
    // sphereColor = vec3(0.0);

    vec3 ambient = sphereColor * ambientColor;
    float outline = j * 0.02;
    // float glow = getGlow(objId[0], radius, intensity) * 0.01;
    vec3 color = (ambient + diff + spec + outline) * vdepth;
    if (sphereColor == vec3(1)){
        color = (sphereColor) * vdepth;
    }
    // color = vec3(1.0 - outline);
    // color *= exp( -0.1*t ); // fog 
    gl_FragColor = vec4(color, 1.0);

    // vec3 bg = vec3(1);
    // if (dist > maxDist)
    //     gl_FragColor = vec4(bg,1);
}