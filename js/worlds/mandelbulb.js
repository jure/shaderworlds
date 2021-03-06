import * as THREE from 'three'

import bluenoise from './bluenoise.png'
import fragment from './mandelbulb.frag.glsl'
import vertex from './vertex.glsl'

const texture1 = new THREE.TextureLoader().load(bluenoise)

texture1.type = THREE.FloatType
texture1.wrapS = texture1.wrapT = THREE.RepeatWrapping

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
    iChannelResolution: {
      value: [new THREE.Vector2(1024.0, 1024.0)],
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
  transparent: false,
  premultipliedAlpha: true,
  depthTest: false,
  depthWrite: false,
})

export const geometry = () => {}

export const fly = true
export const cameraOffset = new THREE.Vector3(0, 1, 2.5)