#pragma vscode_glsllint_stage : frag
// Original shader license (Shadertoy default license):
// This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Hacked by Lucas Granito 2016 https://www.shadertoy.com/view/XlVSWh
// Simple path tracer. Created by Reinder Nijhoff 2014
// @reindernijhoff
//
// https://www.shadertoy.com/view/4tl3z4
//

// Modifications use the same CC-BY-NC-SA 3.0 license as above
// Jure Triglav 2021 (@juretriglav)
// Intersector adjustments
// Fix bug with lit backsides
// Add VR controller intersectors

precision highp float;
uniform vec4      resolution;           // viewport resolution (in pixels)
uniform vec4 virtualCameraQuat;
uniform vec3 virtualCameraPosition;
uniform float     iTime;                 // shader playback time (in seconds)
uniform int       iFrame;                // shader playback frame
uniform sampler2D iChannel0;          // input channel. XX = 2D/Cube

uniform vec3 leftControllerPosition;
uniform vec3 rightControllerPosition;

uniform vec3 iChannelResolution[1];

in vec2 vUv;
in vec3 vPosition;
uniform vec3 localCameraPos;

#define SPEED 0.0004
#define eps 0.01
#define EYEPATHLENGTH 4
#define SAMPLES 8
#define FULLBOX
#define LIGHTCOLOR vec3(16.86, 10.76, 8.2)*3.
#define WHITECOLOR vec3(.7295, .7355, .729)*0.7
#define ANIMATED

// Custom
#define MAX_DIST 1000.0
lowp float seed;

lowp vec3 ACESFilm( vec3 x )
{
    x *= 0.6; 
    lowp float a = 2.51;
    lowp float b = 0.03;
    lowp float c = 2.43;
    lowp float d = 0.59;
    lowp float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}


lowp float hash1() {
    return fract(sin(seed += 0.1)*43758.5453123);
}

lowp vec2 hash2() {
    return fract(sin(vec2(seed+=0.1,seed+=0.1))*vec2(43758.5453123,22578.1459123));
}

lowp vec3 hash3() {
    return fract(sin(vec3(seed+=0.1,seed+=0.1,seed+=0.1))*vec3(43758.5453123,22578.1459123,19642.3490423));
}


float bluenoise(vec2 uv)
{
    #if defined( ANIMATED )
    uv += 1.3370*fract(iTime);
    #endif
    float v = texture( iChannel0 , (uv + 0.5) / iChannelResolution[0].xy, 0.0).x;
    return v;
}


vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


//-----------------------------------------------------
// Intersection functions (by iq)
//-----------------------------------------------------

lowp vec3 nSphere( in vec3 pos, in vec4 sph ) {
    return (pos-sph.xyz)/sph.w;
}

lowp float iSphere( in vec3 ro, in vec3 rd, in vec4 sph ) {
    lowp vec3 oc = ro - sph.xyz;
    lowp float b = dot(oc, rd);
    lowp float c = dot(oc, oc) - sph.w * sph.w;
    lowp float h = b * b - c;
    if (h < 0.0) return -1.0;

	lowp float s = sqrt(h);
	lowp float t1 = -b - s;
	lowp float t2 = -b + s;
	
	return t1 < 0.0 ? t2 : t1;
}

vec3 nPlane( in vec3 ro, in vec4 obj ) {
    return obj.xyz;
}

float iPlane( in vec3 ro, in vec3 rd, in vec4 pla ) {
    return (-pla.w - dot(pla.xyz,ro)) / dot( pla.xyz, rd );
}

//-----------------------------------------------------
// scene
//-----------------------------------------------------

vec3 cosWeightedRandomHemisphereDirection( const vec3 n ) {
  	lowp vec2 r = hash2();
	lowp vec3  uu = normalize( cross( n, vec3(0.0,1.0,1.0) ) );
	lowp vec3  vv = cross( uu, n );
	lowp float ra = sqrt(r.y);
	lowp float rx = ra*cos(6.2831*r.x); 
	lowp float ry = ra*sin(6.2831*r.x);
	lowp float rz = sqrt( 1.0-r.y );
	lowp vec3  rr = vec3( rx*uu + ry*vv + rz*n );
    return normalize( rr );
}

vec3 randomSphereDirection() {
    lowp vec2 r = hash2()*6.2831;
	lowp vec3 dr=vec3(sin(r.x)*vec2(sin(r.y),cos(r.y)),cos(r.x));
	return dr;
}

vec3 randomHemisphereDirection( const vec3 n ) {
	lowp vec3 dr = randomSphereDirection();
	return dot(dr,n) * dr;
}

