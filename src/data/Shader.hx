package data;

import haxe.ds.IntMap;
import haxe.ds.StringMap;

@:autoBuild(ShaderGenMacro.buildId())
class Shader {
	public var programInfoIndex:Int = -1;

	private var uniforms:IntMap<ShaderUniform> = new IntMap<ShaderUniform>();

	public function new() {
	}

	public function setUniform(name:String, value:Dynamic):Void {
		var canonicalName = canonicalUniformName(name);
		var targetId = getUniformId(canonicalName);
		var uniform = uniforms.get(targetId);
		if (uniform == null) {
			uniforms.set(targetId, new ShaderUniform(targetId, canonicalName, value));
		} else {
			uniform.value = value;
		}
	}

	public static function getUniformId(name:String):Int {
		var uniformName:UniformName = name;
		return uniformName.id;
	}

	private static function canonicalUniformName(name:String):String {
		return StringTools.endsWith(name, "[0]") ? name.substr(0, name.length - 3) : name;
	}

	public inline function getUniforms():Iterator<{
		nameId:Int,
		name:String,
		value:Dynamic
	}> {
		return uniforms.iterator();
	}

}

private abstract UniformName(String) from String to String {
	private static var nextId:Int = 0;
	private static var stringToId:StringMap<Int> = new StringMap<Int>();

	public var id(get, never):Int;

	private inline function get_id():Int {
		var name:String = this;
		if (!stringToId.exists(name)) {
			var id = nextId++;
			stringToId.set(name, id);
		}
		return stringToId.get(name);
	}
}

private class ShaderUniform {
	public var nameId:Int;
	public var name:String;
	public var value:Dynamic;

	public function new(nameId:Int, name:String, value:Dynamic) {
		this.nameId = nameId;
		this.name = name;
		this.value = value;
	}
}
