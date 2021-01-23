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

  cameraForward = worldDirection;
}