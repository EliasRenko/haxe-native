package;

class ShaderDefinition {
	public final name:String;
	public final shaderId:Int;
	public final vertexSource:String;
	public final fragmentSource:String;

	public function new(name:String, shaderId:Int, vertexSource:String, fragmentSource:String) {
		this.name = name;
		this.shaderId = shaderId;
		this.vertexSource = vertexSource;
		this.fragmentSource = fragmentSource;
	}
}