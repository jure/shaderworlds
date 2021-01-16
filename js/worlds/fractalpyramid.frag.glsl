// Since no specific license was applied to shader https://www.shadertoy.com/view/tsXBzS
// it falls under the site default license:
// This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Created by bradjamesgrant https://www.shadertoy.com/user/bradjamesgrant

// Modified by @JureTriglav (2021) to support interactivity and WebXR under the same CC-BY-NC-SA 3.0 license

precision highp float;
uniform vec4 virtualCameraQuat;
uniform vec3 virtualCameraPosition;
uniform vec3 localCameraPos;
uniform float     iTime;                 // shader playback time (in seconds)
uniform int       iFrame;                // shader playback frame

uniform float zNear;
uniform float zFar;

in vec2 vUv;
in vec3 vPosition;


vec3 palette(float d){
	return mix(vec3(0.2,0.7,0.9),vec3(1.,0.,1.),d);
}

vec2 rotate(vec2 p,float a){
	float c = cos(a);
    float s = sin(a);
    return p*mat2(c,s,-s,c);
}

float map(vec3 p){
    for( int i = 0; i<8; ++i){
        float t = iTime*0.0002;
        p.xz =rotate(p.xz,t);
        p.xy =rotate(p.xy,t*1.89);
        p.xz = abs(p.xz);
        p.xz-=.5;
	}
	return dot(sign(p),p)/2.;
}

vec4 rm (vec3 ro, vec3 rd){
    float t = 0.;
    vec3 col = vec3(0.);
    float d;
    for(float i =0.; i<64.; i++){
		vec3 p = ro + rd*t;
        d = map(p)*.5;
        if(d<0.02){
            break;
        }
        if(d>100.){
        	break;
        }
        //col+=vec3(0.6,0.8,0.8)/(400.*(d));
        col+=palette(length(p)*.1)/(400.*(d));
        t+=d;
    }
    return vec4(col,1./(d*10.));
}

vec3 rotate_vector( vec4 quat, vec3 vec) {
  return vec + 2.0 * cross( cross( vec, quat.xyz ) + quat.w * vec, quat.xyz );
}

void main()
{

  vec3 ro = virtualCameraPosition;
  vec3 someVec = normalize(vPosition - localCameraPos);
  someVec = rotate_vector(virtualCameraQuat, someVec);
  vec3 rd = normalize(someVec);
    
  vec4 col = rm(ro,rd);
    
    
  gl_FragColor = col;
}
