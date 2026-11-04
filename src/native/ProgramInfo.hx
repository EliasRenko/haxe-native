package native;

//import GL;
import data.Shader as DataShader;
import data.AttributeInfo;
import data.UniformInfo;

typedef UniformLocation = Int;
typedef Program = Int;

class ProgramInfo {

	public var program:Program;
	public var vao:GL.GlUInt;
	public var attributesInfo:Array<data.AttributeInfo>;
	public var uniforms:Array<data.UniformInfo>;
	public var name(get, null):String;
	public var vertexStride:UInt;

	private var __name:String;

	public function new(name:String, program:Program, vao:Int, attributesInfo:Array<data.AttributeInfo>, uniforms:Array<data.UniformInfo>, vertexStride:UInt) {
		__name = name;
		this.program = program;
		this.vao = vao;
		this.attributesInfo = attributesInfo;
		this.uniforms = uniforms;
		this.vertexStride = vertexStride;
	}

	public function getUniformAt(index:Int):Null<data.UniformInfo> {
		if (index < 0 || index >= uniforms.length) return null;
		return uniforms[index];
	}

	private function get_name():String {
		return __name;
	}
}
