package types;

enum abstract BlendFactors(Int) from Int to Int {
    var ZERO:Int = 0;
    var ONE:Int = 1;
    var SRC_COLOR:Int = 768;
    var ONE_MINUS_SRC_COLOR:Int = 769;
    var SRC_ALPHA:Int = 770;
    var ONE_MINUS_SRC_ALPHA:Int = 771;
    var DST_ALPHA:Int = 772;
    var ONE_MINUS_DST_ALPHA:Int = 773;
    var DST_COLOR:Int = 774;
    var ONE_MINUS_DST_COLOR:Int = 775;
    var SRC_ALPHA_SATURATE:Int = 776;
    var CONSTANT_COLOR:Int = 32769;
    var ONE_MINUS_CONSTANT_COLOR:Int = 32770;
    var CONSTANT_ALPHA:Int = 32771;
    var ONE_MINUS_CONSTANT_ALPHA:Int = 32772;
    var SRC1_ALPHA:Int = 34185;
    var SRC1_COLOR:Int = 35001;
    var ONE_MINUS_SRC1_COLOR:Int = 35002;
    var ONE_MINUS_SRC1_ALPHA:Int = 35003;
}