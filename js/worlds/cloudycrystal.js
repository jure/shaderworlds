import * as THREE from 'three'

import fragment from './cloudycrystal.frag.glsl'
import vertex from './vertex.glsl'

let leftControllerStart = null
let rightControllerStart = null
let rotationX = 0
let rotationY = 0
let rotationZ = 0
let numberX = 0
let numberY = 0
let numberZ = 0

export const material = new THREE.ShaderMaterial({
  side: THREE.DoubleSide,
  uniforms: {
    iTime: { value: 0 },
    // progress: { value: 0 },
    iFrame: { value: 0 },
    mouse: { value: new THREE.Vector2(0, 0) },
    localCameraPos: { value: new THREE.Vector3(0) },
    resolution: { value: new THREE.Vector4() },
    virtualCameraQuat: { value: new THREE.Vector4(0, 0, 0, 0) },
    virtualCameraPosition: { value: new THREE.Vector3(0, 0, 0) },
    leftControllerPosition: { value: new THREE.Vector3(0, 0, 0) },
    rightControllerPosition: { value: new THREE.Vector3(0, 0, 0) },
    rotationY: { value: rotationY },
    rotationX: { value: rotationX },
    rotationZ: { value: rotationZ },
    numberXYZ: { value: new THREE.Vector3()},
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
export const cameraOffset = new THREE.Vector3(0, 0, 1)

export const onSelectStartLeft = (event) => {
  leftControllerStart = material.uniforms.leftControllerPosition.value.clone()
}

export const onSelectStartRight = (event) => {
  rightControllerStart = material.uniforms.rightControllerPosition.value.clone()
}

export const onSelectEndLeft = (event) => {
  leftControllerStart = null
  rotationY = material.uniforms.rotationY.value
  rotationX = material.uniforms.rotationX.value
  rotationZ = material.uniforms.rotationZ.value
}

export const onSelectEndRight = (event) => {
  rightControllerStart = null
  numberX = material.uniforms.numberXYZ.value.x
  numberY = material.uniforms.numberXYZ.value.y
  numberZ = material.uniforms.numberXYZ.value.z
}

export const updateLeftControllerPosition = (position) => {
  if (leftControllerStart) {
    material.uniforms.rotationY.value = Math.min(
      Math.max(rotationY + 10 * (position.y - leftControllerStart.y), -50),
      50
    )
    material.uniforms.rotationX.value = Math.min(
      Math.max(rotationX + 10 * (leftControllerStart.x - position.x), -50),
      50
    )
    material.uniforms.rotationZ.value = Math.min(
      Math.max(rotationZ + 10 * (leftControllerStart.z - position.z), -50),
      50
    )
  }
}

export const updateRightControllerPosition = (position) => {
  if (rightControllerStart) {
    material.uniforms.numberXYZ.value.y = Math.min(
      Math.max(numberX + (position.y - rightControllerStart.y), -1),
      1
    )
    material.uniforms.numberXYZ.value.x = Math.min(
      Math.max(numberY + (position.x - rightControllerStart.x), -1),
      1
    )
    material.uniforms.numberXYZ.value.z = Math.min(
      Math.max(numberZ + (position.z - rightControllerStart.z), -1),
      1
    )
  }
}
