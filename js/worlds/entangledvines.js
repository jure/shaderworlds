import * as THREE from 'three'

import wood1 from './wood1.jpg'
import fragment from './entangledvines.frag.glsl'
import vertex from './vertex.glsl'

const texture1 = new THREE.TextureLoader().load(wood1)

let leftControllerStart = null
let magicNumberX = 1.0
let magicNumberY = 2.0
let magicNumberZ = 1.0

const lightAcceleration = 2
const lightMaxSpeed = 10

// This is used for the sun flight animation
const lightParams = {
  offset: 0,
  speed: 0, // speed of the sun when in flight, not c
  accelerating: false,
  deccelerating: false,
  time: 0,
}

texture1.wrapS = texture1.wrapT = THREE.RepeatWrapping

export const material = new THREE.ShaderMaterial({
  side: THREE.DoubleSide,
  uniforms: {
    iTime: { value: 0 },
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
    leftControllerMatrix: { value: new THREE.Matrix4() },
    rightControllerMatrix: { value: new THREE.Matrix4() },
    leftControllerRotation: { value: new THREE.Quaternion() },
    magicNumberX: { value: magicNumberX },
    magicNumberY: { value: magicNumberY },
    magicNumberZ: { value: magicNumberZ },
    materialColor: { value: new THREE.Vector3(0.5, 0.4, 0.35) },
    lightOffset: { value: 0 },
    worldDirection: { value: new THREE.Vector3() },
    zNear: { value: 0 },
    zFar: { value: 0 },
  },
  vertexShader: vertex,
  fragmentShader: fragment,
})

export const fly = true

// Called every frame, given delta as time between frames
export const tick = (delta) => {
  lightParams.time = lightParams.time + delta
  if (lightParams.accelerating) {
    lightParams.speed = Math.min(
      lightParams.speed + lightAcceleration * lightParams.time,
      lightMaxSpeed
    )
    lightParams.offset += lightParams.speed * delta
  } else if (lightParams.deccelerating) {
    lightParams.speed = Math.max(
      lightParams.speed - 1.5 * lightAcceleration * lightParams.time,
      -1.5 * lightMaxSpeed
    )
    lightParams.offset += lightParams.speed * delta
    lightParams.offset = Math.max(0, lightParams.offset)
    if (lightParams.offset === 0) {
      lightParams.speed = 0
      lightParams.deccelerating = false
    }
  }
  material.uniforms.lightOffset.value = lightParams.offset
}

export const onSqueezeStartLeft = (event) => {
  lightParams.time = 0
  lightParams.accelerating = true
}

export const onSqueezeEndLeft = (event) => {
  lightParams.time = 0
  lightParams.accelerating = false
  lightParams.deccelerating = true
}

export const onSelectStartLeft = (event) => {
  leftControllerStart = material.uniforms.leftControllerPosition.value.clone()
}

// export const onSelectStartRight = (event) => {
//   rightControllerStart = material.uniforms.rightControllerPosition.value.clone()
// }

export const onSelectEndLeft = (event) => {
  leftControllerStart = null
  magicNumberX = material.uniforms.magicNumberX.value
  magicNumberY = material.uniforms.magicNumberY.value
  magicNumberZ = material.uniforms.magicNumberZ.value
}

export const updateLeftControllerPosition = (position) => {
  if (leftControllerStart) {
    material.uniforms.magicNumberY.value = Math.min(
      Math.max(magicNumberY + 2 * (position.y - leftControllerStart.y), 1),
      3
    )
    material.uniforms.magicNumberX.value = Math.min(
      Math.max(magicNumberX + 2 * (leftControllerStart.x - position.x), 0),
      1.0
    )
    material.uniforms.magicNumberZ.value = Math.min(
      Math.max(magicNumberZ + (leftControllerStart.z - position.z), 0),
      2
    )
  }
}

export const instructions = `
<span style="font-size:36px">Click to play</span>
<br /><br />
Move: WASD<br/>
Look: MOUSE<br />
In VR: <br />
Left trigger: holding & moving controller changes vines<br />
Left squeeze: accelerates the sun towards you<br />

Experimental! Works only on a high-end PC + Oculus Link.
`
