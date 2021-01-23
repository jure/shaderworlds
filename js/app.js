import * as THREE from 'three'
import { PointerLockControls } from 'three/examples/jsm/controls/PointerLockControls'
import { VRButton } from 'three/examples/jsm/webxr/VRButton.js'
// import { XRControllerModelFactory } from 'three/examples/jsm/webxr/XRControllerModelFactory'
import { onKeyUp, onKeyDown } from './keys'
import * as worlds from './worlds'

export default class Shaderworlds {
  constructor(options) {
    const that = this
    // This comes from keys
    this.movement = {}
    this.currentFrame = 0
    this.prevTime = performance.now()
    this.velocity = new THREE.Vector3()
    this.direction = new THREE.Vector3()

    this.leftControllerWorldPosition = new THREE.Vector3()
    this.rightControllerWorldPosition = new THREE.Vector3()

    this.leftControllerRotation = new THREE.Quaternion()
    this.rightControllerRotation = new THREE.Quaternion()

    this.currentProjectionMatrix = new THREE.Matrix4()

    const blocker = document.getElementById('blocker')
    this.instructions = document.getElementById('instructions')

    this.scene = new THREE.Scene()

    this.container = options.dom
    this.width = window.innerWidth
    this.height = window.innerHeight

    // Setting up an XR-enabled renderer
    this.renderer = new THREE.WebGLRenderer({ antialias: true })
    this.renderer.setPixelRatio(window.devicePixelRatio)
    this.renderer.setSize(this.width, this.height)
    this.renderer.setClearColor(0x000000, 1)
    this.renderer.physicallyCorrectLights = false
    this.renderer.outputEncoding = THREE.sRGBEncoding
    this.renderer.xr.enabled = true
    this.container.appendChild(this.renderer.domElement)

    const aspect = this.width / this.height

    // Set up camera
    this.cameraSingle = new THREE.PerspectiveCamera(50, aspect, 0.1, 1000)
    this.cameraSingle.position.set(0, 0, 0)
    this.cameraSingleQuat = new THREE.Quaternion()
    const controls = new PointerLockControls(this.cameraSingle, document.body)
    this.controls = controls

    // Set up dolly for camera movement
    // https://stackoverflow.com/a/34471170/790483
    this.dolly = new THREE.Group()
    this.dolly.position.set(0, 0, 0)
    this.dolly.add(this.cameraSingle)
    this.scene.add(this.dolly)

    // Pointer lock
    this.instructions.addEventListener(
      'click',
      function () {
        controls.lock()
      },
      false
    )

    this.controls.addEventListener('lock', function () {
      that.instructions.style.display = 'none'
      blocker.style.display = 'none'
    })

    this.controls.addEventListener('unlock', function () {
      blocker.style.display = 'block'
      that.instructions.style.display = ''
    })

    // One controller
    // this.controllerL = this.renderer.xr.getController(1)
    // this.controllerL.addEventListener( 'selectstart', onSelectStart );
    // this.controllerL.addEventListener( 'selectend', onSelectEnd );
    // this.controllerL.addEventListener('connected', function (event) {
    //   this.add(that.buildController(event.data))
    // })
    // this.scene.add(this.controllerL)

    that.leftAxis = new THREE.Vector2()

    // const controllerModelFactory = new XRControllerModelFactory()

    this.controllerGrip = this.renderer.xr.getControllerGrip(0)
    // this.controllerGrip.add(
    //   controllerModelFactory.createControllerModel(this.controllerGrip)
    // )
    // this.scene.add(this.controllerGrip)

    document.body.appendChild(VRButton.createButton(this.renderer))

    this.leftController = this.renderer.xr.getController(0)
    this.rightController = this.renderer.xr.getController(1)
    this.dolly.add(this.leftController)
    this.dolly.add(this.rightController)

    this.time = 0
    this.isPlaying = true

    // Squeeze state
    this.leftSqueeze = null
    this.rightSqueeze = null

    this.render = this.render.bind(this)
    this.addObjects()
    this.resize()
    this.setupResize()
    this.keyEvents()

    let currentBlockerStyle
    this.renderer.xr.addEventListener('sessionstart', () => {
      currentBlockerStyle = blocker.style.display
      blocker.style.display = 'none'
      // Parent the full screen quad to the new camera
      const currentCamera = this.renderer.xr.getCamera(that.cameraSingle)
      currentCamera.add(this.planeL)
      this.scene.add(currentCamera)
    })
    this.renderer.xr.addEventListener('sessionend', () => {
      blocker.style.display = currentBlockerStyle
      this.cameraSingle.add(this.planeL)
      this.resize()
      this._updateCoverQuad()
    })

    this.renderer.setAnimationLoop(this.render)
  }

