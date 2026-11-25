package types;

enum abstract UniformFormat(Int) {
	var Float = 0;
	var Vec2 = 1;
	var Vec3 = 2;
	var Vec4 = 3;
	var Mat2 = 4;
	var Mat3 = 5;
	var Mat4 = 6;
	var Int = 7;
	var IntVec2 = 8;
	var IntVec3 = 9;
	var IntVec4 = 10;
	var Bool = 11;
	var BoolVec2 = 12;
	var BoolVec3 = 13;
	var BoolVec4 = 14;
	var Sampler2D = 15;
	var SamplerCube = 16;

	public static function fromGLType(glType:Int):UniformFormat {
		return switch (glType) {
			case 5126: UniformFormat.Float;
			case 35664: UniformFormat.Vec2;
			case 35665: UniformFormat.Vec3;
			case 35666: UniformFormat.Vec4;
			case 35674: UniformFormat.Mat2;
			case 35675: UniformFormat.Mat3;
			case 35676: UniformFormat.Mat4;
			case 5124: UniformFormat.Int;
			case 35667: UniformFormat.IntVec2;
			case 35668: UniformFormat.IntVec3;
			case 35669: UniformFormat.IntVec4;
			case 35670: UniformFormat.Bool;
			case 35671: UniformFormat.BoolVec2;
			case 35672: UniformFormat.BoolVec3;
			case 35673: UniformFormat.BoolVec4;
			case 35678: UniformFormat.Sampler2D;
			case 35680: UniformFormat.SamplerCube;
			default: UniformFormat.Float;
		};
	}
}