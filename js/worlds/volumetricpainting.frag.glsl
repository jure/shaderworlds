// Joe Gardner from Soul (Pixar 2020)
//
// by Leon Denise 2020.12.31
// 
// thanks to Inigo Quilez, Dave Hoskins, Koltes, NuSan
// for sharing useful lines of code
//
// Licensed under hippie love conspiracy

// https://www.shadertoy.com/view/3ltyRB

// Modifications for interactivity and painting abilities by @JureTriglav (2021)
// under the same hippie love conspiracy license. :)
// Modified with premission from the author for non-commercial experimental purposes.

// #define gl_FragDepthEXT gl_FragDepth
precision highp float;
uniform vec4 virtualCameraQuat;
uniform vec3 virtualCameraPosition;
uniform vec3 localCameraPos;
uniform float     iTime;                 // shader playback time (in seconds)

uniform sampler2D dataTexture1; 

uniform vec3 leftControllerPosition;
uniform vec3 rightControllerPosition;

uniform float zNear;
uniform float zFar;

in vec3 vPosition;
in vec3 cameraForward;


#define MAX_DISTANCE 10.0
#define MAX_COUNT 20
#define MAX_OBJECTS 10
// out highp vec4 pc_fragColor;


// layout(location = 0) out vec4 frag_color;

// Warning: We don't use struct due to this bug:
// https://github.com/jure/precision-bug-repro
// details about sdf volumes
// struct Volume
// {
//     highp float dist;
//     highp int mat;
//     mediump float density;
//     highp float space;
// };

vec4[MAX_OBJECTS] objects;

// union operation between two volume
// Volume select(Volume a, Volume b)
// {
//     if (a.dist < b.dist) return a;
//     return b;
// }

// Without struct, x dist, y mat, z density, w space
vec4 select(vec4 a, vec4 b) {
    if (a.x < b.x) return a;
    return b;
}


// Rotation 2D matrix
mat2 rot(float a) { highp float c = cos(a), s = cos(a); return mat2(c,-s,s,c); }

// Dave Hoskins
// https://www.shadertoy.com/view/4djSRW
float hash12(vec2 p)
{
	highp vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

uvec3 pcg3d(uvec3 v) {

    v = v * 1664525u + 1013904223u;

    v.x += v.y*v.z;
    v.y += v.z*v.x;
    v.z += v.x*v.y;

    v ^= v >> 16u;

    v.x += v.y*v.z;
    v.y += v.z*v.x;
    v.z += v.x*v.y;

    return v;
}

// Inigo Quilez
// https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}
float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); }

float opSmoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h); }

float opSmoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h); }
float sdCappedTorus(in vec3 p, in vec2 sc, in float ra, in float rb)
{
  p.x = abs(p.x);
  float k = (sc.y*p.x>sc.x*p.y) ? dot(p.xy,sc) : length(p.xy);
  return sqrt( dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
}
float sdVerticalCapsule( vec3 p, float h, float r )
{
  p.y -= clamp( p.y, 0.0, h );
  return length( p ) - r;
}
float sdCappedCone(vec3 p, vec3 a, vec3 b, float ra, float rb)
{
    float rba  = rb-ra;
    float baba = dot(b-a,b-a);
    float papa = dot(p-a,p-a);
    float paba = dot(p-a,b-a)/baba;
    float x = sqrt( papa - paba*paba*baba );
    float cax = max(0.0,x-((paba<0.5)?ra:rb));
    float cay = abs(paba-0.5)-0.5;
    float k = rba*rba + baba;
    float f = clamp( (rba*(x-ra)+paba*baba)/k, 0.0, 1.0 );
    float cbx = x-ra - f*rba;
    float cby = paba - f;
    float s = (cbx < 0.0 && cay < 0.0) ? -1.0 : 1.0;
    return s*sqrt( min(cax*cax + cay*cay*baba,
                       cbx*cbx + cby*cby*baba) );
}
float sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
  vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}
float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

// Joe Gardner from Soul (Pixar 2020)
//
// by Leon Denise 2020.12.31
// 
// thanks to Inigo Quilez, Dave Hoskins, Koltes, NuSan
// for sharing useful lines of code
//
// Licensed under hippie love conspiracy

bool ao_pass = false;