//-----------------------------------------------------
// light
//-----------------------------------------------------

lowp vec4 lightSphere;

void initLightSphere( float time ) {
	lightSphere = vec4( 2.5+2.2*sin(time),3.+2.*sin(time*0.7),6.0 + 1.0 * sin(time*1.7), 0.6 + 0.4 * sin(time*.5) );
}

lowp vec3 sampleLight( const in vec3 ro ) {
    lowp vec3 n = randomSphereDirection() * lightSphere.w;
    return lightSphere.xyz + n;
}

//-----------------------------------------------------
// scene
//-----------------------------------------------------

float bounce() { return pow( abs( sin( iTime * 1.5  * SPEED ) * 2.), 0.5) * 2. + 0.5;}
float sway() { return asin(cos( iTime * 1.5 * SPEED)) * 0.3;}
lowp float bounce2() { return pow( abs( sin( iTime * 2.  *SPEED ) * 2.), 0.5) + 0.5;}


// Some fun stuff from https://www.shadertoy.com/view/tl23Rm
// By @reinder
vec3 opU( vec3 d, float distance, float mat ) {
	return (distance < d.y) ? vec3(d.x, distance, mat) : d;
}

// float opSmoothUnion( float d1, float d2, float k ) {
//     float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
//     return mix( d2, d1, h ) - k*h*(1.0-h); 
// }

vec3 opSmoothUnion(vec3 d, float distance, float k, float mat ) {
    float h = clamp(0.5 + 0.5*(distance-d.y)/k, 0.0, 1.0);
    return vec3(d.x, mix(distance, d.y, h) - k*h*(1.0-h), mat);
}

// float sminCubic( vec3 a, float b, float k )
// {

//     float h = max( k-abs(a-b), 0.0 )/k;
//     return min( a, b ) - h*h*h*k*(1.0/6.0);
// }

vec3 sminCubic (vec3 d, float distance, float k, float mat) {
    float a = d.y;
    float b = distance;
    float h = max( k-abs(a-b), 0.0 )/k;
    return vec3(d.x, min( a, b ) - h*h*h*k*(1.0/6.0), mat);
}

float i2Plane( in vec3 ro, in vec3 rd, in vec2 distBound, inout vec3 normal,
              in vec3 planeNormal, in float planeDist) {
    float a = dot(rd, planeNormal);
    float d = -(dot(ro, planeNormal)+planeDist)/a;
    if (a > 0. || d < distBound.x || d > distBound.y) {
        return MAX_DIST;
    } else {
        normal = planeNormal;
    	return d;
    }
}

float i2Sphere( in vec3 ro, in vec3 rd, in vec2 distBound, inout vec3 normal,
               float sphereRadius ) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - sphereRadius*sphereRadius;
    float h = b*b - c;
    if (h < 0.) {
        return MAX_DIST;
    } else {
	    h = sqrt(h);
        float d1 = -b-h;
        float d2 = -b+h;
        if (d1 >= distBound.x && d1 <= distBound.y) {
            normal = normalize(ro + rd*d1);
            return d1;
        } else if (d2 >= distBound.x && d2 <= distBound.y) { 
            normal = normalize(ro + rd*d2);            
            return d2;
        } else {
            return MAX_DIST;
        }
    }
}

// Box: https://www.shadertoy.com/view/ld23DV
float i2Box( in vec3 ro, in vec3 rd, in vec2 distBound, inout vec3 normal, 
            in vec3 boxSize ) {
    vec3 m = sign(rd)/max(abs(rd), 1e-8);
    vec3 n = m*ro;
    vec3 k = abs(m)*boxSize;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
    if (tN > tF || tF <= 0.) {
        return MAX_DIST;
    } else {
        if (tN >= distBound.x && tN <= distBound.y) {
        	normal = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
            return tN;
        } else if (tF >= distBound.x && tF <= distBound.y) { 
        	normal = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
            return tF;
        } else {
            return MAX_DIST;
        }
    }
}

vec3 rotateY( const in vec3 p, const in float t ) {
    float co = cos(t);
    float si = sin(t);
    vec2 xz = mat2(co,si,-si,co)*p.xz;
    return vec3(xz.x, p.y, xz.y);
}

    
// End fun section
#define bounce (pow( abs( sin( iTime * 1.5 *SPEED ) * 2.), 0.5) * 1.5 + 0.5)
#define bounce2 (pow( abs( sin( iTime * 2.  *SPEED ) * 2.), 0.5) + 0.5)

