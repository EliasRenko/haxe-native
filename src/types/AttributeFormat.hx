package types;

enum abstract AttributeFormat(Int) {
	var Float = 0;
	var Vec2 = 1;
	var Vec3 = 2;
	var Vec4 = 3;
	var Int = 4;
	var UnsignedInt = 5;
	var Byte = 6;
	var UnsignedByte = 7;
	var Short = 8;
	var UnsignedShort = 9;

	public static function fromGLType(glType:Int):AttributeFormat {
		return switch (glType) {
			case 5126: AttributeFormat.Float;
			case 35664: AttributeFormat.Vec2;
			case 35665: AttributeFormat.Vec3;
			case 35666: AttributeFormat.Vec4;
			case 5124: AttributeFormat.Int;
			case 5125: AttributeFormat.UnsignedInt;
			case 5120: AttributeFormat.Byte;
			case 5121: AttributeFormat.UnsignedByte;
			case 5122: AttributeFormat.Short;
			case 5123: AttributeFormat.UnsignedShort;
			default: AttributeFormat.Float;
		};
	}
}
