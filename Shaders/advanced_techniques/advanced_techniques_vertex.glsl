#version 410 core

layout (location = 0) in vec3 pos_in;
layout (location = 1) in vec2 tex_in;

out vec2 uv;

void main()
{
    uv = tex_in;
    gl_Position = vec4(pos_in.xy, 0.0, 1.0);
}
