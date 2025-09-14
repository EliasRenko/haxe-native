package input;

@:enum abstract Control(Int) from Int to Int {
	
	var A = 0;
	
	var B = 1;
	
	var X = 2;
	
	var Y = 3;
	
	var BACK = 4;
	
	var GUIDE = 5;
	
	var START = 6;
	
	var LEFT_STICK = 7;
	
	var RIGHT_STICK = 8;
	
	var LEFT_SHOULDER = 9;
	
	var RIGHT_SHOULDER = 10;
	
	var DPAD_UP = 11;
	
	var DPAD_DOWN = 12;
	
	var DPAD_LEFT = 13;
	
	var DPAD_RIGHT = 14;
}