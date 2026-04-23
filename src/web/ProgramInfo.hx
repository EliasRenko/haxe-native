package web;

#if js
import web.GL;
import ShaderBuilder;

// -------------------------------------------------------------------------
// Type aliases — keep the same names as the native ProgramInfo so shared
// code can reference them without conditional compilation.
// -------------------------------------------------------------------------
typedef UniformLocation = Int; // maps into GL.__uniformLocations
typedef Program         = Int; // maps into GL.__programs
typedef Shader          = Int; // maps into GL.__shaders
typedef GlUInt          = Int; // generic handle (buffer, VAO, texture …)

// -------------------------------------------------------------------------
// Shared enums / typedefs (identical to native ProgramInfo)
// -------------------------------------------------------------------------

enum AttributeFormat {
    Float;
    Vec2;
    Vec3;
    Vec4;
    Int;
    UnsignedInt;
    Byte;
    UnsignedByte;
    Short;
    UnsignedShort;
}

class AttributeFormatHelper {
    public static function getValuesPerVertex(format:AttributeFormat):Int {
        return switch (format) {
            case Float: 1;
            case Vec2:  2;
            case Vec3:  3;
            case Vec4:  4;
            case _:     1;
        };
    }

    public static function getBytesPerVertex(format:AttributeFormat):Int {
        return switch (format) {
            case Float | Int | UnsignedInt: 4;
            case Vec2:  8;
            case Vec3: 12;
            case Vec4: 16;
            case Short | UnsignedShort: 2;
            case Byte  | UnsignedByte:  1;
        };
    }
}

enum UniformFormat {
    Float;
    Vec2;
    Vec3;
    Vec4;
    Mat2;
    Mat3;
    Mat4;
    Int;
    IntVec2;
    IntVec3;
    IntVec4;
    Bool;
    BoolVec2;
    BoolVec3;
    BoolVec4;
    Sampler2D;
    SamplerCube;
}

typedef Attribute = {
    var name:String;
    var format:AttributeFormat;
    var size:Int;
    var stride:Int;
    var offset:Int;
    var location:Int;
}

typedef Uniform = {
    var name:String;
    var format:UniformFormat;
    var setter:Dynamic;
    var ?location:UniformLocation;
}

// -------------------------------------------------------------------------
// ProgramInfo
// -------------------------------------------------------------------------

class ProgramInfo {

    // ** Shader source code
    public var vertexShaderSource:String;
    public var fragmentShaderSource:String;

    // ** Compiled shader handles
    public var vertexShader:Shader   = 0;
    public var fragmentShader:Shader = 0;
    public var program:Program       = 0;
    public var programId:Int         = -1;

    // ** Vertex attributes and uniforms
    public var attributes:Array<Attribute> = [];
    public var uniforms:Array<Uniform>     = [];
    public var textures:Array<Uniform>     = [];

    // ** Performance: O(1) uniform lookup
    private var uniformMap:Map<String, Uniform> = new Map();

    // ** Rendering properties
    public var name(get, null):String;
    public var vertexStride:Int = 0;
    public var textureCount(get, null):Int;
    public var isCompiled:Bool = false;

    // ** VAO — created for compatibility; web uses per-(program,vbo) VAO cache in Renderer
    public var vao:GlUInt = 0;
    public var useModernBinding:Bool = false; // always false on web

    private var __name:String;

