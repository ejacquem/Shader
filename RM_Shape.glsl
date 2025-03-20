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

float sdfSphere(vec3 pos, vec3 center, float s)
{
  return length(pos - center) - s;
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

float sdRotatingTorus(vec3 pos, vec2 t, float r /*rotation dir*/){
    float sdf = 1000.;
    vec3 center = vec3(0,0.0,0);

    vec3 p = pos;
    p.xz *= rot2D(radians(u_time * 10. * r));

    sdf = min(sdf, sdTorus(p, t));
    float o = t.x;
    float s = 0.09;
    sdf = min(sdf, sdfSphere(p, vec3(+o,.0,+0), s));
    sdf = min(sdf, sdfSphere(p, vec3(+0,.0,+o), s));
    sdf = min(sdf, sdfSphere(p, vec3(+0,.0,-o), s));
    sdf = min(sdf, sdfSphere(p, vec3(-o,.0,+0), s));

    t.x *= 0.3;
    t.y *= 0.5;

    vec2 t2 = t;
    t2.x *= 0.75;
    t2.y *= 2.5;

    p = pos; p.z += o;
    p.xz *= rot2D(radians(90.));
    p.xy *= rot2D(radians(u_time * -10.0));
    sdf = min(sdf, sdHexPrism(p, t2));
    sdf = min(sdf, sdStarBox(p, t));

    p = pos; p.z -= o;
    p.zx *= rot2D(radians(90.));
    p.xy *= rot2D(radians(u_time * -10.0));
    sdf = min(sdf, sdHexPrism(p, t2));
    sdf = min(sdf, sdStarBox(p, t));

    p = pos; p.x += o;
    p.xy *= rot2D(radians(u_time * -10.0));
    sdf = min(sdf, sdHexPrism(p, t2));
    sdf = min(sdf, sdStarBox(p, t));

    p = pos; p.x -= o;
    p.xy *= rot2D(radians(u_time * 10.0));
    sdf = min(sdf, sdHexPrism(p, t2));
    sdf = min(sdf, sdStarBox(p, t));

    return sdf;
}

float sdfMap(vec3 pos)
{
    float sdf;

    // pos.xy *= rot2D(radians(u_time * 100.));

    sdf = sdRotatingTorus(pos, vec2(0.5, 0.05), 1.0);

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