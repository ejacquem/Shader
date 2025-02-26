/* Main function, uniforms & utils */
#ifdef GL_ES
    precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform float u_gain;
uniform float u_lacunarity;
uniform float u_octaves;
uniform float u_size;
uniform float u_w1;
uniform float u_w2;
uniform float u_w3;

const int max_octaves = 5;

#define PI_TWO			1.570796326794897
#define PI				3.141592653589793
#define TWO_PI			6.283185307179586

vec2 hash22(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);

}

float smin( float a, float b, float k )
{
    k *= 4.0;
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - h*h*k*(1.0/4.0);
}

float voronoi(vec2 pos)
{
    vec2 g = floor(pos);//grid
    vec2 f = fract(pos);

    float m_dist = 10.0;
    for (int i = -1; i <= 1; i++)
    for (int j = -1; j <= 1; j++){
        vec2 ij = vec2(i,j);
        float dist = distance(f - ij, hash22(g + ij));
        // m_dist = min(m_dist, dist);
        m_dist = smin(m_dist, dist, 0.05);
    }
    return m_dist;
}

float fbm(vec2 st) {
  float amplitude = 1.0;
  float frequency = 1.0;
  
  float l = u_lacunarity * 5.0;
  float g = u_gain;

  float _sin = 0.0;
  for (int i = 0; i < max_octaves; i++){
    if(i > int(u_octaves * float(max_octaves)))
        break;
    _sin += amplitude * voronoi(st * frequency * 2.0);
    amplitude *= g;
    frequency *= l;
  }
  return _sin;
}

float voronoise(vec2 uv)
{
    float n = 1.0 - voronoi(uv*4.);
    float n2 = 1.0 - voronoi((uv)*4.);

    float shape = (n - 0.5) * 2.0 * step(0.5, n) * (n2 - 0.5) * 2.0 * step(0.5, n2);
    float detail = (1.0 - voronoi(uv*10.)) + (1.0 - voronoi(uv*25.)) * 2.0;

    return (shape + detail * shape) ;
}

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    uv = uv * 0.5 + 0.5;

    // float n1 = voronoi(uv * 5.0);
    // float n2 = voronoi(uv * 7.0);
    // vec3 color = vec3(1.0 - (n2 * n1 * n1));
    // vec3 color = vec3(fbm(uv * u_size * 10.0));

    // float color = 
    // voronoi(uv*4.) * .625 + 
    // voronoi(uv*10.) * .25 + 
    // voronoi(uv*15.) * .125;

    float color = voronoise(uv);

    gl_FragColor = vec4(vec3(color), 1.0);
}