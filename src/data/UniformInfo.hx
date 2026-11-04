package data;

import types.UniformFormat.UniformFormat;

typedef UniformInfo = {
	var name:String;
	var format:UniformFormat;
	var setter:Dynamic;
	var ?location:Int;
	var ?textureUnit:Int;
}