// volumes description
vec4 map(vec3 pos)
{
    float slowTime = iTime / 1000.0;
    float shape = 100.;

    // global twist animation
    // pos.zy *= rot(sin(pos.y*.2 + slowTime) * .1 + .2);
    // pos.yx *= rot(0.1 * sin(pos.y * .3 + slowTime));
    
    highp vec3 p = pos;

    vec4 ghost;
    //ghost.mat = 0;
    ghost.y = 2.0;
    ghost.z = 0.05;
    // ghost.z = 1.0;
    ghost.w = 0.03;
    // ghost.density = 0.3;
    // ghost.space = 0.12;
    
    // Volume opaque;
    // opaque.mat = 0;
    // opaque.density = 1.;
    // opaque.space = 0.;
    
    // Volume hair;
    // hair.mat = mat_eyebrows;
    // hair.density = .2;
    // hair.space = 0.1;
    
    // Volume glass;
    // glass.mat = mat_glass;
    // glass.density = .15;
    // glass.space = 0.1;

    // head
    // ghost.x = length(p*vec3(1,1,1))-2.0;
    // plane.x = p.y;
    // ghost.x = length(p-vec3(1.0,1.0,1.0))-0.25;
    // ghost.x = opSmoothUnion(ghost.x, length(p-vec3(0,1.2,0))-0.55, 0.35);
    
    // ghost.dist = sdBox(p, vec3(1,1,1)); // length(p*vec3(1,0.9,1))-1.0;
    // if(leftControllerPosition != vec3(0,0,0)) {
  // ghost.x = opSmoothUnion(ghost.x, length(p - leftControllerPosition) - 0.1, 0.1);
  ghost.x = length(p - leftControllerPosition) - 0.1;
  ghost.x = opSmoothUnion(ghost.x, sdRoundBox(p - rightControllerPosition, vec3(.2,.06,.2), 0.1), 0.1);
  
    for( int i=0; i<MAX_OBJECTS; i++ ) {
      if(objects[i].w == 0.0) {
        break; // means no object was recorded past this position
      }
      ghost.x = (objects[i].w == 0.05) ? opSmoothUnion(ghost.x, length(p - objects[i].xyz) - 0.1, 0.1) : ghost.x;
      ghost.x = (objects[i].w == 0.15) ? opSmoothUnion(ghost.x, sdRoundBox(p - objects[i].xyz, vec3(.2,.06,.2), 0.1), 0.1) : ghost.x;
    }
        // ghost.dist = opSmoothUnion(ghost.dist, length(p*rightControllerPosition) - 0.35, 0.5);


    // Volume volume;
    
    // volume.density = ghost.density;
    // volume.dist = ghost.dist;
    // volume.space = ghost.space;
    // volume.mat = ghost.mat;
    
    highp vec4 volume = ghost; //select(plane, ghost);

    // glass
    if (!ao_pass)
    {
        p = pos-vec3(0,2.,-.65);
        p.x = abs(p.x)-.18;
        volume = volume;
    }

    return volume;
}

// NuSan
// https://www.shadertoy.com/view/3sBGzV
vec3 getNormal(vec3 p) {
	vec2 off=vec2(0.001,0);
	return normalize(map(p).x-vec3(map(p-off.xyy).x, map(p-off.yxy).x, map(p-off.yyx).x));
}

// Inigo Quilez
// https://www.shadertoy.com/view/Xds3zN
float getAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
  float sca = 1.0;
  for( int i=0; i<5; i++ )
  {
      float h = 0.01 + 0.12*float(i)/4.0;
      vec4 volume = map( pos + h*nor );
      float d = volume.x;
      occ += (h-d)*sca;
      sca *= 0.95;
      if( occ>0.35 ) break;
  }
  return clamp( 1.0 - 3.0*occ, 0.0, 1.0 ) * (0.5+0.5*nor.y);
}

vec3 rotate_vector( vec4 quat, vec3 vec) {
  return vec + 2.0 * cross( cross( vec, quat.xyz ) + quat.w * vec, quat.xyz );
}

float depthSample(float z)
{
  // z = z * 2.0 - 1.0;
  float a = (zFar+zNear)/(zFar-zNear);
  float b = 2.0*zFar*zNear/(zFar-zNear);
  return (2.0 * zNear * zFar) / (zFar + zNear - z * (zFar - zNear));
  // gl_FragDepth = a + b/z;
	// return a + b/z; //nonLinearDepth;
}

