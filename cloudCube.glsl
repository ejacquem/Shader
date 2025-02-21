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

float sdfSphere(vec3 pos, vec3 center, float s)
{
  return length(pos - center) - s;
}

float sdfBox(vec3 pos, vec3 box)
{
  vec3 q = abs(pos) - box;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
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
    vec3 boxSize = vec3(5.0);
    
    float box = sdfBox(pos, boxSize);
    
    return box;
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
  return cellVal * 0.5 + 0.5;
}

float density(vec3 pos)
{
    float n1 = (noise((pos + u_time * 0.03) * 2.0));
    // float n2 = (noise((pos + u_time * 0.04) * 5.0));
    float n2 = 0.5;
    // float n3 = (noise((pos + u_time * 0.05) * 15.0));
    float n3 = 0.5;

    return (n1*n1*n1*n1*n1*n1*50.0*n2*n2*n2*10.0*n3+n3*n3+n2+n1*n1*n1*10.0)* 0.1;
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDir)
{
    float stepSize = 0.03;
    float t = 0.0;
    float light_received = 0.0;
    float totalDen = 0.0;
    float samlpeNb = 0.0;
    vec3 first = vec3(0);
    vec3 last = vec3(0);

    for(int i = 0; i < 100; i++){
        vec3 pos = rayOrigin + rayDir * t;
        float den = 1.0;
        if(insideCloud(pos)){
            if (first == vec3(0))
                first = pos;
            vec3 plDir = normalize(pointLight - pos); // dir to pointlight
            float t2 = 0.0;
            // for(int j = 0; j < 5; j++){
            //     vec3 pos2 = pos + plDir * t2;
            //     if(insideCloud(pos)){
            //         light_received += density(pos);
            //     }
            //     t2 += stepSize * 10.0;
            // }
            den = density(pos);
            totalDen += den;
            samlpeNb++;
        }
        else if (first != vec3(0) && last == vec3(0))
            last = pos;
        t += stepSize * (1.5 - (den * 0.5));
    }
    totalDen /= distance(first, last) * 1.0;

    float beer = exp(-totalDen * .035);
    vec3 color = mix(vec3(0), spColor.rgb, light_received * 0.1);
    return vec4(color, (1.0 - beer) * (1.0 - beer));
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