    public function new(name:String, ?vertexSource:String, ?fragmentSource:String) {
        __name = name;

        // Capture defaults BEFORE patchForTarget() strips them (GLSL ES has no default uniforms)
        var defaults:Map<String, Dynamic> = new Map();
        if (fragmentSource != null)
            for (k => v in ShaderBuilder.extractUniformDefaults(fragmentSource)) defaults.set(k, v);
        if (vertexSource != null)
            for (k => v in ShaderBuilder.extractUniformDefaults(vertexSource)) defaults.set(k, v);

        fragmentShaderSource = ShaderBuilder.patchForTarget(fragmentSource);
        vertexShaderSource   = (vertexSource != null)
                                ? ShaderBuilder.patchForTarget(vertexSource)
                                : ShaderBuilder.defaultVertexFor(fragmentShaderSource);
        programId = -1;

        if (!compileProgramInfo(this)) {
            trace("Failed to compile shader program: " + name);
            return;
        }

        introspectProgram();

        // Apply parsed defaults so WebGL uniforms start at the same value as native GLSL defaults
        if (defaults.keys().hasNext()) {
            GL.useProgram(program);
            for (uname => value in defaults) {
                var u = uniformMap.get(uname);
                if (u != null) u.setter(value);
            }
            GL.useProgram(0);
        }

        // Create a placeholder VAO (actual per-draw setup is done in Renderer)
        vao = GL.createVertexArray();
    }

    // -------------------------------------------------------------------------
    // Shader compilation
    // -------------------------------------------------------------------------

    public function compileProgramInfo(programInfo:ProgramInfo):Bool {
        if (programInfo.isCompiled) return true;

        // Vertex shader
        programInfo.vertexShader = GL.createShader(GL.VERTEX_SHADER);
        GL.shaderSource(programInfo.vertexShader, programInfo.vertexShaderSource);
        GL.compileShader(programInfo.vertexShader);
        if (!checkShaderCompilation(programInfo.vertexShader, "Vertex")) {
            return false;
        }

        // Fragment shader
        programInfo.fragmentShader = GL.createShader(GL.FRAGMENT_SHADER);
        GL.shaderSource(programInfo.fragmentShader, programInfo.fragmentShaderSource);
        GL.compileShader(programInfo.fragmentShader);
        if (!checkShaderCompilation(programInfo.fragmentShader, "Fragment")) {
            return false;
        }

        // Link program
        programInfo.program = GL.createProgram();
        GL.attachShader(programInfo.program, programInfo.vertexShader);
        GL.attachShader(programInfo.program, programInfo.fragmentShader);
        GL.linkProgram(programInfo.program);

        if (!checkProgramLinking(programInfo.program)) {
            return false;
        }

        programInfo.isCompiled = true;
        return true;
    }

    private function checkShaderCompilation(shader:Int, type:String):Bool {
        var success = GL.getShaderParameterValue(shader, GL.COMPILE_STATUS);
        if (success == 0) {
            var log = GL.getShaderInfoLogString(shader);
            trace(type + " shader compilation failed:\n" + log);
            return false;
        }
        trace(type + " shader compiled successfully");
        return true;
    }

    private function checkProgramLinking(program:Int):Bool {
        var success = GL.getProgramParameterValue(program, GL.LINK_STATUS);
        if (success == 0) {
            var log = GL.getProgramInfoLogString(program);
            trace("Program linking failed:\n" + log);
            return false;
        }
        trace("Program linked successfully");
        return true;
    }

    // -------------------------------------------------------------------------
    // Introspection — uses WebGL2 getActiveAttrib / getActiveUniform
    // -------------------------------------------------------------------------

    private function introspectProgram():Void {
        if (!isCompiled) return;
        trace("Introspecting shader program: " + __name);
        attributes = [];
        uniforms   = [];
        introspectAttributes();
        introspectUniforms();
        trace("Introspection complete.");
    }

    private function introspectAttributes():Void {
        var count = GL.getProgramActiveAttributes(program);
        trace("Found " + count + " active attributes");

        for (i in 0...count) {
            var info:Dynamic = GL.getActiveAttrib(program, i);
            if (info == null) continue;

            var attrName:String = info.name;
            var glType:Int      = info.type;
            var location:Int    = GL.getAttribLocation(program, attrName);
            var format          = convertGLTypeToAttributeFormat(glType);
            var components      = AttributeFormatHelper.getValuesPerVertex(format);

            trace('Attribute $i: "$attrName" loc=$location type=$glType');
            attributes.push({
                name:     attrName,
                format:   format,
                size:     components,
                stride:   0, // calculated below
                offset:   0,
                location: location
            });
        }

        if (attributes.length == 0) return;

        // Sort by location for a deterministic, consistent interleaved layout
        attributes.sort(function(a, b) return a.location - b.location);

        var offset = 0;
        for (attr in attributes) {
            attr.offset = offset;
            offset += AttributeFormatHelper.getBytesPerVertex(attr.format);
        }
        vertexStride = offset;
        for (attr in attributes) attr.stride = vertexStride;

        trace("Vertex stride: " + vertexStride + " bytes");
    }

