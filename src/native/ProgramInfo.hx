package native;

import data.Shader as DataShader;
import data.AttributeInfo;
import data.UniformInfo;

typedef Program = Int;

class ProgramInfo {

	// Publics
	public var program(get, null):Program;
	public var vao(get, null):Int;
	public var attributeInfos(get, null):Array<AttributeInfo>;
	public var uniformInfos(get, null):Array<UniformInfo>;
	public var name(get, null):String;
	public var vertexStride(get, null):UInt;

	// Privates
	@:allow(native.Renderer) private var __vao:Int;
	@:allow(native.Renderer) private var __program:Program;
	private var __name:String;
	private var __attributeInfos:Array<data.AttributeInfo>;
	private var __uniformInfos:Array<data.UniformInfo>;
	private var __vertexStride:UInt;

	public function new(name:String, program:Program, vao:Int, attributeInfos:Array<data.AttributeInfo>, uniformInfos:Array<data.UniformInfo>, vertexStride:UInt) {
		__name = name;
		__program = program;
		__vao = vao;
		__attributeInfos = attributeInfos;
		__uniformInfos = uniformInfos;
		__vertexStride = vertexStride;
	}

	// public function getUniformAt(index:Int):Null<data.UniformInfo> {
	// 	if (index < 0 || index >= uniformInfos.length) return null;
	// 	return uniformInfos[index];
	// }

	// Getters and setters
	private function get_attributeInfos():Array<AttributeInfo> {
		return __attributeInfos;
	}

	private function get_program():Program {
		return __program;
	}

	private function get_vao():GL.GlUInt {
		return __vao;
	}

	private function get_name():String {
		return __name;
	}

	private function get_uniformInfos():Array<UniformInfo> {
		return __uniformInfos;
	}

	private function get_vertexStride():UInt {
		return __vertexStride;
	}
}