lowp vec2 intersect( in vec3 ro, in vec3 rd, inout vec3 normal ) {
	lowp vec2 res = vec2( 1e20, -1.0 );
    lowp float t;
	
	t = iPlane( ro, rd, vec4( 0.0, 1.0, 0.0,0.0 ) ); if( t>eps && t<res.x ) { res = vec2( t, 1. ); normal = vec3( 0., 1., 0.); }
	t = iPlane( ro, rd, vec4( 0.0, 0.0,-1.0,8.0 ) ); if( t>eps && t<res.x ) { res = vec2( t, 1. ); normal = vec3( 0., 0.,-1.); }
    t = iPlane( ro, rd, vec4( 1.0, 0.0, 0.0,0.0 ) ); if( t>eps && t<res.x ) { res = vec2( t, 2. ); normal = vec3( 1., 0., 0.); }
#ifdef FULLBOX
    t = iPlane( ro, rd, vec4( 0.0,-1.0, 0.0,5.49) ); if( t>eps && t<res.x ) { res = vec2( t, 1. ); normal = vec3( 0., -1., 0.); }
    t = iPlane( ro, rd, vec4(-1.0, 0.0, 0.0,5.59) ); if( t>eps && t<res.x ) { res = vec2( t, 3. ); normal = vec3(-1., 0., 0.); }
#endif

	t = iSphere( ro, rd, vec4( 1.5,0.5 + bounce, 2.7, 1.0) ); if( t>eps && t<res.x ) { res = vec2( t, 1. ); normal = nSphere( ro+t*rd, vec4( 1.5,0.5 + bounce, 2.7,1.0) ); }
    t = iSphere( ro, rd, vec4( 4.0,0.5 + bounce2, 4.0, 1.0) ); if( t>eps && t<res.x ) { res = vec2( t, 5. ); normal = nSphere( ro+t*rd, vec4( 4.0,0.5 + bounce2, 4.0,1.0) ); }
    t = iSphere( ro, rd, lightSphere ); if( t>eps && t<res.x ) { res = vec2( t, 0.0 );  normal = nSphere( ro+t*rd, lightSphere ); }
				
    // Controllers
    t = iSphere(ro, rd, vec4(leftControllerPosition, 0.1)); if( t>eps && t<res.x ) { res = vec2( t, 5.0 );  normal = nSphere( ro+t*rd,vec4(leftControllerPosition, 0.1)  ); }
    t = iSphere(ro, rd, vec4(rightControllerPosition, 0.1)); if( t>eps && t<res.x ) { res = vec2( t, 1.0 );  normal = nSphere( ro+t*rd,vec4(rightControllerPosition, 0.1)  ); }

    return res;						  
}

bool intersectShadow( in vec3 ro, in vec3 rd, in float dist ) {
    lowp float t;
	
	t = iSphere( ro, rd, vec4( 1.5,0.5 + bounce, 2.7,1.0) );  if( t>eps && t<dist ) { return true; }
    t = iSphere( ro, rd, vec4( 4.0,0.5 + bounce2, 4.0,1.0) );  if( t>eps && t<dist ) { return true; }
    t = iSphere(ro, rd, vec4(leftControllerPosition, 0.1)); if( t>eps && t<dist ) { return true; }
    t = iSphere(ro, rd, vec4(rightControllerPosition, 0.1)); if( t>eps && t<dist ) { return true; }

    return false; // optimisation: planes don't cast shadows in this scene
}

//-----------------------------------------------------
// materials
//-----------------------------------------------------

lowp vec3 matColor( const in float mat ) {
	lowp vec3 nor = vec3(1., 1., 1.);
	
	if( mat<3.5 ) nor = hsv2rgb(vec3(iTime * SPEED * 0.025,0.8,0.6));
    if( mat<2.5 ) nor = hsv2rgb(vec3(iTime * SPEED * 0.025 + 0.5,0.9,0.6));
	if( mat<1.5 ) nor = WHITECOLOR;
	if( mat<0.5 ) nor = LIGHTCOLOR;
					  
    return nor;					  
}

bool matIsSpecular( const in float mat ) {
    return mat > 4.5;
}

bool matIsLight( const in float mat ) {
    return mat < 0.5;
}

//-----------------------------------------------------
// brdf
//-----------------------------------------------------

