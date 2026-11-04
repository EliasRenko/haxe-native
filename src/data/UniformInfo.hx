package data;

import types.UniformFormat.UniformFormat;

typedef UniformLocation = Int;

typedef UniformInfo = {
	var name:String;
	var format:UniformFormat;
	var setter:Dynamic;
	var ?location:UniformLocation;
	var ?textureUnit:Int;
}