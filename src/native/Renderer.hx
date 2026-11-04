package native;

import cpp.ConstCharStar;
import cpp.Float32;
import cpp.RawConstPointer;
import cpp.RawPointer;
import cpp.UInt32;
import data.Indices;
import data.Shader as DataShader;
import data.TextureData;
import data.Vertices;
import data.AttributeInfo;
import data.UniformInfo;
import types.AttributeFormat.AttributeFormat;
import types.UniformFormat.UniformFormat;
import display.DepthVisualizationScreenPass;
import display.GrayscaleScreenPass;
import display.ScanlineScreenPass;
import display.ScreenPass;
import ds.SlotArray;
import GL;
import Log;
import math.Matrix;
import ProgramInfo;
import Texture;

private typedef FramebufferTextureConfig = {
    final attachment:Int;
    final internalFormat:Int;
    final format:Int;
    final type:Int;
}

private typedef FramebufferTextureAttachment = {
    final attachment:Int;
    final texture:Texture;
}

private class Framebuffer {
    public var fbo:UInt = 0;
    public var textureConfigs:Array<FramebufferTextureConfig>;
    public var textures:Array<FramebufferTextureAttachment> = [];
    public var depthRenderbuffer:UInt = 0;
    public var width:Int;
    public var height:Int;
    public var hasDepthRenderbuffer:Bool;

	public function new(width:Int, height:Int, textureConfigs:Array<FramebufferTextureConfig>, useDepthRenderbuffer:Bool) {
		this.width = width;
		this.height = height;
		this.textureConfigs = textureConfigs;
		this.hasDepthRenderbuffer = useDepthRenderbuffer;
	}
}

private typedef ShaderDefinition = {
    final name:String;
    final vertexSource:String;
    final fragmentSource:String;
}

class Buffers {
	public var vbo:UInt32;
	public var ebo:UInt32;
    public var programInfo:ProgramInfo;

    public function new(vbo:UInt32, ebo:UInt32, programInfo:ProgramInfo) {
        this.vbo = vbo;
        this.ebo = ebo;
        this.programInfo = programInfo;
    }
}

@:build(macros.ShaderRegistryMacro.build("shaders"))
class Renderer {
    
    // Publics
    public var app(get, null):App;
    public var frameCount(get, null):Int;
    public var matrix:Matrix = new Matrix();

    // Privates
    private var __app:App;
    private var __currentDepthTest:Bool = false;
    private var __currentDepthWrite:Bool = false;
    private var __currentBlendMode:Bool = false;
    private var __currentBlendSource:Int = -1;
    private var __currentBlendDestination:Int = -1;
    private var __frameCount:Int = 0;
    private var __programInfos:Array<ProgramInfo> = new Array<ProgramInfo>();
    private var __initializedSamplerPrograms:Map<String, Bool> = new Map<String, Bool>();

    private var buffers:SlotArray<Buffers> = new SlotArray<Buffers>(32);
    private var framebuffers:SlotArray<Framebuffer> = new SlotArray<Framebuffer>(8);
    private var __framebufferStack:Array<Int> = [];

    public var postProcessDisplayObject:ScreenPass = null;
    public var usePostProcessing:Bool = false; // Toggle post-processing on/off
    private var __screenPasses:Array<ScreenPass> = [];
    private var __activeScreenPassIndex:Int = 0;
    private var currentProgram:Int = -1;
    private var currentVbo:Int = 0;
    private var currentEbo:Int = 0;
    
    // ===== LIFECYCLE =====

    public function new(app:App) {
        __app = app;

		for (definition in definitions) {
            var programInfo = createProgramInfoObject(
                definition.name,
                definition.vertexSource,
                definition.fragmentSource
            );
            __programInfos.push(programInfo);
		}

        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(true);
    }
    
    public function render():Void {
        currentProgram = -1;
        currentVbo = 0;
        currentEbo = 0;
        __currentBlendSource = -1;
        __currentBlendDestination = -1;
        __frameCount++;
    }

    public function release():Void {
        // Reset render state
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(false);

        while (__framebufferStack.length > 0) {
            unbindFramebuffer(__framebufferStack[__framebufferStack.length - 1]);
        }

        if (postProcessDisplayObject != null) {
            for (screenPass in __screenPasses) {
                screenPass.dispose(this);
                screenPass.release(this);
            }
            __screenPasses = [];
            postProcessDisplayObject = null;
        }

        for (framebuffer in framebuffers) {
            disposeFramebufferResources(framebuffer, true);
        }
        framebuffers.clear();

        for (buffer in buffers) {
            deleteBuffers(buffers.indexOf(buffer));
        }
        buffers.clear();

        for (programInfo in __programInfos) {
            disposeProgramInfo(programInfo);
        }
        __programInfos = [];
        __initializedSamplerPrograms = new Map<String, Bool>();

        __app.log.info(LogCategory.RENDERER, "Renderer cleanup complete");
    }

    // ===== PROGRAMS AND DRAWING =====

    public function useProgram(programInfo:ProgramInfo):Void {
        if (programInfo.program != currentProgram) {
            GL.useProgram(programInfo.program);
            GL.bindVertexArray(programInfo.vao);
            initializeSamplerUnits(programInfo);
            currentProgram = programInfo.program;
            currentVbo = 0;
            currentEbo = 0;
        }
    }

