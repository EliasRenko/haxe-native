package shaders;

import data.Shader;

@:shaderSourceVert("
    #version 330 core

    layout (location = 0) in vec3 aPos;
    layout (location = 1) in vec2 aTexCoord;

    out vec2 TexCoord;

    uniform mat4 uMatrix;

    void main() {
        gl_Position = uMatrix * vec4(aPos, 1.0);
        TexCoord = aTexCoord;
    }
")

@:shaderSourceFrag("
    #version 330 core

    in vec2 TexCoord;
    out vec4 FragColor;

    uniform sampler2D uTexture;

    void main() {
        FragColor = texture(uTexture, TexCoord);
    }
")

@:uniform("uMatrix", Matrix)
@:uniform("uTexture", Texture)

class TexturedShader extends Shader {

    public function new() {
        super();
    }
}