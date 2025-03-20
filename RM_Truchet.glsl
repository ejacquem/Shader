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
const int steps = 500;
const vec3 lightDir = normalize(vec3(1.2, 1, -1.1));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);


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

float sdfBox(vec3 pos, vec3 box)
{
  vec3 q = abs(pos) - box;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - .00;
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

float sdRotatingTorus(vec3 pos, vec2 t, float r /*rotation dir*/){
    float sdf = 1000.;
    vec3 center = vec3(0,0.0,0);

    vec3 p = pos;
    p.xz *= rot2D(radians(u_time * 10. * r));

    sdf = min(sdf, sdTorus(p, t));
    float o = t.x;
    float s = 0.1;
    sdf = min(sdf, sdfSphere(p, vec3(+o,.0,+0), s));
    sdf = min(sdf, sdfSphere(p, vec3(+0,.0,+o), s));
    sdf = min(sdf, sdfSphere(p, vec3(+0,.0,-o), s));
    sdf = min(sdf, sdfSphere(p, vec3(-o,.0,+0), s));

    t.x *= s * 2.0;
    t.y *= 0.5;

    p = pos;
    p.z += o;
    p.xy *= rot2D(radians(90.));
    sdf = min(sdf, sdTorus(p, t));
    p = pos;
    p.z -= o;
    p.xy *= rot2D(radians(90.));
    sdf = min(sdf, sdTorus(p, t));
    p = pos;
    p.x += o;
    p.zy *= rot2D(radians(90.));
    sdf = min(sdf, sdTorus(p, t));
    p = pos;
    p.x -= o;
    p.zy *= rot2D(radians(90.));
    sdf = min(sdf, sdTorus(p, t));

    return sdf;
}

float sdfMap(vec3 pos)
{
    float t = u_time * 0.1;
    vec3 mpos = fract(pos) - 0.5;

    float size = hash13(floor(pos)) * 0.2 + 0.05;
    // size = 0.1;

    vec3 center = (hash33(floor(pos)) * 2.0 - 1.0) * (0.0);

    // float sdf = sdfSphere(mpos, center, size);
    // float sdf = sdfBox(mpos, vec3(size));
    vec3 p = mpos;
    float sdf = maxDist;
    float d = 0.5; // circle offset
    float s = 0.5; // circle size
    float w = 0.05;// circle width


    // sdf = min(sdf, sdRotatingTorus(p, vec2(0.5, 0.5)));

    vec3 rand = hash33(floor(pos)); 
    // mpos.x *= (rand.x < 0.5) ? -1.0 : 1.0;
    // mpos.y *= (rand.y < 0.5) ? -1.0 : 1.0;
    // mpos.z *= (rand.z < 0.5) ? -1.0 : 1.0;
    p = mpos + vec3(d,0,d);
    sdf = min(sdf, sdRotatingTorus(p, vec2(s, w), 1.0));

    p = mpos + vec3(0,d,-d);
    p.xy *= rot2D(radians(90.));
    sdf = min(sdf, sdRotatingTorus(p, vec2(s, w), 1.0));

    p = mpos + vec3(-d,-d,0);
    p.zy *= rot2D(radians(-90.));
    sdf = min(sdf, sdRotatingTorus(p, vec2(s, w), 1.0));
    
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

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0,0,u_time * 0.0);
    vec3 rayDir = normalize(vec3(uv, 1.0));

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
        if(m_dist < -epsilon){
            gl_FragColor = vec4(vec3(abs(sin(u_time * 3.))),1);
            return;
        }
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
    float depth = distance(pos, rayOrigin) / maxDist;
    vec3 N = calculateNormal(pos);
    float diffuse = max(dot(N, -rayDir), 0.0);

    vec3 sphereColor = hash33(floor(pos) + time * 0.00002);
    sphereColor = vec3(1.0);

    vec3 ambient = sphereColor * 0.5;
    float outline = float(j) * float(j) * 0.0001;
    color = (ambient + diffuse * 0.3) * (1.0 - depth) - outline;
    // color *= exp( -0.1*t ); // fog 
    gl_FragColor = vec4(color, 1.0);
    if (m_dist > maxDist || m_dist > epsilon * 10.)
        gl_FragColor = vec4(0,0,0,1);
}