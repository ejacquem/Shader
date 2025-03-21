#ifdef GL_ES
    precision mediump float;
#endif


uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const float maxDist = 50.;
const float epsilon = 0.0005;
// const vec4 bgColor = vec4(0.14, 0.59, 0.73, 1.0);
const vec4 bgColor = vec4(1.0);
const int steps = 100;
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

float sdfSphere(vec3 pos, vec3 center, float s)
{
  return length(pos - center) - s;
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
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
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

float sdRotatingTorus(vec3 pos, vec2 t){
    float sdf = 1000.;
    float r = 1.0;
    vec3 p = pos;

    p.xz *= rot2D(radians(u_time * 10. * r));

    // sdf = min(sdf, sdTorus(p, t * vec2(1,0.2)));
    sdf = min(sdf, sdTorus(p + vec3(0), t * vec2(1.2,.25)));
    sdf = min(sdf, sdTorus(p + vec3(0), t * vec2(0.8,.25)));
    sdf = min(sdf, sdTorus(p + vec3(0,0.1,0), t * vec2(1.0,.25)));
    sdf = min(sdf, sdTorus(p + vec3(0,-0.1,0), t * vec2(1.0,.25)));
    float o = t.x;
    float o2 = t.x / 1.4142;
    float s = 0.08;
    p = abs(p); // mirror negative space on 3 axis
    sdf = min(sdf, sdfSphere(p, vec3(+o,.0,+0), s));
    sdf = min(sdf, sdfSphere(p, vec3(+0,.0,+o), s));
    sdf = min(sdf, sdfSphere(p, vec3(+o2,.0,+o2), s));

    t.x *= 0.3;
    t.y *= 0.5;

    mat2 rotTime = rot2D(radians(u_time * -10.0));
    mat2 rot90 = rot2D(radians(90.));

    // stars ------------------
    // p = pos; p.xz = abs(pos.xz); p.z -= o;
    // p.zx *= rot90;
    // p.xy *= rotTime;
    // sdf = min(sdf, sdStarBox(p, t));

    // p = pos; p.xz = abs(pos.xz);; p.x -= o;
    // p.yx *= rotTime;
    // sdf = min(sdf, sdStarBox(p, t));

    // Torus ---------------------

    t.x *= 0.65;
    t.y *= 1.1;
    p = pos; p.xz = abs(pos.xz);; p.x -= o;
    p.zy *= rot90;
    sdf = min(sdf, sdTorus(p, t));

    p = pos; p.xz = abs(pos.xz);; p.z -= o;
    p.xy *= rot90;
    sdf = min(sdf, sdTorus(p, t));

    //arrow
    // p = pos;
    // p.xy *= rot2D(radians(180. * float(r == 1.0)));
    // sdf = min(sdf, sdArrow(p - vec3(0,0,o), vec3(-1,0,0)));
    // sdf = min(sdf, sdArrow(p - vec3(o,0,0), vec3(0,0,1)));
    // sdf = min(sdf, sdArrow(p - vec3(0,0,-o), vec3(1,0,0)));
    // sdf = min(sdf, sdArrow(p - vec3(-o,0,0), vec3(0,0,-1)));

    return sdf;
}

float sdfMap(vec3 pos)
{
    // Find center of nearest cell
    vec3 ctr = floor(pos);
    // Alternating sign on each axis
    vec3 sn = sign(mod(ctr, 2.0) - 0.5);
    pos.x *= sn.y;
    pos.x *= sn.z;
    pos.z *= sn.x;
    pos.z *= sn.y;
    pos.y *= sn.z;
    pos.y *= sn.x;

    vec3 mpos = fract(pos) - 0.5;

    vec3 p = mpos;
    float sdf = maxDist;
    float d = 0.5; // circle offset
    float s = 0.5; // circle size
    float w = 0.05;// circle width

    p = mpos + vec3(d,0,d);
    sdf = min(sdf, sdRotatingTorus(p, vec2(s, w)));

    p = mpos + vec3(0,d,-d);
    p.xy *= rot2D(radians(90.));
    sdf = min(sdf, sdRotatingTorus(p, vec2(s, w)));

    p = mpos + vec3(-d,-d,0);
    p.zy *= rot2D(radians(-90.));
    sdf = min(sdf, sdRotatingTorus(p, vec2(s, w)));
    
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

float calculateDiffuse(vec3 pos)
{
    float eps = 0.0001;
    return clamp((sdfMap(pos+eps*lightDir)-sdfMap(pos))/eps,0.0,1.0);
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

float diffuse(vec3 normal, vec3 lightDir){
    return max(dot(normal, lightDir), 0.0);
}

float specular(vec3 rayDir, vec3 normal, vec3 lightDir, float po){
    vec3 reflectDir = reflect(lightDir, normal);  

    float spec = pow(max(dot(rayDir, reflectDir), 0.0), po);
    return spec;
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(u_time * 0.5,0,1.0);
    vec3 rayDir = normalize(vec3(uv, 0.5));

    mx *= 4.0;
    // rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    // rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    float m_dist = maxDist;
    float t = 0.0; // total dist
    float prev_t = t;
    vec3 color;
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
        //     return;
        // }
        min_m_dist = min(min_m_dist, max(-0., m_dist));

        if (m_dist < epsilon) 
            break;

        prev_t = t;
        t += m_dist;
        if (t > max_t){
            startPos = startPos + rayDir * (max_t + 0.001);
            max_t = gridIntersectionDistance(startPos, rayDir);
            t = 0.0;
        }
        j++;
    }
    // float diffuse = calculateDiffuse(pos);
    float dist = distance(pos, rayOrigin);
    float depth = 1.0 - (dist / (maxDist*0.1));
    vec3 N = calculateNormal(pos);
    float diff, spec;
    diff = diffuse(N, lightDir) * 0.4;
    // float spec = specular(rayDir, N, lightDir, 2.) * 0.3;
    spec += specular(rayDir, N, lightDir, 16.) * 0.5;

    // vec3 rand = hash33(floor(pos));
    // vec3 sphereColor = rand;
    vec3 sphereColor = palette(depth * 2.0, PAL2);
    // sphereColor = arrowColor(pos);
    // sphereColor = vec3(1.0);

    vec3 ambient = sphereColor * ambientColor;
    float outline = float(j) * float(j) * 0.0001;
    color = (ambient + diff + spec) * (depth);
    // color = vec3(outline);
    // color *= exp( -0.1*t ); // fog 
    gl_FragColor = vec4(color, 1.0);

    vec3 bg = vec3(0);
    if (m_dist > maxDist || m_dist > epsilon * 10.)
        gl_FragColor = vec4(bg,1);
}