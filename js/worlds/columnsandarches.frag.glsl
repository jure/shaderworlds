// Since no specific license was applied to shader https://www.shadertoy.com/view/MdyBzw
// it falls under the site default license:
// This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Created by ChrisK https://www.shadertoy.com/user/ChrisK

// Modified by @JureTriglav (2021) to support interactivity and WebXR under the same CC-BY-NC-SA 3.0 license
// Additional author permission for remix: Yes.

precision highp float;
uniform vec4      resolution;           // viewport resolution (in pixels)
uniform vec4 virtualCameraQuat;
uniform vec3 virtualCameraPosition;
uniform float     iTime;                 // shader playback time (in seconds)
uniform int       iFrame;                // shader playback frame
uniform sampler2D iChannel0;          // input channel. XX = 2D/Cube

uniform vec3 leftControllerPosition;
uniform vec3 rightControllerPosition;
uniform mat4 leftControllerMatrix;
uniform mat4 rightControllerMatrix;
uniform vec4 leftControllerRotation;
uniform vec3 iChannelResolution[1];

in vec2 vUv;
in vec3 vPosition;
uniform vec3 localCameraPos;

uniform float ceilingHeight;
uniform float columnDistX;
uniform float columnDistZ;
uniform vec3 materialColor;
uniform float lightOffset;

#define PI			3.14159265359
#define HALF_PI		1.57079632679
#define TAU     	6.28318530718

//#define FAST_TRACE

// #define CEILING_HEIGHT			30.0
// #define COLUMN_DIST_X       10.0
// #define COLUMN_DIST_Z				20.0
#define COLUMN_DIST 7.5
// #define MAT_COL					vec3(0.5, 0.2, 0.35)

#define FOV						HALF_PI
#define CAMERA_HEIGHT			2.0
// #define Z_OFFSET				iTime*COLUMN_DIST*0.25

#define DRAW_LIGHT
// #define LIGHT_POSITION			vec3( sin(iTime*0.001*PI*0.125)*COLUMN_DIST*2.0, 2.0, 20.0)
#define SHADOW_HARDNESS			50.0

#define FOG_NEAR				50.0
#define FOG_COL					vec3(0.02, 0.03, 0.04)

#define MAX_STEPS_PER_RAY   	200
#define MAX_RAY_LENGTH     		150.0
#define EPSILON					0.00001
#define SHADOW_ERROR			0.05

// #define DEBUG

vec3 LIGHT_POSITION; 

///////////////////////////////////////////////////////////////////////////////////////
//	MODEL															  		 		 //
///////////////////////////////////////////////////////////////////////////////////////

//displacements (use in place of 'p' in distance function)
vec3 repeat ( vec3 p, vec3 d ) {
    return mod(p+d*0.5,d)-d*0.5;
}


//primatives
float ubox ( vec3 p, vec3 l ) {
    return length(max(abs(p)-l,0.0));
}


float ybar ( vec3 p, vec2 l ) {
    vec2 d=abs(p.xz)-l;
    return min(max(d.x,d.y),0.0)+length(max(d,0.0));
}


float ycylinder ( vec3 p, float r, float l ) {
    return max(length(p.xz)-r,abs(p.y)-l);
}


float torus ( vec3 p, float ra, float rb ) {
    return length(vec2(length(p.xz)-ra, p.y))-rb;
}


//scene (low quality to accelerate casting with FAST_TRACE)
float modellq ( vec3 p ) {
    p.x+=columnDistX*0.5;
    vec3 pr = repeat( p, vec3(columnDistX,0.0,columnDistZ) );
    return min( ybar(pr,vec2(0.7)), min( ceilingHeight-p.y, p.y ));
}

// https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdVerticalCapsule( vec3 p, float h, float r )
{
  p.y -= clamp( p.y, 0.0, h );
  return length( p ) - r;
}

