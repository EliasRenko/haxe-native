package;

import cpp.RawConstPointer;
import cpp.ConstCharStar;
import cpp.ConstPointer;
import cpp.Star;
import cpp.Struct;
import cpp.RawPointer;
import cpp.Pointer;
import cpp.Char;
import cpp.UInt8;
import cpp.UInt32;
import cpp.Float32;
import cpp.Int64;

import haxe.io.UInt8Array;
import haxe.io.BytesData;

@:native("gladGLversionStruct")
@:structAccess
extern class GLversionStruct {
	var major:Int;
	var minor:Int;
}

// ** Typedefs

typedef GlEnum = UInt32;
typedef GlUInt = UInt32;
typedef GlSizeI = Int;
typedef GlInt = Int;
typedef GlChar = Pointer<Char>;
typedef GlIntPointer = RawPointer<Int>;
typedef GlSizeIPointer = RawPointer<Int64>;

typedef GlFloat = Float32;

typedef GladLoadProc = (name:ConstCharStar) -> cpp.RawPointer<Void>;
//typedef VersionStruct = Struct<GLversionStruct>;

@:keep
@:include("glad/glad.h")
@:buildXml('
<files id="haxe">
  <compilerflag value="-Iinclude" />
  <file name="src/glad.c" />
</files>
')
extern class GL {

    @:native("GLVersion")
	static var version:GLversionStruct;

    static inline function gladLoadGLLoader(loadProc:(name:ConstCharStar) -> cpp.RawPointer<Void>):Int {
        return untyped __cpp__("gladLoadGLLoader((GLADloadproc){0})", loadProc);
    }

    @:native("glViewport")
    static function glViewport(x:Int, y:Int, width:Int, height:Int):Void;

    @:native("glClear")
    static function glClear(mask:Int):Void;

    @:native("glClearColor")
    static function glClearColor(red:Float, green:Float, blue:Float, alpha:Float):Void;

    @:native("glEnable")
    static function glEnable(cap:Int):Void;

    @:native("glDisable")
    static function glDisable(cap:Int):Void;

    @:native("glDepthFunc")
    static function glDepthFunc(func:Int):Void;

    @:native("glViewport")
    static function viewport(x:Int, y:Int, width:Int, height:Int):Void;

    @:native("glCreateProgram")
    static function createProgram():UInt;

    @:native("glUseProgram")
    static function useProgram(program:UInt):Void;

    @:native("glBindBuffer")
    static function bindBuffer(target:Int, buffer:UInt):Void;

    @:native("GL_ARRAY_BUFFER")
    static var ARRAY_BUFFER(default, null):Int;

    @:native("GL_ELEMENT_ARRAY_BUFFER")
    static var ELEMENT_ARRAY_BUFFER(default, null):Int;

    //@:native("glBufferData")
    //static function bufferData(target:Int, size:GlSizeI, data:RawConstPointer<Void>, usage:Int):Void;
    
    inline static function bufferData(target:Int, size:Int, data:BytesData, usage:Int):Void { 
        untyped __cpp__("glBufferData({0}, {1}, (const void*)&({2}[0]), {3})", target, size, data, usage);
    }

    // @:native("glBufferSubData")
    // static function bufferSubData(target:Int, offset:Int, size:Int, data:cpp.RawPointer<cpp.Void>):Void;
    // inline static function bufferSubData(target:GlEnum, offset:Int, size:Int, data:BytesData):Void {
	// 	untyped __cpp__("glBufferSubData({0}, {1}, {2}, {3})", target, offset, size, data);
	// }

	static inline function bufferFloatArray(target:GlEnum, array:Array<cpp.Float32>, usage:GlEnum, arrayLength:Int):Void {
		return untyped __cpp__("float* _cArray = ((float*)(cpp::Pointer_obj::ofArray({0}).value));
			glBufferData({1}, sizeof(float) * {3}, _cArray, {2})", array, target, usage, arrayLength);
	}

    static inline function bufferUIntArray(target:GlEnum, array:Array<cpp.UInt32>, usage:GlEnum, arrayLength:Int):Void {
		return untyped __cpp__(
			"unsigned int* _cArray = ((unsigned int*)(cpp::Pointer_obj::ofArray({0}).value));
			glBufferData({1}, sizeof(unsigned int) * {3}, _cArray, {2})",
		array, target, usage, arrayLength);
	}

    static inline function bufferSubFloatArray(target:GlEnum, offset:GlInt, array:Array<Float>, arrayLength:Int):Void {
		return untyped __cpp__(
			"float* _cArray = ((float*)(cpp::Pointer_obj::ofArray({0}).value));
			glBufferSubData({1}, {2}, sizeof(float) * {3}, _cArray)",
		array, target, offset, arrayLength);
	}

    static inline function bufferSubIntArray(target:GlEnum, offset:GlInt, array:Array<UInt>, arrayLength:Int):Void {
		return untyped __cpp__(
			"unsigned int* _cArray = ((unsigned int*)(cpp::Pointer_obj::ofArray({0}).value));
			glBufferSubData({1}, {2}, sizeof(unsigned int) * {3}, _cArray)",
		array, target, offset, arrayLength);
	}

    @:native("GL_STATIC_DRAW")
    static var STATIC_DRAW(default, null):Int;
    @:native("GL_DYNAMIC_DRAW")
    static var DYNAMIC_DRAW(default, null):Int;

    @:native("GL_BUFFER_SIZE")
    static var BUFFER_SIZE(default, null):GlEnum;

    @:native("glGetBufferParameteriv")
    static function getBufferParameteriv(target:Int, pname:GlEnum, params:RawPointer<GlInt>):Void;

    @:native("glEnableVertexAttribArray")
    static function enableVertexAttribArray(index:GlUInt):Void;

    @:native("glVertexAttribPointer")
    static function vertexAttribPointer(index:GlUInt, size:Int, type:Int, normalized:Bool, stride:GlSizeI, pointer:RawConstPointer<Void>):Void;

    @:native("glGenBuffers")
    static function genBuffers(n:GlSizeI, buffers:RawPointer<GlUInt>):Void;
    @:native("glBindBufferBase")
    static function bindBufferBase(target:Int, index:GlUInt, buffer:GlUInt):Void;
    @:native("glDeleteBuffers")
    static function deleteBuffers(n:GlSizeI, buffers:RawPointer<GlUInt>):Void;

    @:native("glDrawArrays")
    static function drawArrays(mode:Int, first:GlInt, count:GlSizeI):Void;
    // @:native("glDrawElements")
    // static function drawElements(mode:Int, count:GlSizeI, type:Int, indices:RawConstPointer<Void>):Void;
    inline static function drawElements(mode:GlEnum, count:GlSizeI, type:GlEnum, indices:Any):Void {
		untyped __cpp__("glDrawElements({0}, {1}, {2}, 0)", mode, count, type);
	}

    @:native("GL_POINTS")
    static var POINTS(default, null):Int;
    @:native("GL_LINES")
    static var LINES(default, null):Int;
    @:native("GL_LINE_LOOP")
    static var LINE_LOOP(default, null):Int;
    @:native("GL_LINE_STRIP")
    static var LINE_STRIP(default, null):Int;
    @:native("GL_TRIANGLES")
    static var TRIANGLES(default, null):Int;
    @:native("GL_TRIANGLE_STRIP")
    static var TRIANGLE_STRIP(default, null):Int;

    @:native("GL_TEXTURE0")
    static var TEXTURE0(default, null):Int;
    @:native("GL_TEXTURE1")
    static var TEXTURE1(default, null):Int;
    @:native("GL_TEXTURE2")
    static var TEXTURE2(default, null):Int;
    @:native("GL_TEXTURE3")
    static var TEXTURE3(default, null):Int;
    @:native("GL_TEXTURE4")
    static var TEXTURE4(default, null):Int;
    @:native("GL_TEXTURE5")
    static var TEXTURE5(default, null):Int;
    @:native("GL_TEXTURE6")
    static var TEXTURE6(default, null):Int;
    @:native("GL_TEXTURE7")
    static var TEXTURE7(default, null):Int;
    @:native("GL_TEXTURE8")
    static var TEXTURE8(default, null):Int;
    @:native("GL_TEXTURE9")
    static var TEXTURE9(default, null):Int;
    @:native("GL_TEXTURE10")
    static var TEXTURE10(default, null):Int;
    @:native("GL_TEXTURE11")
    static var TEXTURE11(default, null):Int;
    @:native("GL_TEXTURE12")
    static var TEXTURE12(default, null):Int;
    @:native("GL_TEXTURE13")
    static var TEXTURE13(default, null):Int;
    @:native("GL_TEXTURE14")
    static var TEXTURE14(default, null):Int;
    @:native("GL_TEXTURE15")
    static var TEXTURE15(default, null):Int;
    @:native("GL_TEXTURE16")
    static var TEXTURE16(default, null):Int;
    @:native("GL_TEXTURE17")
    static var TEXTURE17(default, null):Int;
    @:native("GL_TEXTURE18")
    static var TEXTURE18(default, null):Int;
    @:native("GL_TEXTURE19")
    static var TEXTURE19(default, null):Int;
    @:native("GL_TEXTURE20")
    static var TEXTURE20(default, null):Int;
    @:native("GL_TEXTURE21")
    static var TEXTURE21(default, null):Int;
    @:native("GL_TEXTURE22")
    static var TEXTURE22(default, null):Int;
    @:native("GL_TEXTURE23")
    static var TEXTURE23(default, null):Int;
    @:native("GL_TEXTURE24")
    static var TEXTURE24(default, null):Int;
    @:native("GL_TEXTURE25")
    static var TEXTURE25(default, null):Int;
    @:native("GL_TEXTURE26")
    static var TEXTURE26(default, null):Int;
    @:native("GL_TEXTURE27")
    static var TEXTURE27(default, null):Int;
    @:native("GL_TEXTURE28")
    static var TEXTURE28(default, null):Int;
    @:native("GL_TEXTURE29")
    static var TEXTURE29(default, null):Int;
    @:native("GL_TEXTURE30")
    static var TEXTURE30(default, null):Int;
    @:native("GL_TEXTURE31")
    static var TEXTURE31(default, null):Int;

    //@:native("GL_COLOR_BUFFER_BIT")
    static inline var COLOR_BUFFER_BIT:Int = 0x00004000;

    //@:native("DEPTH_BUFFER_BIT")
    static inline var DEPTH_BUFFER_BIT:Int = 0x00000100;

    @:native("GL_DEPTH_TEST")
    static var DEPTH_TEST(default, null):Int;

    @:native("GL_CULL_FACE")
    static var CULL_FACE(default, null):Int;
    
    // Depth function constants
    @:native("GL_LESS")
    static var LESS(default, null):Int;
    
    @:native("GL_LEQUAL")  
    static var LEQUAL(default, null):Int;

    @:native("GL_VERTEX_SHADER")
    static var VERTEX_SHADER(default, null):Int;

    @:native("GL_FRAGMENT_SHADER")
    static var FRAGMENT_SHADER(default, null):Int;

    @:native("GL_COMPILE_STATUS")
    static var COMPILE_STATUS(default, null):Int;

    @:native("GL_LINK_STATUS")
    static var LINK_STATUS(default, null):Int;

    @:native("GL_INFO_LOG_LENGTH")
    static var INFO_LOG_LENGTH(default, null):Int;

    @:native("GL_VALIDATE_STATUS")
    static var VALIDATE_STATUS(default, null):GlEnum;

    @:native("GL_ACTIVE_ATTRIBUTES")
    static var ACTIVE_ATTRIBUTES(default, null):GlEnum;

    @:native("GL_ACTIVE_UNIFORMS")
    static var ACTIVE_UNIFORMS(default, null):GlEnum;

    @:native("GL_RGBA")
    static var RGBA(default, null):Int;

    @:native("GL_RED")
    static var RED(default, null):Int;

    @:native("GL_RG")
    static var RG(default, null):Int;

    @:native("GL_RGB")
    static var RGB(default, null):Int;

    // ---

    @:native("glCreateShader")
    static function createShader(shaderType:Int):UInt;

    @:native("glShaderSource")
	static function shaderSource(shader:GlUInt, count:GlSizeI, string:RawPointer<ConstCharStar>, length:RawPointer<GlInt>):Void;

    @:native("glCompileShader")
    static function compileShader(shader:UInt):Void;

    @:native("glGetShaderiv")
    static function getShaderiv(shader:GlUInt, pname:GlEnum, params:RawPointer<GlInt>):Void;

    @:native("glGetShaderInfoLog")
    static function getShaderInfoLog(shader:GlUInt, bufSize:GlSizeI, length:RawPointer<GlSizeI>, infoLog:GlChar):Void;

    //@:native("glGetShaderiv")
    // static inline function getShaderiv(shader:Int, pname:Int, param:Array<Int>):Void {
    //     untyped __cpp__("glGetShaderiv({0}, {1}, (GLint*)&({2}[0]))", shader, pname, param);
    // }

    @:native("glAttachShader")
    static function attachShader(program:UInt, shader:UInt):Void;

    @:native("glLinkProgram")
    static function linkProgram(program:UInt):Void;

    @:native("glValidateProgram")
    static function validateProgram(program:UInt):Void;

    @:native("glGetProgramiv")
    static function getProgramiv(program:GlUInt, pname:GlEnum, params:RawPointer<GlInt>):Void;

    @:native("glGetProgramInfoLog")
    static function getProgramInfoLog(program:GlUInt, bufSize:GlSizeI, length:RawPointer<GlSizeI>, infoLog:GlChar):Void;

    @:native("glDeleteShader")
	static function deleteShader(shader:GlUInt):Void;

    @:native("glGetActiveAttrib")
    static function getActiveAttrib(program:GlUInt, index:GlUInt, bufSize:GlSizeI, length:RawPointer<GlSizeI>, size:RawPointer<GlInt>, type:RawPointer<GlEnum>, name:GlChar):Void;

    @:native("glGetActiveUniform")
    static function getActiveUniform(program:GlUInt, index:GlUInt, bufSize:GlSizeI, length:RawPointer<GlSizeI>, size:RawPointer<GlInt>, type:RawPointer<GlEnum>, name:GlChar):Void;
    @:native("glGetAttribLocation")
	static function getAttribLocation(program:GlUInt, name:ConstCharStar):GlInt;
    @:native("glGetUniformLocation")
    static function getUniformLocation(program:GlUInt, name:ConstCharStar):GlInt;
    @:native("glGetError")
    static function getError():Int;

    // ** Shader compilation helper functions
    static inline function getShaderParameterValue(shader:Int, pname:Int):Int {
        var result:Int = 0;
        untyped __cpp__("glGetShaderiv({0}, {1}, &{2})", shader, pname, result);
        return result;
    }

    static inline function getProgramParameterValue(program:Int, pname:Int):Int {
        var result:Int = 0;
        untyped __cpp__("glGetProgramiv({0}, {1}, &{2})", program, pname, result);
        return result;
    }

    static inline function getShaderInfoLogString(shader:Int):String {
        var logLength:Int = getShaderParameterValue(shader, INFO_LOG_LENGTH);
        if (logLength <= 0) return "";
        
        var errorLog:String = "";
        untyped __cpp__("
            char* log = new char[{1}];
            glGetShaderInfoLog({0}, {1}, NULL, log);
            {2} = String(log);
            delete[] log;
        ", shader, logLength, errorLog);
        return errorLog;
    }

    static inline function getProgramInfoLogString(program:Int):String {
        var logLength:Int = getProgramParameterValue(program, INFO_LOG_LENGTH);
        if (logLength <= 0) return "";
        
        var errorLog:String = "";
        untyped __cpp__("
            char* log = new char[{1}];
            glGetProgramInfoLog({0}, {1}, NULL, log);
            {2} = String(log);
            delete[] log;
        ", program, logLength, errorLog);
        return errorLog;
    }

    // ** glUniform
    @:native("glUniform1f")
    static function uniform1f(location:GlInt, v0:Float):Void;
    @:native("glUniform1fv")
    static function uniform1fv(location:GlInt, count:GlSizeI, value:RawPointer<GlFloat>):Void;
    @:native("glUniform2fv")
    static function uniform2fv(location:GlInt, count:GlSizeI, value:RawPointer<GlFloat>):Void;
    @:native("glUniform3fv")
    static function uniform3fv(location:GlInt, count:GlSizeI, value:RawPointer<GlFloat>):Void;
    @:native("glUniform4fv")
    static function uniform4fv(location:GlInt, count:GlSizeI, value:RawPointer<GlFloat>):Void;
    @:native("glUniform1i")
    static function uniform1i(location:GlInt, v0:Int):Void;
    @:native("glUniform1iv")
    static function uniform1iv(location:GlInt, count:GlSizeI, value:RawPointer<GlInt>):Void;
    @:native("glUniform2iv")
    static function uniform2iv(location:GlInt, count:GlSizeI, value:RawPointer<GlInt>):Void;
    @:native("glUniform3iv")
    static function uniform3iv(location:GlInt, count:GlSizeI, value:RawPointer<GlInt>):Void;
    @:native("glUniform4iv")
    static function uniform4iv(location:GlInt, count:GlSizeI, value:RawPointer<GlInt>):Void;
    @:native("glUniform1ui")
    static function uniform1ui(location:GlInt, v0:Int):Void;
    @:native("glUniform1uiv")
    static function uniform1uiv(location:GlInt, count:GlSizeI, value:RawPointer<GlUInt>):Void;
    @:native("glUniform2uiv")
    static function uniform2uiv(location:GlInt, count:GlSizeI, value:RawPointer<GlUInt>):Void;
    @:native("glUniform3uiv")
    static function uniform3uiv(location:GlInt, count:GlSizeI, value:RawPointer<GlUInt>):Void;
    @:native("glUniform4uiv")
    static function uniform4uiv(location:GlInt, count:GlSizeI, value:RawPointer<GlUInt>):Void;
    @:native("glUniformMatrix2fv")
    static function uniformMatrix2fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix3fv")
    static function uniformMatrix3fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix4fv")
    static function uniformMatrix4fv(location:GlInt, count:GlSizeI, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix2x3fv")
    static function uniformMatrix2x3fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix3x2fv")
    static function uniformMatrix3x2fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix2x4fv")
    static function uniformMatrix2x4fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix4x2fv")
    static function uniformMatrix4x2fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix3x4fv")
    static function uniformMatrix3x4fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;
    @:native("glUniformMatrix4x3fv")
    static function uniformMatrix4x3fv(location:GlInt, transpose:Bool, value:RawPointer<GlFloat>):Void;

    @:native("glGenTextures")
	static function genTextures(n:GlSizeI, textures:RawPointer<GlUInt>):Void;
    @:native("glBindTexture")
    static function bindTexture(target:Int, texture:GlUInt):Void;                                        
    
    // ** TODO: UNTYPED
    inline static function texImage1D(target:GlEnum, level:GlInt, internalFormat:GlInt, width:GlSizeI, border:GlInt, format:GlEnum, type:GlEnum, pixels:Any):Void {
		untyped __cpp__("glTexImage1D({0}, {1}, {2}, {3}, {4}, {5}, {6}, {7})", target, level, internalFormat, width, border, format, type, pixels);
	}

    // ** TODO: UNTYPED
	inline static function texImage2D(target:GlEnum, level:GlInt, internalFormat:GlInt, width:GlSizeI, height:GlSizeI, border:GlInt, format:GlEnum, type:GlEnum, pixels:cpp.Star<cpp.UInt8>):Void {
		untyped __cpp__("glTexImage2D({0}, {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8})", target, level, internalFormat, width, height, border, format, type, pixels);
	}

    static inline function deleteTextures(n:GlSizeI, textures:RawPointer<GlUInt>):Void {
        // Use untyped __cpp__ to call glDeleteTextures with proper casting
        untyped __cpp__("glDeleteTextures({0}, (const GLuint*)({1}))", n, textures);
    }

    @:native("glActiveTexture")
    static function activeTexture(texture:Int):Void;

    @:native("glBlendFunc")
    static function blendFunc(sfactor:Int, dfactor:Int):Void;

    // @:native("glGetString")
    // static function getString(name:Int):ConstCharStar;

    // @:native("glGetIntegerv")
    // static function getIntegerv(pname:Int, params:RawPointer<Int>):Void;

    @:native("glGenVertexArrays")
    static function genVertexArrays(n:Int, arrays:RawPointer<GlUInt>):Void;

    @:native("glBindVertexArray")
    static function bindVertexArray(array:GlUInt):Void;

    @:native("glDeleteVertexArrays")
    static function deleteVertexArrays(n:Int, arrays:RawPointer<GlUInt>):Void;

    @:native("glGenerateMipmap")
    static function generateMipmap(target:Int):Void;
    @:native("glTexParameteri")
    static function texParameteri(target:Int, pname:Int, param:Int):Void;
    @:native("glTexParameterf")
    static function texParameterf(target:Int, pname:Int, param:Float):Void;
    @:native("glTexParameteriv")
    static function texParameteriv(target:Int, pname:Int, params:RawPointer<Int>):Void;
    @:native("glTexParameterfv")
    static function texParameterfv(target:Int, pname:Int, params:RawPointer<Float>):Void;

    // ** Texture targets
    @:native("GL_TEXTURE_1D")
    static var TEXTURE_1D(default, null):Int;
    @:native("GL_TEXTURE_2D")
    static var TEXTURE_2D(default, null):Int;
    @:native("GL_TEXTURE_3D")
    static var TEXTURE_3D(default, null):Int;
    @:native("GL_TEXTURE_1D_ARRAY")
    static var TEXTURE_1D_ARRAY(default, null):Int;
    @:native("GL_TEXTURE_2D_ARRAY")
    static var TEXTURE_2D_ARRAY(default, null):Int;
    @:native("GL_TEXTURE_RECTANGLE")
    static var TEXTURE_RECTANGLE(default, null):Int;
    @:native("GL_TEXTURE_CUBE_MAP")
    static var TEXTURE_CUBE_MAP(default, null):Int;

    // ** Texture params
    @:native("GL_TEXTURE_BASE_LEVEL")
    static var TEXTURE_BASE_LEVEL(default, null):Int;
    @:native("GL_TEXTURE_BORDER_COLOR")
    static var TEXTURE_BORDER_COLOR(default, null):Int;
    @:native("GL_TEXTURE_COMPARE_FUNC")
    static var TEXTURE_COMPARE_FUNC(default, null):Int;
    @:native("GL_TEXTURE_COMPARE_MODE")
    static var TEXTURE_COMPARE_MODE(default, null):Int;
    @:native("GL_TEXTURE_LOD_BIAS")
    static var TEXTURE_LOD_BIAS(default, null):Int;
    @:native("GL_TEXTURE_MIN_FILTER")
    static var TEXTURE_MIN_FILTER(default, null):Int;
    @:native("GL_TEXTURE_MAG_FILTER")
    static var TEXTURE_MAG_FILTER(default, null):Int;
    @:native("GL_TEXTURE_MIN_LOD")
    static var TEXTURE_MIN_LOD(default, null):Int;
    @:native("GL_TEXTURE_MAX_LOD")
    static var TEXTURE_MAX_LOD(default, null):Int;
    @:native("GL_TEXTURE_MAX_LEVEL")
    static var TEXTURE_MAX_LEVEL(default, null):Int;
    @:native("GL_TEXTURE_SWIZZLE_R")
    static var TEXTURE_SWIZZLE_R(default, null):Int;
    @:native("GL_TEXTURE_SWIZZLE_G")
    static var TEXTURE_SWIZZLE_G(default, null):Int;
    @:native("GL_TEXTURE_SWIZZLE_B")
    static var TEXTURE_SWIZZLE_B(default, null):Int;
    @:native("GL_TEXTURE_SWIZZLE_A")
    static var TEXTURE_SWIZZLE_A(default, null):Int;
    @:native("GL_TEXTURE_SWIZZLE_RGBA")
    static var TEXTURE_SWIZZLE_RGBA(default, null):Int;
    @:native("GL_TEXTURE_WRAP_S")
    static var TEXTURE_WRAP_S(default, null):Int;
    @:native("GL_TEXTURE_WRAP_T")
    static var TEXTURE_WRAP_T(default, null):Int;
    @:native("GL_TEXTURE_WRAP_R")
    static var TEXTURE_WRAP_R(default, null):Int;

    @:native("GL_NEAREST")
    static var NEAREST(default, null):Int;
    @:native("GL_LINEAR")
    static var LINEAR(default, null):Int;
    @:native("GL_NEAREST_MIPMAP_NEAREST")
    static var NEAREST_MIPMAP_NEAREST(default, null):Int;
    @:native("GL_LINEAR_MIPMAP_NEAREST")
    static var LINEAR_MIPMAP_NEAREST(default, null):Int;
    @:native("GL_NEAREST_MIPMAP_LINEAR")
    static var NEAREST_MIPMAP_LINEAR(default, null):Int;
    @:native("GL_LINEAR_MIPMAP_LINEAR")
    static var LINEAR_MIPMAP_LINEAR(default, null):Int;

    @:native("GL_CLAMP_TO_EDGE")
    static var CLAMP_TO_EDGE(default, null):Int;
    @:native("GL_CLAMP_TO_BORDER")
    static var CLAMP_TO_BORDER(default, null):Int;
    @:native("GL_MIRRORED_REPEAT")
    static var MIRRORED_REPEAT(default, null):Int;
    @:native("GL_REPEAT")
    static var REPEAT(default, null):Int;
    @:native("GL_MIRROR_CLAMP_TO_EDGE")
    static var MIRROR_CLAMP_TO_EDGE(default, null):Int;

    // ** Pixel types
    @:native("GL_UNSIGNED_BYTE")
    static var UNSIGNED_BYTE(default, null):Int;
    @:native("GL_BYTE")
    static var BYTE(default, null):Int;
    @:native("GL_UNSIGNED_SHORT")
    static var UNSIGNED_SHORT(default, null):Int;
    @:native("GL_SHORT")
    static var SHORT(default, null):Int;
    @:native("GL_UNSIGNED_INT")
    static var UNSIGNED_INT(default, null):Int;
    @:native("GL_INT")
    static var INT(default, null):Int;
    @:native("GL_FLOAT")
    static var FLOAT(default, null):Int;
    @:native("GL_UNSIGNED_BYTE_3_3_2")
    static var UNSIGNED_BYTE_3_3_2(default, null):Int;
    @:native("GL_UNSIGNED_BYTE_2_3_3_REV")
    static var UNSIGNED_BYTE_2_3_3_REV(default, null):Int;
    @:native("GL_UNSIGNED_SHORT_5_6_5")
    static var UNSIGNED_SHORT_5_6_5(default, null):Int;
    @:native("GL_UNSIGNED_SHORT_5_6_5_REV")
    static var UNSIGNED_SHORT_5_6_5_REV(default, null):Int;
    @:native("GL_UNSIGNED_SHORT_4_4_4_4")
    static var UNSIGNED_SHORT_4_4_4_4(default, null):Int;
    @:native("GL_UNSIGNED_SHORT_4_4_4_4_REV")
    static var UNSIGNED_SHORT_4_4_4_4_REV(default, null):Int;
    @:native("GL_UNSIGNED_SHORT_5_5_5_1")
    static var UNSIGNED_SHORT_5_5_5_1(default, null):Int;
    @:native("GL_UNSIGNED_SHORT_1_5_5_5_REV")
    static var UNSIGNED_SHORT_1_5_5_5_REV(default, null):Int;
    @:native("GL_UNSIGNED_INT_8_8_8_8")
    static var UNSIGNED_INT_8_8_8_8(default, null):Int;
    @:native("GL_UNSIGNED_INT_8_8_8_8_REV")
    static var UNSIGNED_INT_8_8_8_8_REV(default, null):Int;
    @:native("GL_UNSIGNED_INT_10_10_10_2")
    static var UNSIGNED_INT_10_10_10_2(default, null):Int;
    @:native("GL_UNSIGNED_INT_2_10_10_10_REV")
    static var UNSIGNED_INT_2_10_10_10_REV(default, null):Int;

    // Additional constants for dynamic rendering
    @:native("GL_FLOAT_VEC2")
    static var FLOAT_VEC2(default, null):Int;
    @:native("GL_FLOAT_VEC3")
    static var FLOAT_VEC3(default, null):Int;
    @:native("GL_FLOAT_VEC4")
    static var FLOAT_VEC4(default, null):Int;
    @:native("GL_FLOAT_MAT4")
    static var FLOAT_MAT4(default, null):Int;
    @:native("GL_FLOAT_MAT2")
    static var FLOAT_MAT2(default, null):Int;
    @:native("GL_FLOAT_MAT3")
    static var FLOAT_MAT3(default, null):Int;
    @:native("GL_FLOAT_MAT2x3")
    static var FLOAT_MAT2x3(default, null):Int;
    @:native("GL_FLOAT_MAT2x4")
    static var FLOAT_MAT2x4(default, null):Int;
    @:native("GL_FLOAT_MAT3x2")
    static var FLOAT_MAT3x2(default, null):Int;
    @:native("GL_FLOAT_MAT3x4")
    static var FLOAT_MAT3x4(default, null):Int;
    @:native("GL_FLOAT_MAT4x2")
    static var FLOAT_MAT4x2(default, null):Int;
    @:native("GL_FLOAT_MAT4x3")
    static var FLOAT_MAT4x3(default, null):Int;
    @:native("GL_INT_VEC2")
    static var INT_VEC2(default, null):Int;
    @:native("GL_INT_VEC3")
    static var INT_VEC3(default, null):Int;
    @:native("GL_INT_VEC4")
    static var INT_VEC4(default, null):Int;
    @:native("GL_UNSIGNED_INT_VEC2")
    static var UNSIGNED_INT_VEC2(default, null):Int;
    @:native("GL_UNSIGNED_INT_VEC3")
    static var UNSIGNED_INT_VEC3(default, null):Int;
    @:native("GL_UNSIGNED_INT_VEC4")
    static var UNSIGNED_INT_VEC4(default, null):Int;
    @:native("GL_BOOL")
    static var BOOL(default, null):Int;
    @:native("GL_BOOL_VEC2")
    static var BOOL_VEC2(default, null):Int;
    @:native("GL_BOOL_VEC3")
    static var BOOL_VEC3(default, null):Int;
    @:native("GL_BOOL_VEC4")
    static var BOOL_VEC4(default, null):Int;
    @:native("GL_SAMPLER_2D")
    static var SAMPLER_2D(default, null):Int;
    @:native("GL_SAMPLER_CUBE")
    static var SAMPLER_CUBE(default, null):Int;
    @:native("GL_SAMPLER_2D_ARRAY")
    static var SAMPLER_2D_ARRAY(default, null):Int;
    @:native("GL_SAMPLER_2D_SHADOW")
    static var SAMPLER_2D_SHADOW(default, null):Int;
    @:native("GL_SAMPLER_CUBE_SHADOW")
    static var SAMPLER_CUBE_SHADOW(default, null):Int;
    
    // Blend function constants
    @:native("GL_SRC_ALPHA")
    static var SRC_ALPHA(default, null):Int;
    @:native("GL_ONE_MINUS_SRC_ALPHA")
    static var ONE_MINUS_SRC_ALPHA(default, null):Int;

    // Framebuffer constants
    @:native("GL_FRAMEBUFFER")
    static var FRAMEBUFFER(default, null):Int;
    @:native("GL_COLOR_ATTACHMENT0")
    static var COLOR_ATTACHMENT0(default, null):Int;
    @:native("GL_FRAMEBUFFER_COMPLETE")
    static var FRAMEBUFFER_COMPLETE(default, null):Int;
    
    // Framebuffer functions
    @:native("glGenFramebuffers")
    static function genFramebuffers(n:Int, framebuffers:RawPointer<UInt>):Void;
    
    @:native("glBindFramebuffer")
    static function bindFramebuffer(target:Int, framebuffer:UInt):Void;
    
    @:native("glFramebufferTexture2D")
    static function framebufferTexture2D(target:Int, attachment:Int, textarget:Int, texture:UInt, level:Int):Void;
    
    @:native("glCheckFramebufferStatus")
    static function checkFramebufferStatus(target:Int):Int;
    
    @:native("glDeleteFramebuffers")
    static function deleteFramebuffers(n:Int, framebuffers:RawPointer<UInt>):Void;
    
    // Helper functions for single framebuffer creation/deletion
    static inline function createFramebuffer():UInt {
        var fb:UInt = 0;
        untyped __cpp__("glGenFramebuffers(1, (GLuint*)&{0})", fb);
        return fb;
    }
    
    static inline function deleteFramebuffer(framebuffer:UInt):Void {
        untyped __cpp__("glDeleteFramebuffers(1, (GLuint*)&{0})", framebuffer);
    }
    
    // Helper functions for single object creation (using existing extern declarations)
    static inline function createTexture():UInt {
        var tex:UInt = 0;
        untyped __cpp__("glGenTextures(1, (GLuint*)&{0})", tex);
        return tex;
    }
    
    static inline function deleteTexture(texture:UInt):Void {
        untyped __cpp__("glDeleteTextures(1, (GLuint*)&{0})", texture);
    }
    
    static inline function createBuffer():UInt {
        var buf:UInt = 0;
        untyped __cpp__("glGenBuffers(1, (GLuint*)&{0})", buf);
        return buf;
    }
    
    static inline function deleteBuffer(buffer:UInt):Void {
        untyped __cpp__("glDeleteBuffers(1, (GLuint*)&{0})", buffer);
    }
    
    static inline function createVertexArray():UInt {
        var vao:UInt = 0;
        untyped __cpp__("glGenVertexArrays(1, (GLuint*)&{0})", vao);
        return vao;
    }
    
    static inline function deleteVertexArray(vao:UInt):Void {
        untyped __cpp__("glDeleteVertexArrays(1, (GLuint*)&{0})", vao);
    }

    
}