package data;

import types.AttributeFormat.AttributeFormat;

typedef AttributeInfo = {
	var name:String;
	var format:AttributeFormat;
	var size:Int;
	var stride:Int;
	var offset:Int;
	var location:Int;
}