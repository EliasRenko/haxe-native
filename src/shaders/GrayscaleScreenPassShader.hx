package shaders;

import data.Shader;

@:shaderSourceVert("
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;
out vec2 TexCoord;

void main() {
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
    TexCoord = aTexCoord;
}
")

@:shaderSourceFrag("
#version 330 core
in vec2 TexCoord;
out vec4 FragColor;
uniform sampler2D uScreenTexture;

void main() {
    vec4 color = texture(uScreenTexture, TexCoord);
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    FragColor = vec4(vec3(luminance), color.a);
}
")

@:uniform("uScreenTexture", Texture)
class GrayscaleScreenPassShader extends Shader {
    public function new() {
        super();
    }
}