  keyEvents() {
    document.addEventListener(
      'keydown',
      (e) => {
        this.movement = onKeyDown(e)
      },
      false
    )
    document.addEventListener(
      'keyup',
      (e) => {
        this.movement = onKeyUp(e)
      },
      false
    )
  }

  buildController(data) {
    // let geometry, material
    // switch (data.targetRayMode) {
    //   case 'tracked-pointer':
    //     geometry = new THREE.BufferGeometry()
    //     geometry.setAttribute(
    //       'position',
    //       new THREE.Float32BufferAttribute([0, 0, 0, 0, 0, -1], 3)
    //     )
    //     geometry.setAttribute(
    //       'color',
    //       new THREE.Float32BufferAttribute([0.5, 0.5, 0.5, 0, 0, 0], 3)
    //     )
    //     material = new THREE.LineBasicMaterial({
    //       vertexColors: true,
    //       blending: THREE.AdditiveBlending,
    //     })
    //     return new THREE.Line(geometry, material)
    //   case 'gaze':
    //     geometry = new THREE.RingBufferGeometry(0.02, 0.04, 32).translate(
    //       0,
    //       0,
    //       -1
    //     )
    //     material = new THREE.MeshBasicMaterial({
    //       opacity: 0.5,
    //       transparent: true,
    //     })
    //     return new THREE.Mesh(geometry, material)
    // }
  }

  setupResize() {
    window.addEventListener('resize', this.resize.bind(this))
  }

  resize() {
    this.cameraSingle.aspect = window.innerWidth / window.innerHeight
    this.cameraSingle.updateProjectionMatrix()

    this.renderer.setSize(window.innerWidth, window.innerHeight)

    this._updateCoverQuad()
  }

  _updateCoverQuad(options = {}) {
    const quadDimensions = this._calcCoverQuad({ camera: options.camera })
    this.planeL.geometry = new THREE.PlaneGeometry(
      1 * quadDimensions.width,
      1 * quadDimensions.height,
      1,
      1
    )
  }

  _calcCoverQuad(options = {}) {
    const camera = options.camera || this.cameraSingle
    const distanceOfPlaneFromCamera = options.dist || this.planeL.position.z
    const fovRadians =
      2.0 * Math.atan(1.0 / camera.projectionMatrix.elements[5])

    const height =
      2 * Math.tan(fovRadians / 2) * Math.abs(distanceOfPlaneFromCamera)

    // https://stackoverflow.com/a/46195462
    const aspect =
      camera.projectionMatrix.elements[5] / camera.projectionMatrix.elements[0]
    const width = height * aspect
    return {
      width: width,
      height: height,
    }
  }

  checkerboard(segments = 8) {
    const geometry = new THREE.PlaneGeometry(100, 100, segments, segments)
    const materialEven = new THREE.MeshBasicMaterial({ color: 0xccccfc })
    const materialOdd = new THREE.MeshBasicMaterial({ color: 0x444464 })
    const materials = [materialEven, materialOdd]

    for (const x in [(0).segments]) {
      for (const y in [(0).segments]) {
        const i = x * segments + y
        const j = 2 * i
        geometry.faces[j].materialIndex = geometry.faces[j + 1].materialIndex =
          (x + y) % 2
      }
    }

    return new THREE.Mesh(geometry, new THREE.MeshFaceMaterial(materials))
  }

