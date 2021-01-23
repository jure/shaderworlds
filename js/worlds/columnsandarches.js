import * as THREE from 'three'

import bluenoise from './bluenoise.png'
import fragment from './columnsandarches.frag.glsl'
import vertex from './vertex.glsl'

const texture1 = new THREE.TextureLoader().load(bluenoise)

let leftControllerStart = null
let rightControllerStart = null
let ceilingHeight = 2
let columnDistX = 5
let columnDistZ = 5
let materialColorR = 0
let materialColorG = 0
let materialColorB = 0

const lightAcceleration = 3
const lightMaxSpeed = 20

// This is used for the orb flight animation
const lightParams = {
  offset: 0,
  speed: 0, // speed of the orb when in flight, not c
  accelerating: false,
  deccelerating: false,
  time: 0,
}

texture1.type = THREE.FloatType
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
    ceilingHeight: { value: ceilingHeight },
    columnDistX: { value: columnDistX },
    columnDistZ: { value: columnDistZ },
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

export const onSelectStartRight = (event) => {
  rightControllerStart = material.uniforms.rightControllerPosition.value.clone()
}

export const onSelectEndLeft = (event) => {
  leftControllerStart = null
  ceilingHeight = material.uniforms.ceilingHeight.value
  columnDistX = material.uniforms.columnDistX.value
  columnDistZ = material.uniforms.columnDistZ.value
}

export const onSelectEndRight = (event) => {
  rightControllerStart = null
  materialColorR = material.uniforms.materialColor.value.x
  materialColorG = material.uniforms.materialColor.value.y
  materialColorB = material.uniforms.materialColor.value.z
}

export const updateLeftControllerPosition = (position) => {
  if (leftControllerStart) {
    material.uniforms.ceilingHeight.value = Math.min(
      Math.max(ceilingHeight + 10 * (position.y - leftControllerStart.y), 1),
      50
    )
    material.uniforms.columnDistX.value = Math.min(
      Math.max(columnDistX + 10 * (leftControllerStart.x - position.x), 1),
      30
    )
    material.uniforms.columnDistZ.value = Math.min(
      Math.max(columnDistZ + 10 * (leftControllerStart.z - position.z), 1),
      30
    )
  }
}

export const updateRightControllerPosition = (position) => {
  if (rightControllerStart) {
    material.uniforms.materialColor.value.y = Math.min(
      Math.max(materialColorR + (position.y - rightControllerStart.y), 0),
      1
    )
    material.uniforms.materialColor.value.x = Math.min(
      Math.max(materialColorG + (position.x - rightControllerStart.x), 0),
      1
    )
    material.uniforms.materialColor.value.z = Math.min(
      Math.max(materialColorB + (position.z - rightControllerStart.z), 0),
      1
    )
  }
}

export const cameraOffset = new THREE.Vector3(3, 1.0, -6)

export const instructions = `
<span style="font-size:36px">Click to play</span>
<br /><br />
Move: WASD<br/>
Look: MOUSE<br />
In VR: <br />
Left trigger: holding & moving controller alters the space<br />
Left squeeze: accelerates a light orb forward<br />
Right trigger: holding & moving adjusts color of the space<br />

Experimental! Works only on a high-end PC + Oculus Link.
`
