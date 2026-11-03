package web;

#if js
import web.GL;
import ShaderBuilder;
import data.Shader as DataShader;
import Texture;

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

typedef AttributeInfo = {
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
    var ?textureUnit:Int;
}

// -------------------------------------------------------------------------
// ProgramInfo
// -------------------------------------------------------------------------

class ProgramInfo {

    // ** Compiled program handle
    public var program:Program       = 0;
    public var programId:Int         = -1;

    // ** Vertex attributes and uniforms
    public var attributes:Array<AttributeInfo> = [];
    public var uniforms:Array<Uniform>     = [];

    // ** Rendering properties
    public var name(get, null):String;
    public var vertexStride:Int = 0;
    public var textureCount(get, null):Int;

    // ** VAO — created for compatibility; web uses per-(program,vbo) VAO cache in Renderer
    public var vao:GlUInt = 0;
    public var useModernBinding:Bool = false; // always false on web

    private var __name:String;
    private var __samplerUnitsInitialized:Bool = false;

    public function new(name:String, ?vertexSource:String, ?fragmentSource:String) {
        __name = name;

        // Capture defaults BEFORE patchForTarget() strips them (GLSL ES has no default uniforms)
        var defaults:Map<String, Dynamic> = new Map();
        if (fragmentSource != null)
            for (k => v in ShaderBuilder.extractUniformDefaults(fragmentSource)) defaults.set(k, v);
        if (vertexSource != null)
            for (k => v in ShaderBuilder.extractUniformDefaults(vertexSource)) defaults.set(k, v);

        var patchedFragmentSource = ShaderBuilder.patchForTarget(fragmentSource);
        var patchedVertexSource = (vertexSource != null)
                                ? ShaderBuilder.patchForTarget(vertexSource)
                                : ShaderBuilder.defaultVertexFor(patchedFragmentSource);
        programId = -1;

        if (!compileProgramInfo(patchedVertexSource, patchedFragmentSource)) {
            trace("Failed to compile shader program: " + name);
            return;
        }

        introspectProgram(patchedFragmentSource);

        // Apply parsed defaults so WebGL uniforms start at the same value as native GLSL defaults
        if (defaults.keys().hasNext()) {
            GL.useProgram(program);
            for (uname => value in defaults) {
                var u = getUniform(uname);
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

    private function compileProgramInfo(vertexSource:String, fragmentSource:String):Bool {
        // Vertex shader
        var vertexShader = GL.createShader(GL.VERTEX_SHADER);
        GL.shaderSource(vertexShader, vertexSource);
        GL.compileShader(vertexShader);
        if (!checkShaderCompilation(vertexShader, "Vertex")) {
            GL.deleteShader(vertexShader);
            return false;
        }

        // Fragment shader
        var fragmentShader = GL.createShader(GL.FRAGMENT_SHADER);
        GL.shaderSource(fragmentShader, fragmentSource);
        GL.compileShader(fragmentShader);
        if (!checkShaderCompilation(fragmentShader, "Fragment")) {
            GL.deleteShader(vertexShader);
            GL.deleteShader(fragmentShader);
            return false;
        }

        // Link program
        program = GL.createProgram();
        GL.attachShader(program, vertexShader);
        GL.attachShader(program, fragmentShader);
        GL.linkProgram(program);

        var linked = checkProgramLinking(program);
        GL.deleteShader(vertexShader);
        GL.deleteShader(fragmentShader);
        if (!linked) {
            GL.deleteProgram(program);
            program = 0;
            return false;
        }

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

    private function introspectProgram(fragmentSource:String):Void {
        if (program == 0) return;
        trace("Introspecting shader program: " + __name);
        attributes = [];
        uniforms   = [];
        introspectAttributes();
        introspectUniforms(fragmentSource);
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
            var components      = getValuesPerVertex(format);

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
            offset += getBytesPerVertex(attr.format);
        }
        vertexStride = offset;
        for (attr in attributes) attr.stride = vertexStride;

        trace("Vertex stride: " + vertexStride + " bytes");
    }

    private function introspectUniforms(fragmentSource:String):Void {
        var count = GL.getProgramActiveUniforms(program);
        trace("Found " + count + " active uniforms");
        uniforms = [];
        var samplers:Array<Uniform> = [];

        for (i in 0...count) {
            var info:Dynamic = GL.getActiveUniform(program, i);
            if (info == null) continue;

            var uName:String  = info.name;
            var glType:Int    = info.type;
            var location:Int  = GL.getUniformLocation(program, uName);
            var format        = convertGLTypeToUniformFormat(glType);

            trace('Uniform $i: "$uName" loc=$location type=$glType');

            var isSampler = format == UniformFormat.Sampler2D || format == UniformFormat.SamplerCube;
            var uniformData:Uniform = {
                name:     uName,
                format:   format,
                setter:   isSampler ? null : createUniformSetter(format, location),
                location: location
            };

            setUniformAt(DataShader.getUniformId(canonicalUniformName(uName)), uniformData);

            if (isSampler) {
                samplers.push(uniformData);
            }
        }

        // Assign texture units in shader declaration order, not driver enumeration order.
        if (fragmentSource != null && samplers.length > 1) {
            samplers.sort(function(a, b) {
                var posA = fragmentSource.indexOf(a.name);
                var posB = fragmentSource.indexOf(b.name);
                if (posA < 0) posA = 0x7fffffff;
                if (posB < 0) posB = 0x7fffffff;
                return posA - posB;
            });
        }

        for (i in 0...samplers.length) {
            var sampler = samplers[i];
            sampler.textureUnit = i;
            sampler.setter = createTextureSetter(i);
        }
    }

    public function initializeSamplerUnits():Void {
        if (__samplerUnitsInitialized) return;

        for (uniform in uniforms) {
            if (uniform != null && uniform.textureUnit != null) {
                GL.uniform1i(uniform.location, uniform.textureUnit);
            }
        }
        __samplerUnitsInitialized = true;
    }

    private function createTextureSetter(textureUnit:Int):Texture->Void {
        return function(value:Texture):Void {
            var texture = value;
            if (texture == null) {
                throw "Texture uniform has no texture value";
            }
            GL.activeTexture(GL.TEXTURE0 + textureUnit);
            GL.bindTexture(texture.target, texture.id);
        };
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    public function getUniform(name:String):Uniform {
        return getUniformAt(DataShader.getUniformId(canonicalUniformName(name)));
    }

    public function getUniformAt(index:Int):Null<Uniform> {
        if (index < 0 || index >= uniforms.length) return null;
        return uniforms[index];
    }

    private function canonicalUniformName(name:String):String {
        return StringTools.endsWith(name, "[0]")
            ? name.substr(0, name.length - 3)
            : name;
    }

    private function setUniformAt(index:Int, uniform:Uniform):Void {
        while (uniforms.length <= index) {
            uniforms.push(cast null);
        }
        uniforms[index] = uniform;
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
        if (program != 0) {
            GL.deleteProgram(program);
            program = 0;
        }
        if (vao != 0) {
            GL.deleteVertexArray(vao);
            vao = 0;
        }
        __samplerUnitsInitialized = false;
    }

    // -------------------------------------------------------------------------
    // Uniform setter factories — return closures for zero-overhead dispatch
    // -------------------------------------------------------------------------

    private function createUniformSetter(format:UniformFormat, location:UniformLocation):Dynamic {
        return switch (format) {
            case UniformFormat.Float:      function(v:Float) GL.uniform1f(location, v);
            case UniformFormat.Vec2:       function(v:Array<Float>) GL.uniform2f(location, v[0], v[1]);
            case UniformFormat.Vec3:       function(v:Array<Float>) GL.uniform3f(location, v[0], v[1], v[2]);
            case UniformFormat.Vec4:       function(v:Array<Float>) GL.uniform4f(location, v[0], v[1], v[2], v[3]);
            case UniformFormat.Mat2:       function(v:Array<Float>) GL.uniformMatrix2fv(location, false, v);
            case UniformFormat.Mat3:       function(v:Array<Float>) GL.uniformMatrix3fv(location, false, v);
            case UniformFormat.Mat4:       function(v:Array<Float>) GL.uniformMatrix4fv(location, false, v);
            case UniformFormat.Int:        function(v:Int) GL.uniform1i(location, v);
            case UniformFormat.IntVec2:    function(v:Array<Int>) GL.uniform2i(location, v[0], v[1]);
            case UniformFormat.IntVec3:    function(v:Array<Int>) GL.uniform3i(location, v[0], v[1], v[2]);
            case UniformFormat.IntVec4:    function(v:Array<Int>) GL.uniform4i(location, v[0], v[1], v[2], v[3]);
            case UniformFormat.Bool:       function(v:Bool) GL.uniform1i(location, v ? 1 : 0);
            case UniformFormat.BoolVec2:   function(v:Array<Bool>) GL.uniform2i(location, v[0] ? 1 : 0, v[1] ? 1 : 0);
            case UniformFormat.BoolVec3:   function(v:Array<Bool>) GL.uniform3i(location, v[0] ? 1 : 0, v[1] ? 1 : 0, v[2] ? 1 : 0);
            case UniformFormat.BoolVec4:   function(v:Array<Bool>) GL.uniform4i(location, v[0] ? 1 : 0, v[1] ? 1 : 0, v[2] ? 1 : 0, v[3] ? 1 : 0);
            case UniformFormat.Sampler2D:  function(v:Int) GL.uniform1i(location, v);
            case UniformFormat.SamplerCube:function(v:Int) GL.uniform1i(location, v);
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
    private function get_textureCount():Int {
        var count = 0;
        for (uniform in uniforms) {
            if (uniform != null && uniform.textureUnit != null) count++;
        }
        return count;
    }
}
#end