  addObjects() {
    this.cameraWorldDirection = new THREE.Vector3()
    // strip the starting ? and find the correct world, or default to worlds/soul.js
    const worldName = window.location.search.replace(/^\?/, '') || 'soul'
    this.world = worlds[worldName] || worlds.soul
    
    // Update the on screen instructions if available
    this.world.instructions && (this.instructions.innerHTML = this.world.instructions)
    this.material = this.world.material
    if (this.world.cameraOffset) {
      this.dolly.position.set(
        this.world.cameraOffset.x,
        this.world.cameraOffset.y,
        this.world.cameraOffset.z
      )
    }
    const that = this

    const quadDimensions = this._calcCoverQuad({ dist: 5 })
    // Quad covering the screen
    this.geometryL = new THREE.PlaneGeometry(
      quadDimensions.width,
      quadDimensions.height,
      1,
      1
    )
    this.planeL = new THREE.Mesh(this.geometryL, this.material)
    this.planeL.translateZ(-5)
    this.planeL.frustumCulled = false

    this.planeL.onBeforeRender = function (
      renderer,
      scene,
      camera,
      geometry,
      material,
      group
    ) {
      that.material.uniforms.localCameraPos.value.setFromMatrixPosition(
        camera.matrixWorld
      )
      that.planeL.worldToLocal(that.material.uniforms.localCameraPos.value)

      // Get world direction without updating world matrix
      // https://github.com/mrdoob/three.js/blob/dev/src/cameras/Camera.js#L46
      const e = camera.matrixWorld.elements
      that.cameraWorldDirection.set(-e[8], -e[9], -e[10]).normalize()
      that.material.uniforms.worldDirection.value = that.cameraWorldDirection

      that.material.uniforms.resolution.value = that._calcResolution(
        camera.width * 1,
        camera.height * 1
      )
    }

    this.cameraSingle.add(this.planeL)

    // Add "normal" polygonal geometry if needed
    this.world.geometry && this.world.geometry(this)

    // Set up listeners if any are provided by the world
    this.world.onSelectStartLeft &&
      this.leftController.addEventListener(
        'selectstart',
        this.world.onSelectStartLeft.bind(this)
      )
    this.world.onSelectStartRight &&
      this.rightController.addEventListener(
        'selectstart',
        this.world.onSelectStartRight.bind(this)
      )
    this.world.onSelectEndLeft &&
      this.leftController.addEventListener(
        'selectend',
        this.world.onSelectEndLeft.bind(this)
      )
    this.world.onSelectEndRight &&
      this.rightController.addEventListener(
        'selectend',
        this.world.onSelectEndRight.bind(this)
      )
  }

  _calcResolution(width, height, imageAspect) {
    imageAspect ||= 1
    let a1
    let a2
    if (height / width > imageAspect) {
      a1 = (width / height) * imageAspect
      a2 = 1
    } else {
      a1 = 1
      a2 = height / width / imageAspect
    }

    return {
      x: width,
      y: height,
      z: a1,
      w: a2,
    }
  }

  applyVelocity(delta) {
    this.direction.applyQuaternion(this.cameraSingleQuat)

    const SPEED = 0.1
    const factor = this.direction.length()
    if (this.world.fly) {
      this.velocity.copy(this.direction)
      this.velocity.multiplyScalar(SPEED * 16.66667)
    } else {
      // What is this, really? Must be a better name for it
      const vector2 = new THREE.Vector2()
      vector2.set(this.direction.x, this.direction.z)
      vector2.setLength(factor * SPEED * 16.66667)
      this.velocity.x = vector2.x
      this.velocity.z = vector2.y
    }

    if (this.velocity.z !== 0) {
      this.dolly.position.z += this.velocity.z * delta
    }
    if (this.velocity.x !== 0) {
      this.dolly.position.x += this.velocity.x * delta
    }
    if (this.velocity.y !== 0) {
      this.dolly.position.y += this.velocity.y * delta
    }
  }

  // Squeeze events don't current work on Link, emulating them
  // with float button values. Caution: we SHOULDN'T listen to the
  // squeeze events on xr.session AND synthesize events based on
  // float values, as that will cause double events on platforms
  // where the default events fire.
  checkSqueeze() {
    // Left squeeze
    if (
      this.renderer.xr.getSession().inputSources[0]?.gamepad.buttons[1]?.value >
        0.98 &&
      !this.leftSqueeze
    ) {
      this.world.onSqueezeStartLeft && this.world.onSqueezeStartLeft()
      this.leftSqueeze = true
    } else if (
      this.renderer.xr.getSession().inputSources[0]?.gamepad.buttons[1]?.value <
        0.02 &&
      this.leftSqueeze
    ) {
      this.world.onSqueezeEndLeft && this.world.onSqueezeEndLeft()
      this.leftSqueeze = false
    }

    // Right squeeze
    if (
      this.renderer.xr.getSession().inputSources[1]?.gamepad.buttons[1]?.value >
        0.98 &&
      !this.rightSqueeze
    ) {
      this.world.onSqueezeStartRight && this.world.onSqueezeStartRight()
      this.rightSqueeze = true
    } else if (
      this.renderer.xr.getSession().inputSources[1]?.gamepad.buttons[1]?.value <
        0.02 &&
      this.rightSqueeze
    ) {
      this.world.onSqueezeEndLeft && this.world.onSqueezeEndLeft()
      this.rightSqueeze = false
    }
  }

