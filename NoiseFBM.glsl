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

// vec3 hash33(vec3 p3)
// {
// 	p3 = fract(p3 * vec3(.1031, .1030, .0973));
//     p3 += dot(p3, p3.yxz+33.33);
//     return fract((p3.xxy + p3.yxx)*p3.zyx);
// }

vec3 hash33(vec3 point)
{
  float d1 = dot(point, vec3(12.3, 32.1, 21.3));
  float d2 = dot(point, vec3(45.6, 65.4, 54.6));
  float d3 = dot(point, vec3(78.9, 98.7, 87.9));
  
  point = vec3(d1, d2, d3);
  return fract(sin(point) * 14.7) * 2.0 - 1.0;
}

float smin( float a, float b, float k )
{
    k *= 4.0;
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - h*h*k*(1.0/4.0);
}

// Perlin Noise return 0 to 1 value
float noise(vec3 uv) {
  vec3 i = floor(uv); // cellPos
  vec3 pos = fract(uv.xyz);

  vec3 suv = smoothstep(0.0, 1.0, pos);

  float c1 = dot(hash33(i + vec3(0,0,0)), vec3(pos - vec3(0,0,0)));
  float c2 = dot(hash33(i + vec3(1,0,0)), vec3(pos - vec3(1,0,0)));
  float c3 = dot(hash33(i + vec3(0,1,0)), vec3(pos - vec3(0,1,0)));
  float c4 = dot(hash33(i + vec3(1,1,0)), vec3(pos - vec3(1,1,0)));
  float c5 = dot(hash33(i + vec3(0,0,1)), vec3(pos - vec3(0,0,1)));
  float c6 = dot(hash33(i + vec3(1,0,1)), vec3(pos - vec3(1,0,1)));
  float c7 = dot(hash33(i + vec3(0,1,1)), vec3(pos - vec3(0,1,1)));
  float c8 = dot(hash33(i + vec3(1,1,1)), vec3(pos - vec3(1,1,1)));
  

  float cellVal1 = mix(mix(c1, c2, suv.x), mix(c3, c4, suv.x), suv.y);
  float cellVal2 = mix(mix(c5, c6, suv.x), mix(c7, c8, suv.x), suv.y);
  return mix(cellVal1, cellVal2, pos.z);
}

float fbm(vec3 st) {
  float amplitude = 1.0;
  float frequency = 1.0;
   
  const int octaves = 6;
  float lacunarity = 2.0;
  float gain = 0.5;

  float _sin = 0.0;
  for (int i = 0; i < octaves; i++){
    _sin += amplitude * noise(st * frequency * 2.0);
    amplitude *= gain;
    frequency *= lacunarity;
  }
  return _sin;
}

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    uv = uv * 0.5 + 0.5;

    float color = fbm(vec3(uv, u_time * 0.1)) * 0.5 + 0.5;

    gl_FragColor = vec4(vec3(color), 1.0);
}