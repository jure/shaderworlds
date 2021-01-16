import * as THREE from 'three'

import fragment from './fractalpyramid.frag.glsl'
import vertex from './vertex.glsl'

export const material = new THREE.ShaderMaterial({
  side: THREE.DoubleSide,
  uniforms: {
    iTime: { value: 0 },
    iFrame: { value: 0 },
    mouse: { value: new THREE.Vector2(0, 0) },
    iChannelResolution: {
      value: [new THREE.Vector2(256.0, 256.0)],
    },
    localCameraPos: { value: new THREE.Vector3(0) },
    resolution: { value: new THREE.Vector4() },
    virtualCameraQuat: { value: new THREE.Vector4(0, 0, 0, 0) },
    virtualCameraPosition: { value: new THREE.Vector3(0, 0, 0) },
    leftControllerPosition: { value: new THREE.Vector3(0, 0, 0) },
    rightControllerPosition: { value: new THREE.Vector3(0, 0, 0) },
    zNear: { value: 0 },
    zFar: { value: 0 },
    worldDirection: { value: new THREE.Vector3() },
  },
  vertexShader: vertex,
  fragmentShader: fragment,
})

export const geometry = (main) => {}

export const fly = true
export const cameraOffset = new THREE.Vector3(0, 0.5, 0)