  render(time, frame, cameras) {
    this.material.uniforms.zNear.value = this.cameraSingle.near
    this.material.uniforms.zFar.value = this.cameraSingle.far
    this.currentFrame += 1

    this.time = performance.now()

    const delta = (this.time - this.prevTime) / 1000

    // Check if the world also wants to do something per frame
    this.world.tick && this.world.tick(delta)

    if (this.controls.isLocked === true) {
      const moveBackward = this.movement.moveBackward || 0
      const moveForward = this.movement.moveForward || 0
      const moveLeft = this.movement.moveLeft || 0
      const moveRight = this.movement.moveRight || 0

      // TODO: Reintroduce smoother movement when not in VR
      // Slow it down each delta
      // this.velocity.x -= this.velocity.x * 10.0 * delta
      // this.velocity.z -= this.velocity.z * 10.0 * delta
      // if (this.velocity.y) this.velocity.y -= this.velocity.y * 10.0 * delta

      this.direction.y = 0
      this.direction.z = Number(moveBackward) - Number(moveForward)
      this.direction.x = Number(moveRight) - Number(moveLeft)
      this.direction.normalize() // this ensures consistent movements in all directions
    } else if (
      this.renderer.xr.isPresenting &&
      this.renderer.xr.getSession().inputSources[0]
    ) {
      // TODO: This is super hacky.
      this.direction.y = 0
      this.direction.x = this.renderer.xr.getSession().inputSources[0]?.gamepad?.axes[2]
      this.direction.z = this.renderer.xr.getSession().inputSources[0]?.gamepad?.axes[3]
    }

    this.material.uniforms.iTime.value = this.time
    this.material.uniforms.iFrame.value = this.currentFrame

    if (this.renderer.xr.isPresenting) {
      this.checkSqueeze()

      const currentCamera = this.renderer.xr.getCamera(this.cameraSingle)
      currentCamera.getWorldQuaternion(this.cameraSingleQuat)
      // this.applyVelocity(delta)

      // The WebXR emulator specifies a projection matrix for the main camera
      // with NaN elements (e.g. HTC Vive emulator...)
      // So we need to work around it (poorly) for now,
      // by not updating the full screen quad.
      if (
        !isNaN(currentCamera.projectionMatrix.elements[5]) &&
        this.currentProjectionMatrix.elements !==
          currentCamera.projectionMatrix.elements
      ) {
        this._updateCoverQuad({ camera: currentCamera })
        this.currentProjectionMatrix.copy(currentCamera.projectionMatrix)
      }

      this.leftController.getWorldPosition(this.leftControllerWorldPosition)
      this.material.uniforms.leftControllerPosition.value = this.leftControllerWorldPosition
      this.rightController.getWorldPosition(this.rightControllerWorldPosition)
      this.material.uniforms.rightControllerPosition.value = this.rightControllerWorldPosition

      this.leftController.updateWorldMatrix()
      this.material.uniforms.leftControllerMatrix &&
        this.material.uniforms.leftControllerMatrix.value.copy(
          this.leftController.matrixWorld.invert()
        )
      this.rightController.updateWorldMatrix()
      this.material.uniforms.leftControllerMatrix &&
        this.material.uniforms.rightControllerMatrix.value.copy(
          this.rightController.matrixWorld.invert()
        )

      this.leftController.getWorldQuaternion(this.leftControllerRotation)
      this.rightController.getWorldQuaternion(this.rightControllerRotation)

      // TODO: Extract common material base so that we don't have to check for shader features
      this.material.uniforms.leftControllerRotation &&
        (this.material.uniforms.leftControllerRotation.value = this.leftControllerRotation.invert())
      this.material.uniforms.rightControllerRotation &&
        (this.material.uniforms.rightControllerRotation.value = this.rightControllerRotation.invert())

      // Also update the world with the controller position, in case it wants to do something with that
      if (this.world.updateLeftControllerPosition) {
        this.world.updateLeftControllerPosition(
          this.leftControllerWorldPosition
        )
      }

      if (this.world.updateRightControllerPosition) {
        this.world.updateRightControllerPosition(
          this.rightControllerWorldPosition
        )
      }

      this.applyVelocity(delta)
      this.material.uniforms.virtualCameraQuat.value = this.cameraSingleQuat.invert()
      this.material.uniforms.virtualCameraPosition.value.setFromMatrixPosition(
        currentCamera.matrixWorld
      )
    } else {
      this.cameraSingle.getWorldQuaternion(this.cameraSingleQuat)
      this.applyVelocity(delta)
      this.material.uniforms.virtualCameraQuat.value = this.cameraSingleQuat.invert()
      this.material.uniforms.virtualCameraPosition.value.setFromMatrixPosition(
        this.cameraSingle.matrixWorld
      )
      
    }
    this.prevTime = this.time

    this.renderer.render(this.scene, this.cameraSingle)
  }
}

// eslint-disable-next-line
new Shaderworlds({
  dom: document.getElementById('container'),
})
