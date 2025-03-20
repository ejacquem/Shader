#ifdef GL_ES
    precision mediump float;
#endif


uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const float maxDist = 50.;
const float epsilon = 0.003;
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

float sdfSphere(vec3 pos, vec3 center, float s)
{
  return length(pos - center) - s;
}

float sdfBox(vec3 pos, vec3 box)
{
  vec3 q = abs(pos) - box;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - .00;
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

float sdfMap(vec3 pos)
{
    float t = u_time * 0.1;
    vec3 mpos = fract(pos) - 0.5;

    float size = hash13(floor(pos)) * 0.2 + 0.05;
    // size = 0.1;

    vec3 center = (hash33(floor(pos)) * 2.0 - 1.0) * (0.0);

    // float sdf = sdfSphere(mpos, center, size);
    float sdf = sdfBox(mpos, vec3(size));
    
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

    vec3 rayOrigin = vec3(0,0,0);
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
        if(m_dist < 0.0){
            gl_FragColor = vec4(vec3(abs(sin(u_time * 10.))),1);
            return;
        }
        min_m_dist = min(min_m_dist, max(-0., m_dist));

        if (m_dist < epsilon) 
            break;

        prev_t = t;
        t += m_dist;
        if (t > max_t){
            startPos = startPos + rayDir * (max_t + 0.01);
            max_t = gridIntersectionDistance(startPos, rayDir);
            t = 0.0;
        }
        j++;
    }
    float diffuse = calculateDiffuse(pos);
    float depth = distance(pos, rayOrigin) / maxDist;
    // vec3 N = calculateNormal(rayOrigin + rayDir * t);
    // float diffuse = max(dot(N, lightDir), 0.0);

    vec3 sphereColor = hash33(floor(pos) + time * 0.00002);

    color = (sphereColor + float(j) * 0.000) * (1.0 - depth);
    // color *= exp( -0.1*t ); // fog 
    gl_FragColor = vec4(color, 1.0);
    if (m_dist > maxDist || m_dist > epsilon * 10.)
        gl_FragColor = vec4(0,0,0,1);
}