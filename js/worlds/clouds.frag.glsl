// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// Modified by @JureTriglav (2021) to support interactivity and WebXR under the same CC-BY-NC-SA 3.0 license

// Volumetric clouds. It performs level of detail (LOD) for faster rendering
uniform vec4 virtualCameraQuat;
uniform vec3 virtualCameraPosition;
uniform vec3 localCameraPos;
uniform float     iTime;                 // shader playback time (in seconds)
uniform sampler2D iChannel0;          // input channel. XX = 2D/Cube
varying vec2 vUv;

in vec3 vPosition;

float noise( in vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
	f = f*f*(3.0-2.0*f);
    
#if 1
	vec2 uv = (p.xy+vec2(37.0,239.0)*p.z) + f.xy;
    vec2 rg = textureLod(iChannel0,(uv+0.5)/256.0,0.0).yx;
#else
    ivec3 q = ivec3(p);
	ivec2 uv = q.xy + ivec2(37,239)*q.z;

	vec2 rg = mix(mix(texelFetch(iChannel0,(uv           )&255,0),
				      texelFetch(iChannel0,(uv+ivec2(1,0))&255,0),f.x),
				  mix(texelFetch(iChannel0,(uv+ivec2(0,1))&255,0),
				      texelFetch(iChannel0,(uv+ivec2(1,1))&255,0),f.x),f.y).yx;
#endif    
	return -1.0+2.0*mix( rg.x, rg.y, f.z );
}

float map( vec3 p, int n )
{
	vec3 q = p - vec3(0,.1,1)*iTime/1000.0;
	float f, w = 1.;
    for(int i=0; i<n; i++, w*=2.1 ) {
        f  += .5/w * noise( w*q );
    }
	return clamp( 1.5 - p.y - 2. + 1.75*f, 0., 1. );
}

vec3 sundir = normalize( vec3(-1.0,0.0,-1.0) );

#define MARCH(STEPS,MAPLOD)\
for(int i=0; i<STEPS; i++)\
{\
   vec3 pos = ro + t*rd;\
   if( pos.y<-3.0 || pos.y>2.0 || sum.a>0.99 ) break;\
   float den = map( pos, MAPLOD );\
   if( den>0.01 )\
   {\
     float dif = clamp((den - map(pos+0.3*sundir, MAPLOD))/0.6, 0.0, 1.0 );\
     vec3  lin = vec3(0.65,0.7,0.75)*1.4 + vec3(1.0,0.6,0.3)*dif;\
     vec4  col = vec4( mix( vec3(1.0,0.95,0.8), vec3(0.25,0.3,0.35), den ), den );\
     col.xyz *= lin;\
     col.xyz = mix( col.xyz, bgcol, 1.0-exp(-0.003*t*t) );\
     col.w *= 0.4;\
     \
     col.rgb *= col.a;\
     sum += col*(1.0-sum.a);\
   }\
   t += max(0.05,0.02*t);\
}

vec4 raymarch( in vec3 ro, in vec3 rd, in vec3 bgcol, in ivec2 px )
{
	vec4 sum = vec4(0.0);

	float t = 0.0; //texelFetch( iChannel0, px&255, 0 ).x;

    MARCH(40,5);
    MARCH(40,4);
    MARCH(30,3);
    MARCH(30,2);

    return clamp( sum, 0.0, 1.0 );
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv = normalize( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

vec4 render( in vec3 ro, in vec3 rd, in ivec2 px )
{
    // background sky     
	float sun = clamp( dot(sundir,rd), 0.0, 1.0 );
	vec3 col = vec3(0.6,0.71,0.75) - rd.y*0.2*vec3(1.0,0.5,1.0) + 0.15*0.5;
	col += 0.2*vec3(1.0,.6,0.1)*pow( sun, 8.0 );

    // clouds    
    vec4 res = raymarch( ro, rd, col, px );
    col = col*(1.0-res.w) + res.xyz;
    
    // sun glare    
	col += 0.2*vec3(1.0,0.4,0.2)*pow( sun, 3.0 );

    return vec4( col, 1.0 );
}


vec3 rotate_vector( vec4 quat, vec3 vec) {
  return vec + 2.0 * cross( cross( vec, quat.xyz ) + quat.w * vec, quat.xyz );
}

void main()  {  
  vec3 pos = virtualCameraPosition - vec3(0, 1, 0);
  vec3 someVec = normalize(vPosition - localCameraPos);
  someVec = rotate_vector(virtualCameraQuat, someVec);
  vec3 ray = normalize(someVec);

  gl_FragColor = render( pos, ray, ivec2(gl_FragCoord-0.5) );
}