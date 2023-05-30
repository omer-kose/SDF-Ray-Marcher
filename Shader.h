#ifndef SHADER_H
#define SHADER_H

#include <GL/glew.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>


#include <string>
#include <fstream>
#include <sstream>
#include <iostream>


class Shader
{
public:
    Shader();
	// constructor reads and builds the shader
	Shader(const char* vertexPath, const char* fragmentPath, const char* geometryPath = nullptr);
	// use/activate the shader
	void use();
	// utility uniform functions. Note that to call these functions, first you have to activate the shader program
	void setBool(const std::string &name, bool value) const;
	void setInt(const std::string &name, int value) const;
	void setFloat(const std::string &name, float value) const;
	void setVec2(const std::string& name, const glm::vec2& value) const;
	void setVec2(const std::string& name, float x, float y) const;
	void setVec3(const std::string& name, const glm::vec3& value) const;
	void setVec3(const std::string& name, float x, float y, float z) const;
	void setVec4(const std::string& name, const glm::vec4& value) const;
	void setVec4(const std::string& name, float x, float y, float z, float w) const;
	void setMat3(const std::string& name, const glm::mat3& matrix) const;
	void setMat4(const std::string& name, const glm::mat4& matrix) const;
	GLuint getID() const;
private:
	void checkCompileErrors(GLuint shader, std::string type) const;
private:
	// the program ID
	GLuint ID;

};

#endif
