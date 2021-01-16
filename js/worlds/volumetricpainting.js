import * as THREE from 'three'

import bluenoise from './bluenoise.png'
import fragment from './volumetricpainting.frag.glsl'
import vertex from './vertex.glsl'

const texture1 = new THREE.TextureLoader().load(bluenoise)

texture1.type = THREE.FloatType
texture1.wrapS = texture1.wrapT = THREE.RepeatWrapping

// Init data texture - this keeps newly created objects
const textureSize = 512
const dataSize = 512 * 512

const data = new Float32Array(dataSize * 4)

// Prefill with x objects for test
for (let i = 0; i < 200; i++) {
  const index = i * 4
  data[index] = Math.random() * 10.0 - 5.0
  data[index + 1] = Math.random() * 5.0
  data[index + 2] = Math.random() * 10.0 - 5.0
  data[index + 3] = Math.random() < 0.5 ? 0.15 : 0.05
}

const dataTexture1 = new THREE.DataTexture(
  data,
  textureSize,
  textureSize,
  THREE.RGBAFormat,
  THREE.FloatType
)

const updatingDataTexture1 = {}
let dataTexture1LastEntry = 0

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
    dataTexture1: { value: dataTexture1 },
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

export const geometry = (main) => {
  const gridHelper = new THREE.GridHelper(20, 20)
  main.scene.add(gridHelper)

  // const geometry = new THREE.BoxGeometry(1, 1, 1)
  // const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 })
  // const cube = new THREE.Mesh(geometry, material)
  // cube.position.z = 3.0
  // cube.position.y = 1.0
  // main.scene.add(cube)
}

export const init = (main) => {
  main.dataTexture1 = dataTexture1
  main.dataTexture1LastEntry = 0
}

// What to do when controller select is pressed
const onSelectStartAbstract = (event, side, main, thing) => {
  const data = dataTexture1.image.data

  const startIndex = dataTexture1LastEntry * 4
  data[startIndex] = event.target.position.x
  data[startIndex + 1] = event.target.position.y
  data[startIndex + 2] = event.target.position.z
  data[startIndex + 3] = thing
  dataTexture1.needsUpdate = true
  // We start tracking
  updatingDataTexture1[side] = true
  console.log(event)
}

export const onSelectStartLeft = (event) => {
  return onSelectStartAbstract(event, 'left', this, 0.05)
}
export const onSelectStartRight = (event) => {
  return onSelectStartAbstract(event, 'right', this, 0.15)
}

const onSelectEndAbstract = (event, side, main) => {
  // Advance the index
  dataTexture1LastEntry += 1
  // Disable tracking the controller
  updatingDataTexture1[side] = false
}
export const onSelectEndLeft = (event) => {
  return onSelectEndAbstract(event, 'left', this)
}

export const onSelectEndRight = (event) => {
  return onSelectEndAbstract(event, 'right', this)
}

export const updateLeftControllerPosition = (position) => {
  if (updatingDataTexture1.left) {
    const data = dataTexture1.image.data
    console.log('updating left')
    console.log('left', position)
    const startIndex = dataTexture1LastEntry * 4
    data[startIndex] = position.x
    data[startIndex + 1] = position.y
    data[startIndex + 2] = position.z
    // data[startIndex + 3] = 1.0 // Can't update the type of thing yet
    dataTexture1.needsUpdate = true
  }
}

export const updateRightControllerPosition = (position) => {
  if (updatingDataTexture1.right) {
    console.log('updating left')
    console.log('right', position)
    const startIndex = dataTexture1LastEntry * 4
    data[startIndex] = position.x
    data[startIndex + 1] = position.y
    data[startIndex + 2] = position.z
    // data[startIndex + 3] = 1.0
    dataTexture1.needsUpdate = true
  }
}

export const fly = true
export const cameraOffset = new THREE.Vector3(0, 0.5, 0)