lowp vec3 getBRDFRay( in vec3 n, const in vec3 rd, const in float m, inout bool specularBounce ) {
    specularBounce = false;
    
    lowp vec3 r = cosWeightedRandomHemisphereDirection( n );
    if(  !matIsSpecular( m ) ) {
        return r;
    } else {
        specularBounce = true;
        
        lowp float n1, n2, ndotr = dot(rd,n);
        
        if( ndotr > 0. ) {
            n1 = 1.0; 
            n2 = 1.5;
            n = -n;
        } else {
            n1 = 1.5;
            n2 = 1.0; 
        }

        lowp float r0 = (n1-n2)/(n1+n2); r0 *= r0;

		lowp float fresnel = r0 + (1.-r0) * pow(1.0-abs(ndotr),2.);
        
        lowp vec3 ref;
        
        ref = reflect( rd, n );
        
        return normalize( ref + 0.1 * hash1() * r );
	}
}

//-----------------------------------------------------
// eyepath
//-----------------------------------------------------

lowp vec3 traceEyePath( in vec3 ro, in vec3 rd, const in bool directLightSampling ) {
    lowp vec3 tcol = vec3(0.);
    lowp vec3 fcol  = vec3(1.);
    
    bool specularBounce = true;
    
    for( int j=0; j<EYEPATHLENGTH; ++j ) {
        lowp vec3 normal;
        
        lowp vec2 res = intersect( ro, rd, normal );
        if( res.y < -0.5 ) {
            return tcol;
        }
        
        if( matIsLight( res.y ) ) {
            if( directLightSampling ) {
            	if( specularBounce ) tcol += fcol*LIGHTCOLOR;
            } else {
                tcol += fcol*LIGHTCOLOR;
            }

            return tcol;
        }
        
        ro = ro + res.x * rd;
        if (dot(rd, normal) > 0.0) normal *= -1.f;
        rd = getBRDFRay( normal, rd, res.y, specularBounce );        
        
        fcol *= matColor( res.y );

        lowp vec3 ld = sampleLight( ro ) - ro;
        
        if( directLightSampling ) {
			lowp vec3 nld = normalize(ld);
            if( !specularBounce && j < EYEPATHLENGTH-1 && !intersectShadow( ro, nld, length(ld)) ) {

                lowp float cos_a_max = sqrt(1. - clamp(lightSphere.w * lightSphere.w / dot(lightSphere.xyz-ro, lightSphere.xyz-ro), 0., 1.));
                lowp float weight = 2. * (1. - cos_a_max);

                tcol += (fcol * LIGHTCOLOR) * (weight * clamp(dot( nld, normal ), 0., 1.));
            }
        }
    }    
    return tcol;
}

//-----------------------------------------------------
// main
//-----------------------------------------------------
vec3 rotate_vector( vec4 quat, vec3 vec) {
  return vec + 2.0 * cross( cross( vec, quat.xyz ) + quat.w * vec, quat.xyz );
}

void main() {
	vec2 q = gl_FragCoord.xy / resolution.xy;
    
    // lowp float splitCoord = (iMouse.x == 0.0) ? resolution.x/2. + resolution.x*cos(iTime*.5) : iMouse.x;
    bool directLightSampling = true;
    
    //-----------------------------------------------------
    // camera
    //-----------------------------------------------------

    lowp vec2 p = -1.0 + 2.0 * (gl_FragCoord.xy) / resolution.xy;
    p.x *= resolution.x/resolution.y; 

    seed = bluenoise(gl_FragCoord.xy); // jitter dither pattern offset

    // lowp vec3 ro = vec3(2.78, 2.73, -8.00);
    vec3 ro = virtualCameraPosition; // custom

 
    vec3 someVec = normalize(vPosition - localCameraPos);
    someVec = rotate_vector(virtualCameraQuat, someVec);
    vec3 rd = normalize(someVec);

    //-----------------------------------------------------
    // render
    //-----------------------------------------------------

    lowp vec3 col = vec3(0.0);
    lowp vec3 tot = vec3(0.0);
    lowp vec3 uvw = vec3(0.0);
    
    for( int a=0; a<SAMPLES; a++ ) {

        lowp vec2 rpof;

	    // lowp vec3 rd = normalize( (p.x+rpof.x)*uu + (p.y+rpof.y)*vv + 3.0*ww );
        
        lowp vec3 rof = ro;

        initLightSphere( iTime * SPEED * 1.0);        

        col = traceEyePath( ro, rd, directLightSampling );

        tot += col;
        
        seed = mod( seed*1.1234567893490423, 13. );
    }
    
    tot /= float(SAMPLES);
    
    tot = pow( tot, vec3(0.35) );

    // From Image on https://www.shadertoy.com/view/4tVSDm
    tot = pow( tot, vec3(1.25) );
    tot = ACESFilm(tot);
    // End
    
    gl_FragColor = vec4( tot, 1.0 );
}