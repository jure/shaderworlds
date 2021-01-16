import * as THREE from 'three'

import bluenoise from './bluenoise256.png'
import noise from './noise64.png'
import fragment from './volumetricexplosion.frag.glsl'
import vertex from './vertex.glsl'

const texture1 = new THREE.TextureLoader().load(bluenoise)

texture1.type = THREE.FloatType
texture1.wrapS = THREE.RepeatWrapping
texture1.wrapT = THREE.RepeatWrapping
// texture1.flipY = true
// texture1.needsUpdate = true

const texture2 = new THREE.TextureLoader().load(noise)
texture2.type = THREE.FloatType
texture2.wrapS = THREE.RepeatWrapping
texture2.wrapT = THREE.RepeatWrapping
// texture1.flipY = true
// texture1.needsUpdate = true

export const material = new THREE.ShaderMaterial({
  // extensions: {
  //   derivatives: '#extension GL_OES_standard_derivatives : enable',
  // },
  side: THREE.DoubleSide,
  uniforms: {
    iTime: { value: 0 },
    // progress: { value: 0 },
    iFrame: { value: 0 },
    mouse: { value: new THREE.Vector2(0, 0) },
    iChannel0: { value: texture1 },
    iChannel1: { value: texture2 },
    iChannelResolution: {
      value: [new THREE.Vector2(256.0, 256.0), new THREE.Vector2(64.0, 64.0)],
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
  transparent: true,
  premultipliedAlpha: true,
  depthTest: true,
  depthWrite: true,
})

export const geometry = (main) => {}

export const fly = true