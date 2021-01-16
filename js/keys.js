const movement = {
  moveForward: false,
  moveLeft: false,
  moveRight: false,
  moveBackward: false,
}

export const onKeyDown = function (event) {
  switch (event.keyCode) {
    case 38: // up
    case 87: // w
      movement.moveForward = true
      break

    case 37: // left
    case 65: // a
      movement.moveLeft = true
      break

    case 40: // down
    case 83: // s
      movement.moveBackward = true
      break

    case 39: // right
    case 68: // d
      movement.moveRight = true
      break

    // case 32: // space
    //     if ( canJump === true ) velocity.y += 350;
    //     canJump = false;
    //     break;
  }
  return movement
}

export const onKeyUp = function (event) {
  switch (event.keyCode) {
    case 38: // up
    case 87: // w
      movement.moveForward = false
      break

    case 37: // left
    case 65: // a
      movement.moveLeft = false
      break

    case 40: // down
    case 83: // s
      movement.moveBackward = false
      break

    case 39: // right
    case 68: // d
      movement.moveRight = false
      break
  }
  return movement
}
