// Since no specific license was applied to shader https://www.shadertoy.com/view/WdB3Dw
// it falls under the site default license:
// This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Created by tdhooper https://www.shadertoy.com/user/tdhooper

// Modified by @JureTriglav (2021) to support interactivity and WebXR under the same CC-BY-NC-SA 3.0 license

precision highp float;
uniform vec4      resolution;           // viewport resolution (in pixels)
uniform vec4 virtualCameraQuat;
uniform vec3 virtualCameraPosition;
uniform vec3 localCameraPos;
uniform float     iTime;                 // shader playback time (in seconds)
uniform int       iFrame;                // shader playback frame
uniform sampler2D iChannel0;          // input channel. XX = 2D/Cube

uniform vec3 leftControllerPosition;
uniform vec3 rightControllerPosition;

uniform vec3 iChannelResolution[1];

uniform float zNear;
uniform float zFar;

in vec2 vUv;
in vec3 vPosition;
in mat4 vViewMatrix;
in mat4 vProjectionMatrix;
in mat4 vModelViewMatrix;
in mat4 vModelViewProjectionMatrix;

vec3 vrMove = vec3(0,0, -2);
// --------------------------------------------------------
// HG_SDF
// https://www.shadertoy.com/view/Xs3GRB
// --------------------------------------------------------

#define PI 3.14159265359

void pR(inout vec2 p, float a) {
    p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float smax(float a, float b, float r) {
    vec2 u = max(vec2(r + a,r + b), vec2(0));
    return min(-r, max (a, b)) + length(u);
}


// --------------------------------------------------------
// Spectrum colour palette
// IQ https://www.shadertoy.com/view/ll2GD3
// --------------------------------------------------------

vec3 pal( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos( 6.28318*(c*t+d) );
}

vec3 spectrum(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
}


// --------------------------------------------------------
// Main SDF
// https://www.shadertoy.com/view/wsfGDS
// --------------------------------------------------------

vec4 inverseStereographic(vec3 p, out float k) {
    k = 2.0/(1.0+dot(p,p));
    return vec4(k*p,k-1.0);
}

float fTorus(vec4 p4) {
    float d1 = length(p4.xy) / length(p4.zw) - 1.;
    float d2 = length(p4.zw) / length(p4.xy) - 1.;
    float d = d1 < 0. ? -d1 : d2;
    d /= PI;
    return d;
}

float fixDistance(float d, float k) {
    float sn = sign(d);
    d = abs(d);
    d = d / k * 1.82;
    d += 1.;
    d = pow(d, .5);
    d -= 1.;
    d *= 5./3.;
    d *= sn;
    return d;
}

float time;

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); }

float opSmoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h); }

float opSubtraction( float d1, float d2 ) { return max(-d1,d2); }

float map(vec3 p) {
    float k;
    vec4 p4 = inverseStereographic(p,k);

    pR(p4.zy, time * -PI / 2.);
    pR(p4.xw, time * -PI / 2.);

    // A thick walled clifford torus intersected with a sphere

    float d = fTorus(p4);
    d = abs(d);
    d -= .2;
    d = fixDistance(d, k);
    d = smax(d, length(p) - 1.85, .2);
    
    // d = smax(d, length(p - leftControllerPosition) - 0.3, 0.2);
    d = opSmoothUnion(d, length(p - leftControllerPosition + vrMove) - 0.1, 0.6);
    d = opSubtraction(length(p - rightControllerPosition + vrMove) - 0.1, d);

    return d;
}


// --------------------------------------------------------
// Rendering
// --------------------------------------------------------

// mat3 calcLookAtMatrix(vec3 ro, vec3 ta, vec3 up) {
//     vec3 ww = normalize(ta - ro);
//     vec3 uu = normalize(cross(ww,up));
//     vec3 vv = normalize(cross(uu,ww));
//     return mat3(uu, vv, ww);
// }

vec3 rotate_vector( vec4 quat, vec3 vec) {
  return vec + 2.0 * cross( cross( vec, quat.xyz ) + quat.w * vec, quat.xyz );
}

void main() {

    time = mod(iTime / 10000., 1.);

    vec3 camPos = virtualCameraPosition - vrMove; // vec3(1.8, 5.5, -5.5) * 1.75;
    // vec3 camTar = vec3(.0,0,.0);
    // vec3 camUp = vec3(-1,0,-1.5);
    // mat3 camMat = calcLookAtMatrix(camPos, camTar, camUp);
    float focalLength = 5.;
    vec2 p = vUv; // (-iResolution.xy + 2. * gl_FragCoord.xy) / iResolution.y;


    // vec3 ro = virtualCameraPosition - vrMove;
    vec3 someVec = normalize(vPosition - localCameraPos);
    someVec = rotate_vector(virtualCameraQuat, someVec);
    vec3 rd = normalize(someVec);
    
    vec3 rayDirection = rd; // normalize(camMat * vec3(p, focalLength));
    vec3 rayPosition = camPos;
    float rayLength = 0.;

    float distance = 0.;
    vec3 color = vec3(0);

    vec3 c;

    // Keep iteration count too low to pass through entire model,
    // giving the effect of fogged glass
    const float ITER = 82.;
    const float FUDGE_FACTORR = 0.8;
    const float INTERSECTION_PRECISION = .001;
    const float MAX_DIST = 20.;

    for (float i = 0.; i < ITER; i++) {

        // Step a little slower so we can accumilate glow
        rayLength += max(INTERSECTION_PRECISION, abs(distance) * FUDGE_FACTORR);
        rayPosition = camPos + rayDirection * rayLength;
        distance = map(rayPosition);

        // Add a lot of light when we're really close to the surface
        c = vec3(max(0., .01 - abs(distance)) * .08);
        c *= vec3(1.4,2.1,1.7); // blue green tint

        // Accumilate some purple glow for every step
        c += vec3(.6,.25,.7) * FUDGE_FACTORR / 160.;
        c *= smoothstep(20., 7., length(rayPosition));

        // // Fade out further away from the camera
        float rl = smoothstep(3.5, .5, length(rayPosition));
        c *= rl;

        // Vary colour as we move through space
        c *= spectrum(rl * 2. - 0.6 );

        color += c;

        if (rayLength > MAX_DIST) {
            break;
        }
    }

    // Tonemapping and gamma
    color = pow(color, vec3(1. / 1.8)) * 2.;
    color = pow(color, vec3(2.)) * 3.;
    color = pow(color, vec3(1. / 2.2));

    gl_FragColor = vec4(color, 1);
}
