package data;

@:autoBuild(ShaderGenMacro.buildId())
class Shader {

    public var shaderType:Class<Dynamic>;

    public function new() {
    }

    public function getSuperclass():Class<Dynamic> {
        var classInfo = Type.getClass(shaderType);
        return classInfo;
    }
}