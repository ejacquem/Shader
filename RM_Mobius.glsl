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
const vec3 lightDir = normalize(vec3(1.2, 1, -1.1));
const vec3 lightColor = vec3(1.0,0.9,0.8);
const vec3 ambientColor = vec3(0.19, 0.28, 0.37);

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
// IQ's smooth minium function. 
float smin(float a, float b , float s){
    
    float h = clamp( 0.5 + 0.5*(b-a)/s, 0. , 1.);
    return mix(b, a, h) - h*(1.0-h)*s;
}
mat2 r2(float th){ vec2 a = sin(vec2(1.5707963, 0) + th); return mat2(a, -a.y, a.x); }
float Mobius(vec3 q){
 
    //// CONSTANTS ////
    const float toroidRadius = 1.25; // The object's disc radius.
    //const float ringWidth = .15; 
    float polRot = floor(2.)/4.; // Poloidal rotations.
    const float ringNum = 32.; // Number of quantized objects embedded between the rings.
    
    
    //// RAIL SECTION ////
    vec3 p = q;
    
    // Angle of the point on the XZ plane.
    float a = atan(p.z, p.x);
    
    // Angle of the point at the center of 32 (ringNum) partitioned cells.
    //
    // Partitioning the circular path into 32 (ringNum) cells - or sections, then obtaining the angle of 
    // the center position of that cell. The reason you want that angle is so that you can render 
    // something at the corresponding position. In this case, it will be a squared-off ring looking object.  	
    float ia = floor(ringNum*a/6.2831853);  
    // The ".5" value for the angle of the cell center. It was something obvious that I'd overlooked.
    // Thankfully, Dr2 did not. :)
  	ia = (ia + .5)/ringNum*6.2831853; 
    
    // Sweeping a point around a central point at a distance (toroidRadius), more or less. Basically, it's
    // the toroidal axis bit. If that's confusing, looking up a toroidal\poloidal image will clear it up.
    p.xz *= r2(a);
    p.x -= toroidRadius;
    p.xy *= r2(a*polRot);  // Twisting about the poloidal direction (controlled by "polRot) as we sweep.
    

    // The rail object. Taking the one rail, then ofsetting it along X and Y, resulting in four rails.
    // This is a neat spacial partitioning trick, and worth knowing if you've never encountered it before.
    // Basically, you're taking the rail, and splitting it into two along X and Y... also along Z, but since 
    // the object is contiunous along that axis, the result is four rails.
    p.zy = abs(abs(p.zy) - .25); // Change this to "p = abs(p)," and you'll see what it does.

    float rail = max(max(p.x, p.y) - .07, (max(p.y-p.x, p.y + p.x)*.7071 - .075)); // Makeshift octagon.
    // return rail;
    // return rail;
    
    //// REPEAT RING SECTION ////
    // The repeat square rings. It's similar to the way in which the rails are constructed, but since the object
    // isn't continous, we need to use the quantized angular positions (using "ia").
    p = q;
    // Another toroidal sweep using the quantized (partitioned, etc) angular position.
    p.xz *= r2(ia); // Using the quantized angle to obtain the position of the center of the corresponding cell.
    p.x -= toroidRadius;
    p.xy *= r2(a*polRot);  // Twisting about the poloidal direction - as we did with the rails.
    
    // Constructing some square rings.
    p = abs(p);
    float ring = max(p.x, p.y); // Square shape.
    // Square rings: A flat cube, with a thinner square pole taken out.
    ring = max(max(ring - .275, p.z - .03), -(ring - .2));
    
    
    //// WHOLE OBJECT ////
    // Object ID for shading purposes.
    // mObjID = step(ring, rail); //smoothstep(0., .07, rail - sqr);
    
    // Smoothly combine (just slightly) the square rings with the rails.
    return smin(ring, rail, .07); 

}

mat2 rot2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

float sdfMap(vec3 pos)
{
    vec3 center = vec3(5.0);
    
    float box = Mobius(pos);
    
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

vec4 raymarch(vec3 rayOrigin, vec3 rayDir)
{
    float m_dist = maxDist;
    float t = 0.0; // total dist
    vec3 pos;

    for (int i = 0; i < steps; i++){
        pos = rayOrigin + rayDir * t;
        m_dist = sdfMap(pos);

        if (m_dist > maxDist || m_dist < epsilon) 
            break;

        t += m_dist;
    }
    return vec4(pos, m_dist);
}

void main(){
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y; // [-1; 1]
    vec2 mx = (u_mouse.xy * 2.0 - u_resolution.xy) / u_resolution.y;

    vec3 rayOrigin = vec3(0, 0, -3);
    vec3 rayDir = normalize(vec3(uv, 1.0));

    rayOrigin.yz *= rot2D(mx.y);
    rayDir.yz *= rot2D(mx.y);

    rayOrigin.xz *= rot2D(mx.x);
    rayDir.xz *= rot2D(mx.x);

    vec4 result = raymarch(rayOrigin, rayDir);
    vec3 pos = result.xyz;
    float m_dist = result.w;

    vec3 color;
    if (m_dist > maxDist)
        color = bgColor.xyz;
    else {
        float diffuse = calculateDiffuse(pos);

        color = lightColor * diffuse + ambientColor;
        // color *= exp( -0.1*t ); // fog 
    }
    gl_FragColor = vec4(color, 1.0);
}