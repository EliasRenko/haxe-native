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
    uniform bool silhouette = false;
    uniform vec4 silhouetteColor = vec4(1.0);
    uniform float uAlpha = 1.0;

    void main() {
        if (silhouette) {
            FragColor = silhouetteColor;
        } else {
            vec4 texColor = texture(uTexture, TexCoord);
            FragColor = vec4(texColor.rgb, texColor.a * uAlpha);
        }
    }
")

@:uniform("uMatrix", Matrix)
@:uniform("uTexture", Texture)
@:uniform("silhouette", Bool)
@:uniform("silhouetteColor", Vec4)
@:uniform("uAlpha", Float)

class TexturedShader extends Shader {

    public function new() {
        super();
    }
}