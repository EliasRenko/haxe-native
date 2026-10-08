package shaders;

@:shaderVert("
    #version 300 es

    layout(location = 0) in vec3 aPosition;
    layout(location = 1) in vec2 aTexCoord;

    uniform mat4 uMatrix;

    out vec2 vTexCoord;

    void main() {
        gl_Position = uMatrix * vec4(aPosition, 1.0);
        vTexCoord = aTexCoord;
    }
")

@:shaderFrag("
    #version 300 es

    precision mediump float;

    uniform sampler2D uTexture;

    in vec2 vTexCoord;

    out vec4 fragColor;

    void main() {
        fragColor = texture(uTexture, vTexCoord);
    }
")
class TexturedShader extends Shader {

    @:uniform("uMatrix", 0)
    public var matrix:Uniform<Matrix>;

    @:uniform("uTexture", 1)
    public var texture:Uniform<Texture>;

    public function new() {
        super();
    }
}