    public function getProgramInfo(index:Int):ProgramInfo {
        if (index < 0 || index >= __programInfos.length) {
            throw "ProgramInfo index out of range: " + index;
        }
        return __programInfos[index];
    }

    public function renderUniforms(programInfo:ProgramInfo, shader:Null<DataShader>):Void {
        if (shader == null) return;

        for (uniform in shader.getUniforms()) {
            var uniformInfo = programInfo.uniformInfos[uniform.nameId];

            // If the uniform doesn't exist in the shader, log a warning and skip it
            if (uniformInfo == null) {
                __app.log.warn(
                    LogCategory.RENDERER,
                    "Uniform '" + uniform.name + "' doesn't exist in shader"
                );

                continue;
            }

            if (uniformInfo.setter == null) {
                throw "Uniform setter is missing for program uniform '" + uniformInfo.name + "'";
            }
            uniformInfo.setter(uniform.value);
        }
    }

    public function drawElements(mode:Int, count:Int):Void {
        GL.drawElements(mode, count, GL.UNSIGNED_INT, 0);
    }

    public function drawArrays(mode:Int, first:Int, count:Int):Void {
        GL.drawArrays(mode, first, count);
    }
    
    public function createProgramInfo(name:String, vertexSource:String, fragmentSource:String):ProgramInfo {
        var programInfo = createProgramInfoObject(name, vertexSource, fragmentSource);

        __programInfos.push(programInfo);

        __app.log.info(LogCategory.RENDERER, "Created and registered ProgramInfo: " + name);

        return programInfo;
    }

    private function createProgramInfoObject(name:String, vertexSource:String, fragmentSource:String):ProgramInfo {
        var program = compileProgram(name, vertexSource, fragmentSource);
        if (program == 0) {
            trace("Failed to compile shader program: " + name);
            return new ProgramInfo(name, program, 0, [], [], 0);
        }

        var introspection = try {
            introspectProgram(program, fragmentSource, name);
        } catch (error:Dynamic) {
            GL.deleteProgram(program);
            throw error;
        }

        var vao:UInt;
        try {
            vao = createProgramVertexArray(introspection.attributes);
        } catch (error:Dynamic) {
            GL.deleteProgram(program);
            throw error;
        }

        return new ProgramInfo(
            name,
            program,
            vao,
            introspection.attributes,
            introspection.uniforms,
            introspection.vertexStride
        );
    }

    private function compileProgram(name:String, vertexSource:String, fragmentSource:String):UInt {
        var vertexContent = ConstCharStar.fromString(vertexSource);
        var fragmentContent = ConstCharStar.fromString(fragmentSource);

        var vertexShader = GL.createShader(GL.VERTEX_SHADER);
        GL.shaderSource(vertexShader, 1, RawPointer.addressOf(vertexContent), null);
        GL.compileShader(vertexShader);
        if (!checkShaderCompilation(vertexShader, "Vertex")) {
            GL.deleteShader(vertexShader);
            trace("Vertex shader compilation failed for " + name);
            return 0;
        }

        var fragmentShader = GL.createShader(GL.FRAGMENT_SHADER);
        GL.shaderSource(fragmentShader, 1, RawPointer.addressOf(fragmentContent), null);
        GL.compileShader(fragmentShader);
        if (!checkShaderCompilation(fragmentShader, "Fragment")) {
            GL.deleteShader(vertexShader);
            GL.deleteShader(fragmentShader);
            trace("Fragment shader compilation failed for " + name);
            return 0;
        }

        var program = GL.createProgram();
        GL.attachShader(program, vertexShader);
        GL.attachShader(program, fragmentShader);
        GL.linkProgram(program);
        var linked = checkProgramLinking(program);

        GL.deleteShader(vertexShader);
        GL.deleteShader(fragmentShader);
        if (!linked) {
            GL.deleteProgram(program);
            return 0;
        }

        return program;
    }

    private function checkShaderCompilation(shader:UInt, type:String):Bool {
        var success = GL.getShaderParameterValue(shader, GL.COMPILE_STATUS);
        if (success == 0) {
            var errorLog = GL.getShaderInfoLogString(shader);
            if (errorLog.length > 0) {
                trace(type + " shader compilation failed:");
                trace(errorLog);
            } else {
                trace(type + " shader compilation failed with no error log");
            }
            return false;
        }

        trace(type + " shader compiled successfully");
        return true;
    }

    private function checkProgramLinking(program:UInt):Bool {
        var success = GL.getProgramParameterValue(program, GL.LINK_STATUS);
        if (success == 0) {
            var errorLog = GL.getProgramInfoLogString(program);
            if (errorLog.length > 0) {
                trace("Program linking failed:");
                trace(errorLog);
            } else {
                trace("Program linking failed with no error log");
            }
            return false;
        }

        trace("Program linked successfully");
        return true;
    }

