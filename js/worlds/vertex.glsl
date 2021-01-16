// #version 300 es
// Some custom stuff
// uniform mat4 modelMatrix;
// uniform mat4 modelViewMatrix;
// uniform mat4 projectionMatrix;
// uniform mat4 viewMatrix;
// // uniform vec3 cameraPosition;
// in vec3 position;
// End custom for RawShader
// in vec2 uv;

precision highp float;
uniform float time;
out vec2 vUv;
out vec3 vPosition; // localSurfacePos

uniform vec3 worldDirection;
uniform vec2 pixels;
out mat4 vViewMatrix;
out mat4 vProjectionMatrix;
out mat4 vModelViewProjectionMatrix;
out mat4 vModelViewMatrix;

// out vec3 dir;
// out vec3 eye;
out vec3 cameraForward;


float PI = 3.141592653589793238;

void main() {
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1);
  vViewMatrix = viewMatrix;
  vProjectionMatrix = projectionMatrix;
  vModelViewMatrix = modelViewMatrix;
  vModelViewProjectionMatrix = projectionMatrix * modelViewMatrix;
  vPosition = position;

  // float aspect = projectionMatrix[1][1] / projectionMatrix[0][0];
  // aspect = 1.0;
  // float fov = 2.0*atan( 1.0/projectionMatrix[1][1] );
  // fov = 1.0;
  // dir = vec3(uv.x*fov*aspect,uv.y*fov,-1.0) *mat3(modelViewMatrix);
  // dir = position;
  // eye = -(modelViewMatrix[3].xyz) * mat3(modelViewMatrix);
  
  cameraForward = worldDirection;// vec3(0,0,-1.0)*mat3(modelViewMatrix);

}