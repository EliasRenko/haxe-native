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
    
    // Scanline effect
    float scanline = sin(TexCoord.y * 480.0 * 2.0) * 0.1 + 0.9;
    
    // Vignette effect
    vec2 center = TexCoord - 0.5;
    float vignette = 1.0 - dot(center, center) * 0.5;
    
    FragColor = vec4(color.rgb * scanline * vignette, color.a);
}
")

@:uniform("uScreenTexture", Texture)

class PostProccessingShader extends Shader {

    public function new() {
        super();
    }
}