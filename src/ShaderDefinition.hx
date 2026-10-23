package;

class ShaderDefinition {
    public final name:String;
    public final shaderId:Int;
    public final vertexSource:String;
    public final fragmentSource:String;
    public final uniforms:Array<UniformDefinition>;

    public function new(
        name:String,
        shaderId:Int,
        vertexSource:String,
        fragmentSource:String,
        uniforms:Array<UniformDefinition>
    ) {
        this.name = name;
        this.shaderId = shaderId;
        this.vertexSource = vertexSource;
        this.fragmentSource = fragmentSource;
        this.uniforms = uniforms;
    }
}
