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
uniform sampler2D uDepthTexture;

void main() {
    vec4 sceneColor = texture(uScreenTexture, TexCoord);
    float depth = texture(uDepthTexture, TexCoord).r;
    FragColor = vec4(vec3(1.0 - depth), sceneColor.a);
}
")

@:uniform("uScreenTexture", Texture)
@:uniform("uDepthTexture", Texture)
class DepthVisualizationShader extends Shader {
    public function new() {
        super();
    }
}
