package shaders;

import data.Shader;

@:shaderSourceVert("
    #version 330 core

    layout (location = 0) in vec3 aPosition;
    layout (location = 1) in vec2 aTexCoord;
    layout (location = 2) in float aTexIndex;
    layout (location = 3) in vec4 aColor;

    uniform mat4 uMatrix;

    out vec2 TexCoord;
    out float TexIndex;
    out vec4 Color;

    void main() {
        TexCoord = aTexCoord;
        TexIndex = aTexIndex;
        Color = aColor;

        gl_Position = uMatrix * vec4(aPosition, 1.0);
    }
")

@:shaderSourceFrag("
    #version 330 core

    in vec2 TexCoord;
    in float TexIndex;
    in vec4 Color;

    out vec4 FragColor;

    uniform sampler2D uTexture;
    uniform sampler2D uFont;

    void main() {
        vec4 color;

        if (TexIndex < 0.5) {
            // Sprite atlas (texture unit 0)
            color = texture(uTexture, TexCoord);
        } else {
            // Font atlas (texture unit 1) — same alpha-mask decode as text.frag
            vec4 s = texture(uFont, TexCoord);
            float mask = s.r * s.a;
            color = vec4(1.0, 1.0, 1.0, mask);
        }

        if (color.a < 0.01) discard;

        FragColor = color * Color;
    }
")

@:uniform("uMatrix", Matrix)
@:uniform("uTexture", Texture)
@:uniform("uFont", Texture)

class UiShader extends Shader {

    public function new() {
        super();
    }
}