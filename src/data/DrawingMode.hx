package data;

enum abstract DrawingMode(Int) from Int to Int {
    var POINTS:Int = 0x0000;
    var LINES:Int = 0x0001;
    var LINE_LOOP:Int = 0x0002;
    var LINE_STRIP:Int = 0x0003;
    var TRIANGLES:Int = 0x0004;
    var TRIANGLE_STRIP:Int = 0x0005;
}