    private function introspectUniforms():Void {
        var count = GL.getProgramActiveUniforms(program);
        trace("Found " + count + " active uniforms");

        for (i in 0...count) {
            var info:Dynamic = GL.getActiveUniform(program, i);
            if (info == null) continue;

            var uName:String  = info.name;
            var glType:Int    = info.type;
            var location:Int  = GL.getUniformLocation(program, uName);
            var format        = convertGLTypeToUniformFormat(glType);

            trace('Uniform $i: "$uName" loc=$location type=$glType');

            var setter = createUniformSetter(format, location);
            var uniformData:Uniform = {
                name:     uName,
                format:   format,
                setter:   setter,
                location: location
            };

            uniforms.push(uniformData);
            uniformMap.set(uName, uniformData);

            if (format == UniformFormat.Sampler2D) {
                textures.push({
                    name:     uName,
                    format:   format,
                    setter:   function(slot:Int) GL.uniform1i(location, slot),
                    location: location
                });
            }
        }
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    public function getUniform(name:String):Uniform {
        return uniformMap.get(name);
    }

    public function setupVertexAttributes():Void {
        // Called per-draw on web when not using the VAO cache in Renderer.
        // Requires the VBO to already be bound.
        for (attr in attributes) {
            GL.enableVertexAttribArray(attr.location);
            GL.vertexAttribPointer(attr.location, attr.size, getGLFormat(attr.format), false, attr.stride, attr.offset);
        }
    }

    public function dispose():Void {
        if (isCompiled) {
            GL.deleteShader(vertexShader);
            GL.deleteShader(fragmentShader);
            GL.deleteProgram(program);
        }
        if (vao != 0) GL.deleteVertexArray(vao);
        isCompiled = false;
    }

    // -------------------------------------------------------------------------
    // Uniform setter factories — return closures for zero-overhead dispatch
    // -------------------------------------------------------------------------

    private function createUniformSetter(format:UniformFormat, location:UniformLocation):Dynamic {
        return switch (format) {
            case UniformFormat.Float:      function(v:Dynamic) GL.uniform1f(location, v);
            case UniformFormat.Vec2:       function(v:Dynamic) { var a:Array<Float> = v; GL.uniform2f(location, a[0], a[1]); };
            case UniformFormat.Vec3:       function(v:Dynamic) { var a:Array<Float> = v; GL.uniform3f(location, a[0], a[1], a[2]); };
            case UniformFormat.Vec4:       function(v:Dynamic) { var a:Array<Float> = v; GL.uniform4f(location, a[0], a[1], a[2], a[3]); };
            case UniformFormat.Mat2:       function(v:Dynamic) GL.uniformMatrix2fv(location, false, v);
            case UniformFormat.Mat3:       function(v:Dynamic) GL.uniformMatrix3fv(location, false, v);
            case UniformFormat.Mat4:       function(v:Dynamic) GL.uniformMatrix4fv(location, false, v);
            case UniformFormat.Int:        function(v:Dynamic) GL.uniform1i(location, v);
            case UniformFormat.IntVec2:    function(v:Dynamic) { var a:Array<Int> = v; GL.uniform2i(location, a[0], a[1]); };
            case UniformFormat.IntVec3:    function(v:Dynamic) { var a:Array<Int> = v; GL.uniform3i(location, a[0], a[1], a[2]); };
            case UniformFormat.IntVec4:    function(v:Dynamic) { var a:Array<Int> = v; GL.uniform4i(location, a[0], a[1], a[2], a[3]); };
            case UniformFormat.Bool:       function(v:Dynamic) GL.uniform1i(location, v ? 1 : 0);
            case UniformFormat.BoolVec2:   function(v:Dynamic) { var a:Array<Bool> = v; GL.uniform2i(location, a[0] ? 1 : 0, a[1] ? 1 : 0); };
            case UniformFormat.BoolVec3:   function(v:Dynamic) { var a:Array<Bool> = v; GL.uniform3i(location, a[0] ? 1 : 0, a[1] ? 1 : 0, a[2] ? 1 : 0); };
            case UniformFormat.BoolVec4:   function(v:Dynamic) { var a:Array<Bool> = v; GL.uniform4i(location, a[0] ? 1 : 0, a[1] ? 1 : 0, a[2] ? 1 : 0, a[3] ? 1 : 0); };
            case UniformFormat.Sampler2D:  function(v:Dynamic) GL.uniform1i(location, v);
            case UniformFormat.SamplerCube:function(v:Dynamic) GL.uniform1i(location, v);
        };
    }

    // -------------------------------------------------------------------------
    // GL type conversion helpers
    // -------------------------------------------------------------------------

    private function convertGLTypeToAttributeFormat(glType:Int):AttributeFormat {
        return switch (glType) {
            case 5126:  AttributeFormat.Float;        // GL_FLOAT
            case 35664: AttributeFormat.Vec2;         // GL_FLOAT_VEC2
            case 35665: AttributeFormat.Vec3;         // GL_FLOAT_VEC3
            case 35666: AttributeFormat.Vec4;         // GL_FLOAT_VEC4
            case 5124:  AttributeFormat.Int;          // GL_INT
            case 5125:  AttributeFormat.UnsignedInt;  // GL_UNSIGNED_INT
            case 5120:  AttributeFormat.Byte;         // GL_BYTE
            case 5121:  AttributeFormat.UnsignedByte; // GL_UNSIGNED_BYTE
            case 5122:  AttributeFormat.Short;        // GL_SHORT
            case 5123:  AttributeFormat.UnsignedShort;// GL_UNSIGNED_SHORT
            default:    AttributeFormat.Float;
        };
    }

    private function convertGLTypeToUniformFormat(glType:Int):UniformFormat {
        return switch (glType) {
            case 5126:  UniformFormat.Float;
            case 35664: UniformFormat.Vec2;
            case 35665: UniformFormat.Vec3;
            case 35666: UniformFormat.Vec4;
            case 35674: UniformFormat.Mat2;
            case 35675: UniformFormat.Mat3;
            case 35676: UniformFormat.Mat4;
            case 5124:  UniformFormat.Int;
            case 35667: UniformFormat.IntVec2;
            case 35668: UniformFormat.IntVec3;
            case 35669: UniformFormat.IntVec4;
            case 35670: UniformFormat.Bool;
            case 35671: UniformFormat.BoolVec2;
            case 35672: UniformFormat.BoolVec3;
            case 35673: UniformFormat.BoolVec4;
            case 35678 | 35680: UniformFormat.Sampler2D;
            case 35681: UniformFormat.SamplerCube;
            default:    UniformFormat.Float;
        };
    }

    private function getGLFormat(format:AttributeFormat):Int {
        return switch (format) {
            case Float | Vec2 | Vec3 | Vec4: 5126; // GL_FLOAT
            case Int:          5124;
            case UnsignedInt:  5125;
            case Byte:         5120;
            case UnsignedByte: 5121;
            case Short:        5122;
            case UnsignedShort:5123;
        };
    }

    public function printVertexLayout():Void {
        trace("=== Vertex Layout for " + __name + " ===");
        trace("Total vertex stride: " + vertexStride + " bytes");
        for (i in 0...attributes.length) {
            var attr = attributes[i];
            trace('  [$i] ${attr.name}  loc=${attr.location}  offset=${attr.offset}  stride=${attr.stride}');
        }
        trace("========================");
    }

    // -------------------------------------------------------------------------
    // Getters
    // -------------------------------------------------------------------------

    private function get_name():String      { return __name; }
    private function get_textureCount():Int { return textures.length; }
}
#end