void main()
{

    for( int i=0; i<MAX_OBJECTS; i++ ) {
      // uint stride = 4;
      vec4 object = texture(dataTexture1, vec2(float(i) / 512.0, 0.));
      if (object.z != 0.0) {
        objects[i] = object;
     }
    }

  // gl_FragColor = texture(dataTexture1, vec2(2.0/512.0, 0.));
  // gl_FragDepth = 0.0;
    highp vec3 outputColor = vec3(0);
  // coordinates
  // vec2 uv = gl_FragCoord.xy / resolution.xy;
  // vec2 p = 2.*(gl_FragCoord.xy - 0.5 * resolution.xy)/resolution.y;
  
  // camera
  // vec3 pos = vec3(-5,0,-8);
  
  // Custom
  float slowTime = iTime / 1000.0;  
  
  // look at
  // vec3 z = normalize(vec3(0,-0.3,0)-pos);
  // vec3 x = normalize(cross(z, vec3(0,1,0)));
  // vec3 y = normalize(cross(x, z));
  // vec3 ray = normalize(z * 3. + x * p.x + y * p.y);
  
  // background gradient
  // gl_FragColor.rgb += vec3(0.2235, 0.3804, 0.5882) * uv.y;
  
  // Custom
  // vec2 newUV = (vUv - vec2(0.5))*resolution.zw + vec2(0.5);
  
  // WORKING
  highp vec3 pos = virtualCameraPosition;
  vec3 someVec = normalize(vPosition - localCameraPos);
  vec3 anotherVec = normalize(vPosition - localCameraPos);
  someVec = rotate_vector(virtualCameraQuat, someVec);
  vec3 ray = normalize(someVec);
  // END WORKING
  // vec3 pos = eye;
  // vec3 ray = normalize(dir);
  // ray = rotate_vector(virtualCameraQuat, ray);

  //pos = pos - vec3(0,0,+1.0);
  // vec3 someVec = vec3( (vUv - vec2(0.5))*resolution.zw,-1);
  // vec3 ray = normalize(vPosition - virtualCameraPosition);
  // ray = rotate_vector(virtualCameraQuat, ray);


  float shade = 0.0;
  vec3 normal = vec3(0,1,0);
  float ao = 1.0;
  float rng = hash12(gl_FragCoord.xy + slowTime);
  const int count = MAX_COUNT;
  
  float distance = 0.0;
  // raymarch iteration
  for (int index = 0; index < count; ++index)
  {
    vec4 volume = map(pos);
    if (distance > MAX_DISTANCE) {
      break;
    }
    if (volume.x < 0.01)
    {
      // sample ao when first hit
      if (shade < 0.001)
      {
          ao_pass = true;
          ao = getAO(pos, normal);
          ao_pass = false;
      }
      
      // accumulate fullness
      shade += volume.z;
      
      // step further on edge of volume
      normal = getNormal(pos);
      float fresnel = pow(dot(ray, normal)*.5+.5, 1.2);
      volume.x = volume.w * fresnel;
      
      // coloring
      vec3 col = vec3(0);
      // switch (volume.y)
      // {
      //     // eye globes color
      //     case mat_eye_globe:
      //     float globe = dot(normal, vec3(0,1,0))*0.5+0.5;
      //     vec3 look = vec3(0,0,-1);
      //     look.xz *= rot(sin(time)*0.2-.2);
      //     look.yz *= rot(sin(time*2.)*0.1+.5);
      //     float pupils = smoothstep(0.01, 0.0, dot(normal, look)-.95);
      //     col += vec3(1)*globe*pupils;
      //     break;

      //     // eyebrows color
      //     case mat_eyebrows:
      //     col += vec3(0.3451, 0.2314, 0.5255);
      //     break;

      //     // glass color
      //     case mat_glass:
      //     col += vec3(.2);
      //     break;

      //     // ghost color
      //     default:

    //   if (volume.y < 1.0)  {
    //   // Checkerboard floor
    //   float f = mod(floor(0.3 * pos.z) + floor(0.3 * pos.x), 2.0);
    //   col = 0.4 + f * vec3(0.6);
    // } else if (volume.y < 16.0) {
      vec3 leftlight = normalize(vec3(6,-5,1));
      vec3 rightlight = normalize(vec3(-3,1,1));
      vec3 frontlight = normalize(vec3(-1,1,-2));
      vec3 blue = vec3(0,0,1) * pow(dot(normal, leftlight)*0.5+0.5, 0.2);
      vec3 green = vec3(0,1,0) * pow(dot(normal, frontlight)*0.5+0.5, 2.);
      vec3 red = vec3(0.8941, 0.2039, 0.0824) * pow(dot(normal, rightlight)*0.5+0.5, .5);
      col += blue + green + red;
      col *= ao*0.5+0.3;
    // }
      //     break;
      // }
      
      // accumulate color
      outputColor.rgb += col * volume.z;
    }
    
    // stop when fullness reached
    if (shade >=  1.0)
    {
        break;
    }
    
    // dithering trick inspired by Duke
    volume.x *= 0.9 + 0.1 * rng;
    
    // keep record of distance
    distance += volume.x;
    // keep marching
    pos += ray * volume.x;
  }
      // outputColor.rgb = vec3(0.0, 0.0, 0.0);
  // vec3 finalColor = vec3(9, 0, -3);
  if(outputColor == vec3(0.0, 0.0, 0.0)) {
    discard;
  }
  // } else {
  //   // pc_fragColor.rgb = outputColor;
  // }

  //pc_fragColor.rgb = outputColor;
  //pc_fragColor.a = 1.0; //clamp(2.0*max(max(outputColor.r, outputColor.g), outputColor.b), 0.0, 1.0);



  // extract the z depth of our hit
  float z = -distance * dot(cameraForward, someVec);

  // convert to normalized device coordinates
  float ndcz = (zFar + zNear + (2.0*zFar*zNear)/z)
            / (zFar - zNear);

  // map onto gl_DepthRange
  gl_FragDepth = 0.5 * (gl_DepthRange.diff * ndcz + gl_DepthRange.near + gl_DepthRange.far);
  gl_FragColor.rgb = outputColor;
  gl_FragColor.a = 1.0;
}