//scene
float model ( vec3 p ) {
    float hr = columnDistX*0.5;
    // p.x+=hr;
    
    // staff in the left controller space
    vec3 ps = (leftControllerMatrix * vec4(p, 1.0)).xyz; 
    float staff = sdVerticalCapsule(ps + vec3(0,0.4,0), 1.0, 0.02);
    // staff = min(staff, ycylinder(ps + vec3(0,1.1,0), 0.1, 0.02));

    //pillars
    vec3 pr = repeat( p, vec3(columnDistX,0.0,columnDistZ) );
    float pillar = ycylinder( pr, 0.5, ceilingHeight );
    pillar = min( pillar, 	   ubox( pr-vec3(0.0,ceilingHeight-0.25,0.0), vec3(0.6,0.25,0.6) )-0.01 );
    pillar = min( pillar, 	   ubox( pr-vec3(0.0,ceilingHeight-0.05,0.0), vec3(0.6,0.0,0.6) )-0.05 );
    pillar = min( pillar, ycylinder( pr-vec3(0.0,ceilingHeight-0.65,0.0), 0.55, 0.2 ) );
    pillar = min( pillar, 	  torus( pr-vec3(0.0,ceilingHeight-0.55,0.0), 0.55, 0.05 ) );
    pillar = max( pillar, 	 -torus( pr-vec3(0.0,ceilingHeight-0.70,0.0), 0.55, 0.05 ) );
    pillar = min( pillar, ubox( pr, vec3(0.55,0.4,0.55) )-0.01 );
    pillar = min( pillar, ubox( pr, vec3(0.65,0.2,0.65) )-0.01 );
    pillar = min( pillar, ubox( pr+vec3(0.0,-0.45,0.0), vec3(0.55,0.0,0.55) )-0.05 );
    pillar = min( pillar, ycylinder( pr+vec3(0.0,-0.6,0.0), 0.55, 0.2 ) );
    pillar = min( pillar, torus( pr+vec3(0.0,-0.7,0.0), 0.55, 0.05 ) );
    pillar = max( pillar, -torus( pr+vec3(0.0,-0.6,0.0), 0.55, 0.05 ) );
    
    //ceiling
    float ch = p.y-ceilingHeight+1.0;			//ceiling arch center height
    float pxr = mod(p.x,columnDistX)-hr;
    float pzr = mod((columnDistX/columnDistZ)*p.z,(columnDistX/columnDistZ)*columnDistZ)-hr;
    float ceiling = columnDistX*0.7-0.4-sqrt( ch*ch + min( pzr*pzr, pxr*pxr ));
    float archestrim = max( ceiling-columnDistX*0.2, -ybar( vec3(pxr,p.y,pzr), vec2(hr-0.4)));
    ceiling = min( ceiling, archestrim );
    ceiling = max( ceiling, ceilingHeight-p.y );

    // return min(min( ceiling, pillar ), p.y );
    // return min(min(staff, pillar), p.y );
    
    return min( min(staff, min( ceiling, pillar )), p.y );
    // return staff;
}



//////////////////////////////////////////////////////////////////////////////////////
//	MATH																			//
//////////////////////////////////////////////////////////////////////////////////////

vec3 xrotate (vec3 p, float r) { return vec3( p.x, p.y*cos(r)-p.z*sin(r), p.y*sin(r)+p.z*cos(r) ); }
vec3 yrotate (vec3 p, float r) { return vec3( p.x*cos(r)+p.z*sin(r), p.y, -p.x*sin(r)+p.z*cos(r) ); }
vec3 zrotate (vec3 p, float r) { return vec3( p.x*cos(r)-p.y*sin(r), p.x*sin(r)+p.y*cos(r), p.z ); }


float calcintersection ( vec3 ro, vec3 rd ) {
	//use sphere tracing to advance along ray
	float h = 100.0;
	float d = 0.0;
    int i = 0;
    
    #ifdef FAST_TRACE
    while ( i<MAX_STEPS_PER_RAY/2 && h>EPSILON*50.0 && d<MAX_RAY_LENGTH ) {
		h = modellq( ro+rd*d );
        d += h;
        i++;
	}
    h = 100.0;
    #endif
    
    while ( i<MAX_STEPS_PER_RAY && h>EPSILON && d<MAX_RAY_LENGTH ) {
		h = model( ro+rd*d );
        d += h;
        i++;
	}
	return d<MAX_RAY_LENGTH ? d : -1.0;
}


float lightintersection( vec3 ro, vec3 rd, float rad ) {

	vec3 oc = ro - LIGHT_POSITION;
	float b = dot( oc, rd );
	float c = dot( oc, oc ) - rad*rad;
	float h = b*b - c;
	return h<0.0 ? -1.0 : -b-sqrt(h);
}


float softshadow( vec3 ro, vec3 rd, float ldist ) {  
    float res = 1.0;
    float dmin = SHADOW_ERROR;
    for( float t=dmin; t<ldist-dmin; ) {
        float h = model(ro + rd*t);
        if( h<SHADOW_ERROR*0.001 )
            return 0.0;				//full shadow - break early
        res = min( res, SHADOW_HARDNESS*h/t );
        t += h;
    }
    return res*res*(3.0-2.0*res);
}



vec3 getdata ( vec3 ro, vec3 rd ) {
	float h = 100.0;
	float d = 0.0;
    int steps = 0;
    
    #ifdef FAST_TRACE
    while ( steps<MAX_STEPS_PER_RAY/2 && h>EPSILON*50.0 && d<MAX_RAY_LENGTH ) {
		h = modellq( ro+rd*d );
        d += h;
        steps++;
	}
    h = 100.0;
    #endif
    
    while ( steps<MAX_STEPS_PER_RAY && h>EPSILON && d<MAX_RAY_LENGTH ) {
		h = model( ro+rd*d );
        d += h;
        steps++;
	}
    
	return vec3(d<MAX_RAY_LENGTH ? d : -1.0, steps, h);
}


vec3 getnormal ( vec3 p ) {
	const float e = EPSILON*1.0;  //should be larger for smooth curves, smaller for fine geometric details
	vec3 nor = vec3( model( p - vec3(e,0.0,0.0) ),
					 model( p - vec3(0.0,e,0.0) ),
					 model( p - vec3(0.0,0.0,e) ) );
	return normalize( vec3(model(p)) - nor );
}


