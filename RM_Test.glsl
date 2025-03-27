#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

const float maxDist = 100.;
const float epsilon = 0.001;
const vec4 bgColor = vec4(0.14, 0.59, 0.73, 1.0);
const int steps = 500;
const vec3 lightDir = vec3(-0.1,1,0.5);
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

float lenManhattan(vec3 pos){
    pos = abs(pos);
    return (pos.x + pos.y + pos.z);
}

float customLen(vec3 pos){
    float n = u_time;
    pos = pow(abs(pos), vec3(n));
    return pow(pos.x + pos.y + pos.z, 1. / n);
}

float sdfSphere(vec3 pos, float s)
{
  return customLen(pos) - s;
}

float sdfBox(vec3 pos, vec3 box)
{
  vec3 q = abs(pos) - box;
  return customLen(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

float sdfMap(vec3 pos)
{
    float sdf = 1000.;

    sdf = min(sdf, sdfSphere(pos, 1.0));
    sdf = min(sdf, sdfSphere(pos + vec3(-3.0,1,1), 1.0));
    sdf = min(sdf, sdfSphere(pos + vec3(1.0,2,1), 1.0));
    sdf = min(sdf, sdfBox(pos - vec3(1, -1.0, 1), vec3(1)));
    float ground = pos.y + 2.0;

    return min(ground, sdf);
}

float ambientOcclusion(vec3 p, vec3 n) {
    float occlusion = 0.0;
    float stepSize = 0.1; // Sample step distance
    const int numSamples = 5; // Number of AO samples
    
    for (int i = 1; i <= numSamples; i++) {
        float dist = float(i) * stepSize;
        float d = sdfMap(p + n * dist); // SDF evaluation
        occlusion += max(0.0, stepSize - d);
    }
    
    return 1.0 - (occlusion / float(numSamples));
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
    float eps = 0.001;
    return clamp((sdfMap(pos+eps*lightDir)-sdfMap(pos))/eps,0.0,1.0);
}

mat2 rot2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -5);
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
    
        if (m_dist < -epsilon){
            gl_FragColor = vec4(vec3(sin(u_time * 10.0)), 1.0);
            return;
        }

        // color = vec3(i) / float(steps);

        if (m_dist > maxDist || m_dist < epsilon) break;

        t += m_dist * 0.05;
    }
    color = 1.0 - vec3(t / 15.0);
    vec3 N = calculateNormal(rayOrigin + rayDir * t);
    float diffuse = max(dot(N, lightDir), 0.0); // angle between lightDir and the normal
    diffuse = clamp(diffuse, 0., 1.);
    diffuse = calculateDiffuse(pos);
    float SAO = ambientOcclusion(pos, N);
    color = lightColor * diffuse * (1.0 - (t/maxDist) * 3.0) * SAO * SAO * SAO * SAO + ambientColor;
    // color *= exp( -0.1*t ); // fog 
    gl_FragColor = vec4(color, 1.0);
    if (m_dist > maxDist || m_dist > epsilon * 10.)
        gl_FragColor = bgColor;
}