    private function createProgramVertexArray(attributes:Array<AttributeInfo>):UInt {
        if (GL.GLAD_GL_ARB_vertex_attrib_binding == 0) {
            throw "ARB_vertex_attrib_binding not available";
        }

        var vao = GL.createVertexArray();
        try {
            GL.bindVertexArray(vao);
            for (attribute in attributes) {
                GL.vertexAttribFormat(
                    attribute.location,
                    attribute.size,
                    getGLFormat(attribute.format),
                    false,
                    attribute.offset
                );
                GL.vertexAttribBinding(attribute.location, 0);
                GL.enableVertexAttribArray(attribute.location);
            }
            GL.bindVertexArray(0);
        } catch (error:Dynamic) {
            GL.bindVertexArray(0);
            var vaos = [vao];
            GL.deleteVertexArrays(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vaos));
            throw error;
        }
        return vao;
    }

    private function getGLFormat(format:types.AttributeFormat.AttributeFormat):Int {
        return switch (format) {
            case Float | Vec2 | Vec3 | Vec4: 5126;
            case Int: 5124;
            case UnsignedInt: 5125;
            case Byte: 5120;
            case UnsignedByte: 5121;
            case Short: 5122;
            case UnsignedShort: 5123;
        };
    }

	private function introspectProgram(program:UInt, fragmentSource:String, name:String) {
        trace("Starting shader program introspection for: " + name);
        var attributes = introspectAttributes(program);
        var uniforms = introspectUniforms(program, fragmentSource);
        var vertexStride:UInt = 0;
        if (attributes.length > 0) {
            for (attribute in attributes) vertexStride += getBytesPerVertex(attribute.format);
            var offset:UInt = 0;
            for (attribute in attributes) {
                attribute.offset = offset;
                attribute.stride = vertexStride;
                offset += getBytesPerVertex(attribute.format);
            }
        }
        trace("Introspection complete!");
        return {
            attributes: attributes,
            uniforms: uniforms,
            vertexStride: vertexStride
        };
    }

    private function introspectAttributes(program:UInt):Array<AttributeInfo> {
        var activeAttributes:Int = 0;
        untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_ATTRIBUTES, &{1})", program, activeAttributes);
        trace("Found " + activeAttributes + " active attributes");

        var maxNameLength:Int = 0;
        untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &{1})", program, maxNameLength);

        var attributes:Array<AttributeInfo> = [];
        for (i in 0...activeAttributes) {
            var nameLength:Int = 0;
            var size:Int = 0;
            var type:Int = 0;
            var name:String = "";
            untyped __cpp__("
                char* nameBuffer = new char[{0}];
                glGetActiveAttrib({1}, {2}, {0}, &{3}, &{4}, (GLenum*)&{5}, nameBuffer);
                {6} = String(nameBuffer);
                delete[] nameBuffer;
            ", maxNameLength, program, i, nameLength, size, type, name);

            var location = GL.getAttribLocation(program, name);
            var format = AttributeFormat.fromGLType(type);
            attributes.push({
                name: name,
                format: format,
                size: getValuesPerVertex(format),
                stride: 0,
                offset: 0,
                location: location
            });
            trace("Attribute " + i + ": '" + name + "' location=" + location + " type=" + type + " format=" + format);
        }

        attributes.sort(function(a, b) return a.location - b.location);
        return attributes;
    }

	private function introspectUniforms(program:UInt, fragmentSource:String):Array<UniformInfo> {
        var activeUniforms:Int = 0;
        untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_UNIFORMS, &{1})", program, activeUniforms);
        trace("Found " + activeUniforms + " active uniforms");

        var maxNameLength:Int = 0;
        untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_UNIFORM_MAX_LENGTH, &{1})", program, maxNameLength);
        var uniforms:Array<UniformInfo> = [];
        var samplers:Array<UniformInfo> = [];

        for (i in 0...activeUniforms) {
            var nameLength:Int = 0;
            var size:Int = 0;
            var type:Int = 0;
            var name:String = "";
            untyped __cpp__("
                char* nameBuffer = new char[{0}];
                glGetActiveUniform({1}, {2}, {0}, &{3}, &{4}, (GLenum*)&{5}, nameBuffer);
                {6} = String(nameBuffer);
                delete[] nameBuffer;
            ", maxNameLength, program, i, nameLength, size, type, name);

            var location = GL.getUniformLocation(program, name);
            var format = UniformFormat.fromGLType(type);
            var isSampler = format == UniformFormat.Sampler2D
                || format == UniformFormat.SamplerCube;
                
            var uniform:UniformInfo = {
                name: name,
                format: format,
                setter: isSampler ? null : createUniformSetter(format, location),
                location: location
            };
            setUniformAt(uniforms, DataShader.getUniformId(canonicalUniformName(name)), uniform);
            if (isSampler) samplers.push(uniform);
            trace("Uniform " + i + ": '" + name + "' location=" + location + " type=" + type + " format=" + format);
        }

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
            if (sampler.location == null) {
                throw "Sampler uniform '" + sampler.name + "' has no GL location";
            }
            sampler.setter = createUniformSetter(sampler.format, sampler.location, i);
        }
        return uniforms;
    }

    private function initializeSamplerUnits(programInfo:ProgramInfo):Void {
        var key = Std.string(programInfo.program);
        if (__initializedSamplerPrograms.exists(key)) return;

        for (uniform in programInfo.uniformInfos) {
            if (uniform != null && uniform.textureUnit != null && uniform.location != null) {
                GL.uniform1i(uniform.location, uniform.textureUnit);
            }
        }
        __initializedSamplerPrograms.set(key, true);
    }

	private function setUniformAt(uniforms:Array<UniformInfo>, index:Int, uniform:UniformInfo):Void {
		while (uniforms.length <= index)
			uniforms.push(cast null);
		uniforms[index] = uniform;
	}

    private function canonicalUniformName(name:String):String {
        return StringTools.endsWith(name, "[0]") ? name.substr(0, name.length - 3) : name;
    }

    private function getValuesPerVertex(format:AttributeFormat):Int {
        return switch (format) {
            case Float: 1;
            case Vec2: 2;
            case Vec3: 3;
            case Vec4: 4;
            case Int | UnsignedInt | Byte | UnsignedByte | Short | UnsignedShort: 1;
        };
    }

    private function getBytesPerVertex(format:AttributeFormat):UInt {
        return switch (format) {
            case Float | Int | UnsignedInt: 4;
            case Vec2: 8;
            case Vec3: 12;
            case Vec4: 16;
            case Short | UnsignedShort: 2;
            case Byte | UnsignedByte: 1;
        };
    }

    private function createUniformSetter(format:UniformFormat, uniformLocation:Int, ?textureUnit:Int):Dynamic {
        return switch (format) {
            case Float: floatSetter(uniformLocation);
            case Vec2: floatVec2Setter(uniformLocation);
            case Vec3: floatVec3Setter(uniformLocation);
            case Vec4: floatVec4Setter(uniformLocation);
            case Mat2: floatMat2Setter(uniformLocation);
            case Mat3: floatMat3Setter(uniformLocation);
            case Mat4: floatMat4Setter(uniformLocation);
            case Int: intSetter(uniformLocation);
            case IntVec2: intVec2Setter(uniformLocation);
            case IntVec3: intVec3Setter(uniformLocation);
            case IntVec4: intVec4Setter(uniformLocation);
            case Bool: boolSetter(uniformLocation);
            case BoolVec2: boolVec2Setter(uniformLocation);
            case BoolVec3: boolVec3Setter(uniformLocation);
            case BoolVec4: boolVec4Setter(uniformLocation);
            case Sampler2D:
                if (textureUnit == null) throw "Sampler2D setter requires a texture unit";
                sampler2DSetter(textureUnit);
            case SamplerCube:
                if (textureUnit == null) throw "SamplerCube setter requires a texture unit";
                samplerCubeSetter(textureUnit);
        };
    }

    private function floatSetter(location:Int):Float->Void {
        return function(value:Float):Void GL.uniform1f(location, value);
    }

    private function floatVec2Setter(location:Int):Array<Float>->Void {
        return function(value:Array<Float>):Void {
            if (value.length >= 2)
                untyped __cpp__("glUniform2f({0}, {1}, {2})", location, value[0], value[1]);
        };
    }

    private function floatVec3Setter(location:Int):Array<Float>->Void {
        return function(value:Array<Float>):Void {
            if (value.length >= 3)
                untyped __cpp__("glUniform3f({0}, {1}, {2}, {3})", location, value[0], value[1], value[2]);
        };
    }

    private function floatVec4Setter(location:Int):Array<Float>->Void {
        return function(value:Array<Float>):Void {
            if (value.length >= 4)
                untyped __cpp__("glUniform4f({0}, {1}, {2}, {3}, {4})", location, value[0], value[1], value[2], value[3]);
        };
    }

    private function floatMat2Setter(location:Int):Array<Float>->Void {
        return function(value:Array<Float>):Void {
            untyped __cpp__("
                float matData[4];
                for(int i = 0; i < 4; i++) matData[i] = {1}[i];
                glUniformMatrix2fv({0}, 1, GL_FALSE, matData);
            ", location, value);
        };
    }

    private function floatMat3Setter(location:Int):Array<Float>->Void {
        return function(value:Array<Float>):Void {
            untyped __cpp__("
                float matData[9];
                for(int i = 0; i < 9; i++) matData[i] = {1}[i];
                glUniformMatrix3fv({0}, 1, GL_FALSE, matData);
            ", location, value);
        };
    }

    private function floatMat4Setter(location:Int):Array<Float>->Void {
        return function(value:Array<Float>):Void {
            untyped __cpp__("
                float matData[16];
                for(int i = 0; i < 16; i++) matData[i] = {1}[i];
                glUniformMatrix4fv({0}, 1, GL_FALSE, matData);
            ", location, value);
        };
    }

    private function intSetter(location:Int):Int->Void {
        return function(value:Int):Void GL.uniform1i(location, value);
    }

    private function intVec2Setter(location:Int):Array<Int>->Void {
        return function(value:Array<Int>):Void {
            if (value.length >= 2)
                untyped __cpp__("glUniform2i({0}, {1}, {2})", location, value[0], value[1]);
        };
    }

    private function intVec3Setter(location:Int):Array<Int>->Void {
        return function(value:Array<Int>):Void {
            if (value.length >= 3)
                untyped __cpp__("glUniform3i({0}, {1}, {2}, {3})", location, value[0], value[1], value[2]);
        };
    }

    private function intVec4Setter(location:Int):Array<Int>->Void {
        return function(value:Array<Int>):Void {
            if (value.length >= 4)
                untyped __cpp__("glUniform4i({0}, {1}, {2}, {3}, {4})", location, value[0], value[1], value[2], value[3]);
        };
    }

    private function boolSetter(location:Int):Bool->Void {
        return function(value:Bool):Void GL.uniform1i(location, value ? 1 : 0);
    }

    private function boolVec2Setter(location:Int):Array<Bool>->Void {
        return function(value:Array<Bool>):Void {
            if (value.length >= 2)
                untyped __cpp__("glUniform2i({0}, {1}, {2})", location, value[0] ? 1 : 0, value[1] ? 1 : 0);
        };
    }

    private function boolVec3Setter(location:Int):Array<Bool>->Void {
        return function(value:Array<Bool>):Void {
            if (value.length >= 3)
                untyped __cpp__("glUniform3i({0}, {1}, {2}, {3})", location, value[0] ? 1 : 0, value[1] ? 1 : 0, value[2] ? 1 : 0);
        };
    }

    private function boolVec4Setter(location:Int):Array<Bool>->Void {
        return function(value:Array<Bool>):Void {
            if (value.length >= 4)
                untyped __cpp__("glUniform4i({0}, {1}, {2}, {3}, {4})", location, value[0] ? 1 : 0, value[1] ? 1 : 0, value[2] ? 1 : 0, value[3] ? 1 : 0);
        };
    }

    private function sampler2DSetter(textureUnit:Int):Texture->Void {
        return function(texture:Texture):Void bindTextureUniform(textureUnit, texture);
    }

    private function samplerCubeSetter(textureUnit:Int):Texture->Void {
        return function(texture:Texture):Void bindTextureUniform(textureUnit, texture);
    }

    private function bindTextureUniform(textureUnit:Int, texture:Texture):Void {
        if (texture == null) throw "Texture uniform has no texture value";
        GL.activeTexture(GL.TEXTURE0 + textureUnit);
        GL.bindTexture(texture.target, texture.id);
    }

    private function disposeProgramInfo(programInfo:ProgramInfo):Void {
        __initializedSamplerPrograms.remove(Std.string(programInfo.program));
        if (programInfo.vao != 0) {
            var vaos = [programInfo.vao];
            GL.deleteVertexArrays(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vaos));
        }
        if (programInfo.program != 0) {
            GL.deleteProgram(programInfo.program);
        }
        programInfo.__vao = 0;
        programInfo.__program = 0;
    }
    
    // ===== BUFFERS =====

	public function bindBuffers(bufferId:Int, stride:Int):Void {
		var buffersObjs = buffers.get(bufferId);
		if (buffersObjs == null) {
			throw "Buffers not found for bufferId: " + bufferId;
		}

		// Also bind using modern ARB_vertex_attrib_binding
		if (buffersObjs.vbo != currentVbo) {
			GL.bindVertexBuffer(0, buffersObjs.vbo, 0, stride);
			currentVbo = buffersObjs.vbo;
		}

		// Bind element buffer if available
		if (buffersObjs.ebo != 0 && buffersObjs.ebo != currentEbo) {
			GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, buffersObjs.ebo);
			currentEbo = buffersObjs.ebo;
		}
	}

    public function createBuffers(programInfoIndex:Int):Int {
        if (programInfoIndex < 0 || programInfoIndex >= __programInfos.length) {
            throw "ProgramInfo index out of range: " + programInfoIndex;
        }

        var vbo:UInt32 = 0;
        var ebo:UInt32 = 0;

        GL.genBuffers(1, RawPointer.addressOf(vbo));
        GL.genBuffers(1, RawPointer.addressOf(ebo));

        return buffers.add(new Buffers(vbo, ebo, __programInfos[programInfoIndex]));
    }

    public function getBuffers(bufferId:Int):Buffers {
        return buffers.get(bufferId);
    }

    // Upload vertex data to GPU
    public function uploadData(bufferId:Int, vertices:Vertices, indices:Indices):Void {
        var bufferInfo = getBuffers(bufferId);

        GL.bindVertexArray(bufferInfo.programInfo.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, bufferInfo.vbo);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, vertices, GL.DYNAMIC_DRAW, vertices.length);
        if (bufferInfo.ebo != 0 && indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, bufferInfo.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, indices, GL.DYNAMIC_DRAW, indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }

    public function orphanAndUploadData(bufferId:Int, vertices:Vertices, indices:Indices, maxBufferSize:Int):Void {
        var bufferInfo = getBuffers(bufferId);

        GL.bindVertexArray(bufferInfo.programInfo.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, bufferInfo.vbo);
        untyped __cpp__("glBufferData({0}, {1}, NULL, {2})", GL.ARRAY_BUFFER, maxBufferSize, GL.STREAM_DRAW);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, vertices, GL.STREAM_DRAW, vertices.length);
        if (bufferInfo.ebo != 0 && indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, bufferInfo.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, indices, GL.STREAM_DRAW, indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }

    public function deleteBuffers(bufferId:Int):Void {
        var buffersObj = buffers.get(bufferId);
        if (buffersObj == null) return;

        GL.deleteBuffers(1, RawPointer.addressOf(buffersObj.vbo));
        GL.deleteBuffers(1, RawPointer.addressOf(buffersObj.ebo));

        buffers.remove(bufferId);
    }

    // ===== TEXTURES =====

    /**
     * Upload TextureData to OpenGL and return Texture object
     */
    public function uploadTexture(textureData:TextureData):Texture {
        if (textureData == null) {
            __app.log.error(LogCategory.RENDERER, "Cannot upload null texture data");
            return null;
        }

        var textureId:UInt32 = 0;
        GL.genTextures(1, RawPointer.addressOf(textureId));
        
        GL.bindTexture(GL.TEXTURE_2D, textureId);
        
        // Set texture parameters
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
        
        // Upload actual texture data with correct format based on BPP
        var format:Int;
        var internalFormat:Int;
        
        switch (textureData.bytesPerPixel) {
            case 1: // Grayscale/monochrome
                format = GL.RED;
                internalFormat = GL.RED;
            case 2: // Grayscale + Alpha
                format = GL.RG;
                internalFormat = GL.RG;
            case 3: // RGB
                format = GL.RGB;
                internalFormat = GL.RGB;
            case 4: // RGBA
                format = GL.RGBA;
                internalFormat = GL.RGBA;
            default:
                throw "Unsupported texture format: " + textureData.bytesPerPixel + " bytes per pixel";
        }
                    
        GL.texImage2D(GL.TEXTURE_2D, 0, internalFormat, textureData.width, textureData.height, 0, format, GL.UNSIGNED_BYTE, textureData.bytes.getData().bytes);
        GL.bindTexture(GL.TEXTURE_2D, 0);

        var texture:Texture = {
            id: textureId,
            width: textureData.width,
            height: textureData.height,
            bpp: textureData.bytesPerPixel,
            target: GL.TEXTURE_2D,
            src: textureData.src
        };
        
        return texture;
    }

    public function createRenderTargetTexture(width:Int, height:Int, internalFormat:Int, format:Int, type:Int):Texture {
        var textureId:UInt32 = 0;
        GL.genTextures(1, RawPointer.addressOf(textureId));
        GL.bindTexture(GL.TEXTURE_2D, textureId);

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);

        GL.texImage2D(GL.TEXTURE_2D, 0, internalFormat, width, height, 0, format, type, null);

        GL.bindTexture(GL.TEXTURE_2D, 0);

        return {
            id: textureId,
            width: width,
            height: height,
            bpp: (format == GL.RGBA ? 4 : 1),
            target: GL.TEXTURE_2D,
            src: ""
        };
    }

    // ===== RENDER STATE =====

    /**
     * Clear the screen and prepare for rendering
     */
    public function clearScreen():Void {
        GL.glClearColor(0.1, 0.1, 0.15, 1.0);
        GL.glClear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    }

    /**
     * Initialize rendering state
     */
    // public function initializeRenderState():Void {
    //     // Enable depth testing for 3D
    //     // GL.glEnable(GL.DEPTH_TEST);
    //     // GL.glDepthFunc(GL.LESS);

    //     // Disable face culling to see all faces from all angles
    //     GL.glDisable(GL.CULL_FACE);
    // }

	public function setBlendFunction(source:Int, destination:Int):Void {
		if (__currentBlendSource != source || __currentBlendDestination != destination) {
			GL.blendFunc(source, destination);
			__currentBlendSource = source;
			__currentBlendDestination = destination;
		}
	}

    public function setDepthTest(enabled:Bool):Void {
        if (__currentDepthTest != enabled) {
            if (enabled) {
                GL.glEnable(GL.DEPTH_TEST);
            } else {
                GL.glDisable(GL.DEPTH_TEST);
            }
            __currentDepthTest = enabled;
        }
    }
    
    public function setDepthWrite(enabled:Bool):Void {
        if (__currentDepthWrite != enabled) {
            GL.glDepthMask(enabled);
            __currentDepthWrite = enabled;
        }
    }
    
    public function setBlendMode(enabled:Bool):Void {
        if (__currentBlendMode != enabled) {
            if (enabled) {
                GL.glEnable(GL.BLEND);
                setBlendFunction(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
            } else {
                GL.glDisable(GL.BLEND);
            }
            __currentBlendMode = enabled;
        }
    }

    // ===== POST-PROCESSING =====

	public function initializePostProcessing():Void {
        if (postProcessDisplayObject != null) {
            return;
        }

        var size = app.window.getWindowSizeInPixels();
        __screenPasses = [];
        try {
            __screenPasses.push(new ScanlineScreenPass(this, size.width, size.height));
            __screenPasses.push(new GrayscaleScreenPass(this, size.width, size.height));
            __screenPasses.push(new DepthVisualizationScreenPass(this, size.width, size.height));
        } catch (error:Dynamic) {
            for (screenPass in __screenPasses) {
                screenPass.dispose(this);
                screenPass.release(this);
            }
            __screenPasses = [];
            throw error;
        }
        __activeScreenPassIndex = 0;
        postProcessDisplayObject = __screenPasses[__activeScreenPassIndex];
	}

    public function cyclePostProcess(delta:Int):Void {
        if (__screenPasses.length == 0) {
            throw "Post-processing screen passes are not initialized";
        }

        __activeScreenPassIndex = (__activeScreenPassIndex + delta) % __screenPasses.length;
        if (__activeScreenPassIndex < 0) {
            __activeScreenPassIndex += __screenPasses.length;
        }
        postProcessDisplayObject = __screenPasses[__activeScreenPassIndex];
        __app.log.info(
            LogCategory.RENDERER,
            "Selected screen pass " + (__activeScreenPassIndex + 1) + "/" + __screenPasses.length
                + ": " + postProcessDisplayObject.label
        );
    }

    // ===== FRAMEBUFFERS =====

	public function createFramebuffer(width:Int, height:Int, textureConfigs:Array<FramebufferTextureConfig>, useDepthRenderbuffer:Bool = false):Int {
        if (width <= 0 || height <= 0) {
            throw "Framebuffer dimensions must be positive";
        }

        if (textureConfigs == null) {
            throw "Framebuffer texture configurations cannot be null";
        }
        
        if (textureConfigs.length == 0 && !useDepthRenderbuffer) {
            throw "Framebuffer requires at least one attachment";
        }

        var hasDepthAttachment = false;
        for (i in 0...textureConfigs.length) {
            var attachment = textureConfigs[i].attachment;
            if (attachment == GL.DEPTH_ATTACHMENT || attachment == GL.DEPTH_STENCIL_ATTACHMENT) {
                if (useDepthRenderbuffer || hasDepthAttachment) {
                    throw "Framebuffer cannot have multiple depth attachments or combine a depth texture with a depth renderbuffer";
                }
                hasDepthAttachment = true;
            }

            for (j in 0...i) {
                if (attachment == textureConfigs[j].attachment) {
                    throw "Duplicate framebuffer attachment: " + attachment;
                }
            }
        }

        var framebuffer = new Framebuffer(width, height, textureConfigs.copy(), useDepthRenderbuffer);
        framebuffer.fbo = GL.createFramebuffer();
        try {
            initializeFramebufferAttachments(framebuffer);
        } catch (error:Dynamic) {
            restoreFramebufferBinding();
            disposeFramebufferResources(framebuffer, true);
            throw error;
        }
        return framebuffers.add(framebuffer);
    }

    public function getFramebufferTexture(frameBufferId:Int, attachment:Int):Texture {
        var framebuffer = getFramebufferOrThrow(frameBufferId);
        for (texture in framebuffer.textures) {
            if (texture.attachment == attachment) return texture.texture;
        }
        throw "Framebuffer " + frameBufferId + " has no texture at attachment " + attachment;
    }

    public function resizeFramebuffer(frameBufferId:Int, width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return;
        var framebuffer = getFramebufferOrThrow(frameBufferId);
        if (__framebufferStack.indexOf(frameBufferId) >= 0) {
            throw "Cannot resize framebuffer " + frameBufferId + " while it is bound";
        }
        if (framebuffer.width == width && framebuffer.height == height) return;

        disposeFramebufferAttachments(framebuffer);
        framebuffer.width = width;
        framebuffer.height = height;
        try {
            initializeFramebufferAttachments(framebuffer);
        } catch (error:Dynamic) {
            restoreFramebufferBinding();
            disposeFramebufferResources(framebuffer, true);
            framebuffers.remove(frameBufferId);
            throw error;
        }
    }

    private function getFramebufferOrThrow(frameBufferId:Int):Framebuffer {
        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer == null) {
            throw "Framebuffer with ID " + frameBufferId + " not found";
        }
        return framebuffer;
    }

    private function initializeFramebufferAttachments(framebuffer:Framebuffer):Void {
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer.fbo);
        for (config in framebuffer.textureConfigs) {
            var texture = createRenderTargetTexture(
                framebuffer.width,
                framebuffer.height,
                config.internalFormat,
                config.format,
                config.type
            );
            GL.framebufferTexture2D(
                GL.FRAMEBUFFER,
                config.attachment,
                GL.TEXTURE_2D,
                texture.id,
                0
            );
            framebuffer.textures.push({attachment: config.attachment, texture: texture});
        }

        var drawBuffers:Array<Int> = [];
        var firstColorAttachment = -1;
        for (config in framebuffer.textureConfigs) {
            if (config.attachment >= GL.COLOR_ATTACHMENT0
                && config.attachment < GL.COLOR_ATTACHMENT0 + 32) {
                var index = config.attachment - GL.COLOR_ATTACHMENT0;
                while (drawBuffers.length <= index) drawBuffers.push(GL.NONE);
                drawBuffers[index] = config.attachment;
                if (firstColorAttachment < 0) firstColorAttachment = config.attachment;
            }
        }
        GL.drawBuffers(
            drawBuffers.length > 0 ? drawBuffers.length : 1,
            drawBuffers.length > 0 ? drawBuffers : [GL.NONE]
        );
        GL.readBuffer(firstColorAttachment >= 0 ? firstColorAttachment : GL.NONE);

        if (framebuffer.hasDepthRenderbuffer) {
            var renderbuffers:Array<UInt> = [0];
            GL.genRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", renderbuffers));
            framebuffer.depthRenderbuffer = renderbuffers[0];
            GL.bindRenderbuffer(GL.RENDERBUFFER, framebuffer.depthRenderbuffer);
            GL.renderbufferStorage(
                GL.RENDERBUFFER, GL.DEPTH_COMPONENT24, framebuffer.width, framebuffer.height
            );
            GL.framebufferRenderbuffer(
                GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, framebuffer.depthRenderbuffer
            );
            GL.bindRenderbuffer(GL.RENDERBUFFER, 0);
        }

        var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
        restoreFramebufferBinding();
        if (status != GL.FRAMEBUFFER_COMPLETE) {
            var message = "Framebuffer incomplete: " + getFramebufferStatusString(status);
            __app.log.error(LogCategory.RENDERER, message);
            throw message;
        }
        __app.log.debug(
            LogCategory.RENDERER,
            "Created framebuffer " + framebuffer.width + "x" + framebuffer.height
        );
    }

    private function restoreFramebufferBinding():Void {
        var framebufferId = __framebufferStack.length > 0
            ? __framebufferStack[__framebufferStack.length - 1]
            : -1;
        var framebuffer = framebufferId >= 0 ? framebuffers.get(framebufferId) : null;
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer != null ? framebuffer.fbo : 0);
    }

    private function getFramebufferStatusString(status:Int):String {
        return switch (status) {
            case 0x8CD5: "FRAMEBUFFER_COMPLETE";
            case 0x8CD6: "FRAMEBUFFER_INCOMPLETE_ATTACHMENT";
            case 0x8CD7: "FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT";
            case 0x8CDB: "FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER";
            case 0x8CDC: "FRAMEBUFFER_INCOMPLETE_READ_BUFFER";
            case 0x8CDD: "FRAMEBUFFER_UNSUPPORTED";
            case 0x8D56: "FRAMEBUFFER_INCOMPLETE_MULTISAMPLE";
            default: "UNKNOWN_STATUS_" + status;
        };
    }

    private function disposeFramebufferAttachments(framebuffer:Framebuffer):Void {
        for (attachment in framebuffer.textures) {
            var textures = [attachment.texture.id];
            GL.deleteTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", textures));
        }
        framebuffer.textures = [];
        if (framebuffer.depthRenderbuffer != 0) {
            var renderbuffers = [framebuffer.depthRenderbuffer];
            GL.deleteRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", renderbuffers));
            framebuffer.depthRenderbuffer = 0;
        }
    }

    private function disposeFramebufferResources(framebuffer:Framebuffer, deleteFramebuffer:Bool):Void {
        disposeFramebufferAttachments(framebuffer);
        if (deleteFramebuffer && framebuffer.fbo != 0) {
            var framebuffers = [framebuffer.fbo];
            GL.deleteFramebuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", framebuffers));
            framebuffer.fbo = 0;
        }
    }

    public function bindFramebuffer(frameBufferId:Int):Void {
        var framebuffer = getFramebufferOrThrow(frameBufferId);
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer.fbo);
        setViewport(framebuffer.width, framebuffer.height);
        __framebufferStack.push(frameBufferId);
	}
	
	public function unbindFramebuffer(frameBufferId:Int):Void {
        if (__framebufferStack.length == 0
            || __framebufferStack[__framebufferStack.length - 1] != frameBufferId) {
            throw "Framebuffer " + frameBufferId + " is not the active render target";
        }

        var previousFramebuffer:Framebuffer = null;
        if (__framebufferStack.length > 1) {
            previousFramebuffer = framebuffers.get(__framebufferStack[__framebufferStack.length - 2]);
            if (previousFramebuffer == null) {
                throw "Active framebuffer no longer exists";
            }
        }

        __framebufferStack.pop();
        if (previousFramebuffer != null) {
            GL.bindFramebuffer(GL.FRAMEBUFFER, previousFramebuffer.fbo);
            setViewport(previousFramebuffer.width, previousFramebuffer.height);
        } else {
            GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
            var size = app.window.getWindowSizeInPixels();
            setViewport(size.width, size.height);
        }
	}
	
    public function disposeFramebuffer(frameBufferId:Int):Void {
        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer == null) {
            throw "Framebuffer with ID " + frameBufferId + " not found";
        }
        if (__framebufferStack.indexOf(frameBufferId) >= 0) {
            throw "Cannot dispose framebuffer " + frameBufferId + " while it is bound";
        }
        disposeFramebufferResources(framebuffer, true);
        framebuffers.remove(frameBufferId);
    }

    // ===== VIEWPORT =====

    private function setViewport(width:Int, height:Int):Void {
        GL.viewport(0, 0, width, height);
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return; // Ignore degenerate resize (e.g. window minimised)
        if (__framebufferStack.length > 0) {
            var activeFramebuffer = framebuffers.get(__framebufferStack[__framebufferStack.length - 1]);
            if (activeFramebuffer == null) {
                throw "Active framebuffer no longer exists";
            }
            setViewport(activeFramebuffer.width, activeFramebuffer.height);
        } else {
            setViewport(width, height);
        }
        
        for (screenPass in __screenPasses) {
            screenPass.resize(this, width, height);
        }
    }

    // ===== ACCESSORS =====

    private function get_app():App {
        return __app;
    }

    private function get_frameCount():Int {
        return __frameCount;
    }
}