//////////////////////////////////////////////////////////////////////////////////////
//	RENDERING																		//
//////////////////////////////////////////////////////////////////////////////////////

vec3 getrendersample ( vec3 ro, vec3 rd ) {
    
    float rl = calcintersection( ro, rd );
    
    #ifdef DRAW_LIGHT
    float ll = lightintersection(ro, rd, 0.05);
    if (ll>-0.5 && (ll<rl || rl<-0.5) ) return vec3(255.0);							//draw light source
    #endif
    
    if ( rl > -0.5 ) {
        //draw object
		vec3 xyz = ro + rd*rl;
		vec3 nor = getnormal( xyz );
        
        vec3 ld = normalize(LIGHT_POSITION-xyz);
        float ldist = distance(xyz,LIGHT_POSITION);
        float li = 50.0/(ldist*ldist);

        float diff = max(dot(ld,nor),0.0);											//Lambertian diffuse
        
        vec3 hv = normalize(ld-rd);
        float m = 0.3;
        float a = acos(dot(nor,hv));
        float ta = tan(a);
        float ca = cos(a);
        //float spec = exp(-(ta*ta)/(m*m))/(PI*m*m*ca*ca*ca*ca);						//Beckmann specular
        float spec = max( pow( dot(nor,hv), 50.0 ), 0.00001 );						//Blinn-Phong specular
        
        vec3 c = mix( diff*materialColor, vec3(spec), 0.05)*li;
        // BEGIN
        if(c.r>0.0)
            c *= softshadow(xyz, ld, ldist);										//soft shadows
        c += materialColor*materialColor*100.0/((ldist+columnDistX*2.0)*(ldist+columnDistZ*2.0));		//first light bounce approximation
        c += materialColor*materialColor*materialColor*100.0/((ldist+columnDistX*4.0)*(ldist+columnDistZ*4.0));	//second light bounce approximation
        
        c += pow(1.0-dot(nor,-rd),3.0) * 0.2 * mix(FOG_COL,materialColor,min(li,1.0));	//add fresnel / rim light
        
        //basic fog
        float fog = clamp( (rl-FOG_NEAR)/(MAX_RAY_LENGTH-FOG_NEAR), 0.0, 1.0);
        c = mix(c, FOG_COL, fog);
        
        c *= clamp(model(ro)*2.0, 0.0, 1.0);										//fade to black when near geometry
        // END
        return c;
	} else {
		return FOG_COL;
	}
}


vec3 getheatmap ( vec3 ro, vec3 rd ) {
    vec3 gd = getdata(ro, rd);
    
    float steps = gd.y/float(MAX_STEPS_PER_RAY);
    
    if ( gd.x > -0.5 ) {
		vec3 xyz = ro + rd*gd.x;
        vec3 ld = normalize( LIGHT_POSITION-xyz );
        vec3 ldata = getdata( LIGHT_POSITION, -ld );
        
        float lightsteps = ldata.y/float(MAX_STEPS_PER_RAY);
        float error = float(gd.z>EPSILON) + float(ldata.z>EPSILON);
        return vec3( steps, error*0.5, lightsteps );
	} else {
		return vec3( steps, 0.0, 0.0 );
	}
}


vec3 filmictonemapping( vec3 col ) {
    float lwp = 7.0;			//linear white point
    float a = 0.20;				//shoulder strength
    float b = 0.30;				//linear strength
    float c = 0.85;				//linear angle
    float d = 0.15;				//toe strength
    float e = 0.02;				//toe numerator
    float f = 0.20;				//toe denominator
    
    col = ((col*(a*col+c*b)+d*e)/(col*(a*col+b)+d*f))-e/f;
    col/= ((lwp*(a*lwp+c*b)+d*e)/(lwp*(a*lwp+b)+d*f))-e/f;
    return col;
}

vec3 rotate_vector( vec4 quat, vec3 vec) {
  return vec + 2.0 * cross( cross( vec, quat.xyz ) + quat.w * vec, quat.xyz );
}
void main() {
    vec2 uv = vUv;
    vec3 ro = virtualCameraPosition; // custom

    // TODO: It's 4 AM. :)
    if(length(leftControllerPosition) > 0.01) {
      LIGHT_POSITION = leftControllerPosition + rotate_vector(leftControllerRotation, vec3(0, -1.5 - lightOffset, 0.00)) ; // * normalize(leftControllerMatrix*vec4(0,0,1,0)).xyz; // (leftControllerMatrix * vec4(0,0,1.,0.)).xyz;
    } else {
      LIGHT_POSITION = vec3(3,2,0);
    }
    vec3 someVec = normalize(vPosition - localCameraPos);
    someVec = rotate_vector(virtualCameraQuat, someVec);
    vec3 rd = normalize(someVec);

    vec3 campos = ro;
    vec3 camray = rd;
    
    #ifdef DEBUG
      vec3 col = getheatmap( campos, camray );
    #else
      vec3 col = getrendersample( campos, camray );
      col = filmictonemapping(col);
    #endif
    
    gl_FragColor = vec4( col, 1.0 );
}