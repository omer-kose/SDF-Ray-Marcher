#include "Camera.h"

Camera::Camera(glm::vec3 pos, glm::vec3 wUp, float yaw_in, float pitch_in)
    :
    front(glm::vec3(0.0f, 0.0f, -1.0f)),
    movementSpeed(SPEED),
    mouseSensivity(SENSIVITY),
    fov(FOV),
    lastX(SCR_WIDTH / 2),
    lastY(SCR_HEIGHT / 2)
{
    position = pos;
    worldUp = wUp;
    yaw = yaw_in;
    pitch = pitch_in;
    updateCameraVectors();
}

Camera::Camera(float posX, float posY, float posZ, float wUpX, float wUpY, float wUpZ, float yaw_in, float pitch_in)
    :
    front(glm::vec3(0.0f, 0.0f, -1.0f)),
    movementSpeed(SPEED),
    mouseSensivity(SENSIVITY),
    fov(FOV)
{
    position = glm::vec3(posX, posY, posZ);
    worldUp = glm::vec3(wUpX, wUpY, wUpZ);
    yaw = yaw_in;
    pitch = pitch_in;
    updateCameraVectors();
}

glm::mat4 Camera::getViewMatrix() const
{
    return glm::lookAt(position, position + front, worldUp);
}

float Camera::getFov() const
{
    return fov;
}

glm::vec3 Camera::getPosition() const
{
    return position;
}

glm::vec3 Camera::getFront() const
{
    return front;
}

glm::vec3 Camera::getRight() const
{
    return right;
}

glm::vec3 Camera::getUp() const
{
    return up;
}

void Camera::setSpeed(float speed_in)
{
    movementSpeed = speed_in;
}

void Camera::setSensivity(float sensivity_in)
{
    mouseSensivity = sensivity_in;
}

void Camera::setZoom(float fov_in)
{
    fov = fov_in;
}

void Camera::setLastX(double xPos)
{
    lastX = xPos;
}

void Camera::setLastY(double yPos)
{
    lastY = yPos;
}

void Camera::processKeyboard(Camera_Movement direction, double deltaTime, int speedUp)
{
    float velocity = movementSpeed * deltaTime * speedUp;
    if (direction == FORWARD)
        position += front * velocity;
    if (direction == BACKWARD)
        position -= front * velocity;
    if (direction == LEFT)
        position -= right * velocity;
    if (direction == RIGHT)
        position += right * velocity;
}


void Camera::processMouseMovement(double xPos, double yPos, GLboolean constrainPitch)
{
    //Calculate the offset from given mouse positions.
    double xOffset = xPos - lastX;
    //GLFW returns mouse coordinates relative to top-left corner of the screen
    //X increases in right direction
    //Y increases in bottom direction
    double yOffset = lastY - yPos; //We need to subtract in reverse order since y coordinates ranges in reverse order we want
    lastX = xPos;
    lastY = yPos;

    xOffset *= mouseSensivity;
    yOffset *= mouseSensivity;

    //TODO: Try to convert them into actual angles, you are just assigning offsets as angles.
    //Note that as we move the mouse to the right, we actually decrement the yaw angle so we need to subtract.
    yaw = glm::mod(yaw - xOffset, 360.0);
    pitch += yOffset;


    //If we are constructing orthonormal camera basis using [0,1,0] as world up pitch values close to
    //90.0 deegres can cause gimbal lock, so we may not create a proper orthonormal basis. Constrain it
    if (constrainPitch)
    {
        if (pitch > 89.0f)
            pitch = 89.0f;
        if (pitch < -89.0f)
            pitch = -89.0f;
    }

    //Calculated the angles update the basis
    updateCameraVectors();

}

void Camera::processMouseScroll(float yOffset)
{
    fov -= yOffset;
    if (fov < 1.0f)
        fov = 0.0f;
    if (fov > 45.0f)
        fov = 45.0f;
}


void Camera::moveCameraUp(double deltaTime, int speedUp)
{
    float velocity = movementSpeed * deltaTime * speedUp;
    position += glm::vec3(0.0, 1.0, 0.0) * velocity;
}

void Camera::moveCameraDown(double deltaTime, int speedUp)
{
    float velocity = movementSpeed * deltaTime * speedUp;
    position -= glm::vec3(0.0, 1.0, 0.0) * velocity;
}

void Camera::moveCamera(glm::vec3 direction, double deltaTime, int speedUp)
{
    float velocity = movementSpeed * deltaTime * speedUp;
    position += direction * velocity;
}


void Camera::updateCameraVectors()
{
    glm::vec3 newFront;
    //By mapping from spherical coordinates, to cartesian coordinates, we can convert yaw and pitch angles to direction vector
    newFront.x = cos(glm::radians(pitch)) * cos(glm::radians(yaw));
    newFront.y = sin(glm::radians(pitch));
    newFront.z = -cos(glm::radians(pitch)) * sin(glm::radians(yaw));
    front = newFront;
    //We got a new front vector recalculate right and up vectors
    right = glm::normalize(glm::cross(front, worldUp));
    up = glm::normalize(glm::cross(right, front));
}
