package;

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

class ScissorRect {
    public var x:Int;
    public var y:Int;
    public var width:Int;
    public var height:Int;

    public function new(x:Int = 0, y:Int = 0, width:Int = 0, height:Int = 0) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }
}

@:build(macros.ShaderRegistryMacro.build("shaders"))
class Renderer {
    
    // Publics
    public var app(get, null):App;
    public var frameCount(get, null):Int;
    public var diagnostics(get, null):RendererDiagnostics;
    public var scissorEnabled(get, null):Bool;
    public var scissorStackDepth(get, null):Int;
    public var matrix:Matrix = new Matrix();

    // Privates
    private var __app:App;
    private var __currentDepthTest:Bool = false;
    private var __currentDepthWrite:Bool = false;
    private var __currentBlendMode:Bool = false;
    private var __currentBlendSource:Int = -1;
    private var __currentBlendDestination:Int = -1;
    private var __activeFramebufferId:Int = -1;
    private var __frameCount:Int = 0;
    private var __diagnostics:RendererDiagnostics = new RendererDiagnostics();
    private var __scissorEnabled:Bool = false;
    private var __scissorRect:ScissorRect = new ScissorRect();
    private var __scissorStack:Array<ScissorRect> = [];
    private var __viewportWidth:Int = 0;
    private var __viewportHeight:Int = 0;
    private var __programInfos:Array<ProgramInfo> = new Array<ProgramInfo>();

    private var buffers:SlotArray<Buffers> = new SlotArray<Buffers>(32);
    private var framebuffers:SlotArray<Framebuffer> = new SlotArray<Framebuffer>(8);
    private var textures:Array<Texture> = [];

    private var currentProgram:Int = -1;
    private var currentVbo:Int = 0;
    private var currentEbo:Int = 0;
    
    // ===== LIFECYCLE =====

    public function new(app:App) {
        __app = app;
        var pixelSize = __app.window.getWindowSizeInPixels();
        __viewportWidth = pixelSize.width;
        __viewportHeight = pixelSize.height;

		for (definition in definitions) {
			var programInfo = createProgramInfo(definition.name, definition.vertexSource, definition.fragmentSource);
		}

        __app.log.info(LogCategory.RENDERER, "Renderer initialized with " + __programInfos.length + " shader programs");

        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(true);
    }
    
    public function render():Void {
        clearScissorStack();
        currentProgram = -1;
        currentVbo = 0;
        currentEbo = 0;
        __currentBlendSource = -1;
        __currentBlendDestination = -1;
        __frameCount++;
        __diagnostics.beginFrame();
    }

    public function release():Void {
        // Reset render state
        clearScissorStack();
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(false);

        if (__activeFramebufferId >= 0) {
            unbindFramebuffer(__activeFramebufferId);
        }

        for (framebuffer in framebuffers) {
            disposeFramebufferResources(framebuffer, true);
        }
        framebuffers.clear();

        for (buffer in buffers) {
            deleteBuffers(buffers.indexOf(buffer));
        }
        buffers.clear();

        for (texture in textures.copy()) {
            disposeTexture(texture);
        }

        for (programInfo in __programInfos) {
            programInfo.release(this);
        }
        __programInfos = [];

        __app.log.info(LogCategory.RENDERER, "Renderer cleanup complete");
    }

    // ===== PROGRAMS AND DRAWING =====

    public function useProgram(programInfo:ProgramInfo):Void {
        if (programInfo.program != currentProgram) {
            GL.useProgram(programInfo.program);
            GL.bindVertexArray(programInfo.vao);
            currentProgram = programInfo.program;
            currentVbo = 0;
            currentEbo = 0;
            if (__diagnostics.enabled) __diagnostics.programChanges++;
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
				__app.log.warn(LogCategory.RENDERER, "Uniform '" + uniform.name + "' doesn't exist in shader");
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
        if (__diagnostics.enabled) {
            __diagnostics.drawCalls++;
            __diagnostics.drawElementsCalls++;
            __diagnostics.indicesSubmitted += count;
            __diagnostics.trianglesSubmitted += Std.int(count / 3);
            __diagnostics.cumulativeDrawCalls++;
        }
    }

    public function drawArrays(mode:Int, first:Int, count:Int):Void {
        GL.drawArrays(mode, first, count);
        if (__diagnostics.enabled) {
            __diagnostics.drawCalls++;
            __diagnostics.drawArraysCalls++;
            __diagnostics.verticesSubmitted += count;
            __diagnostics.trianglesSubmitted += Std.int(count / 3);
            __diagnostics.cumulativeDrawCalls++;
        }
    }

    public function createProgramInfo(name:String, vertexSource:String, fragmentSource:String):ProgramInfo {
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

        var programInfo = new ProgramInfo(
            name,
            program,
            vao,
            introspection.attributes,
            introspection.uniforms,
            introspection.vertexStride
        );
        initializeSamplerUnits(programInfo);

        __app.log.info(LogCategory.RENDERER, "Created and registered ProgramInfo: " + name);

        __programInfos.push(programInfo);
        __diagnostics.livePrograms++;

        return programInfo;
    }

    private function initializeSamplerUnits(programInfo:ProgramInfo):Void {
        GL.useProgram(programInfo.program);
        for (uniform in programInfo.uniformInfos) {
            if (uniform != null && uniform.textureUnit != null && uniform.location != null) {
                GL.uniform1i(uniform.location, uniform.textureUnit);
            }
        }
        GL.useProgram(0);
        currentProgram = -1;
        currentVbo = 0;
        currentEbo = 0;
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
        if (__diagnostics.enabled) __diagnostics.textureBindings++;
    }

    public function disposeProgramInfo(programInfo:ProgramInfo):Void {
        if (programInfo.vao != 0) {
            var vaos = [programInfo.vao];
            GL.deleteVertexArrays(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vaos));
        }
        if (programInfo.program != 0) {
            GL.deleteProgram(programInfo.program);
            if (__diagnostics.livePrograms > 0) __diagnostics.livePrograms--;
        }
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
        if (__diagnostics.enabled) __diagnostics.bufferBindings++;
	}

    public function createBuffers(programInfoIndex:Int):Int {
        if (programInfoIndex < 0 || programInfoIndex >= __programInfos.length) {
            throw "ProgramInfo index out of range: " + programInfoIndex;
        }

        var vbo:UInt32 = 0;
        var ebo:UInt32 = 0;

        GL.genBuffers(1, RawPointer.addressOf(vbo));
        GL.genBuffers(1, RawPointer.addressOf(ebo));

        var bufferId = buffers.add(new Buffers(vbo, ebo, __programInfos[programInfoIndex]));
        __diagnostics.liveBuffers++;
        return bufferId;
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
        if (__diagnostics.enabled) {
            __diagnostics.bufferUploads++;
            __diagnostics.uploadedVertexBytes += vertices.length * 4;
            __diagnostics.uploadedIndexBytes += indices.length * 4;
            __diagnostics.cumulativeBufferUploads++;
        }
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
        if (__diagnostics.enabled) {
            __diagnostics.bufferUploads++;
            __diagnostics.orphanUploads++;
            __diagnostics.uploadedVertexBytes += vertices.length * 4;
            __diagnostics.uploadedIndexBytes += indices.length * 4;
            __diagnostics.cumulativeBufferUploads++;
            __diagnostics.cumulativeOrphanUploads++;
        }
    }

    public function deleteBuffers(bufferId:Int):Void {
        var buffersObj = buffers.get(bufferId);
        if (buffersObj == null) return;

        GL.deleteBuffers(1, RawPointer.addressOf(buffersObj.vbo));
        GL.deleteBuffers(1, RawPointer.addressOf(buffersObj.ebo));

        buffers.remove(bufferId);
        if (__diagnostics.liveBuffers > 0) __diagnostics.liveBuffers--;
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
        textures.push(texture);
        __diagnostics.liveTextures = textures.length;
        
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

        var texture:Texture = {
            id: textureId,
            width: width,
            height: height,
            bpp: (format == GL.RGBA ? 4 : 1),
            target: GL.TEXTURE_2D,
            src: ""
        };
        textures.push(texture);
        __diagnostics.liveTextures = textures.length;
        return texture;
    }

    public function disposeTexture(texture:Texture):Void {
        if (texture == null) return;

        var textureId = texture.id;
        var found = false;
        for (i in 0...textures.length) {
            if (textures[i].id == textureId) {
                textures.splice(i, 1);
                found = true;
                break;
            }
        }

        if (found) {
            var textureIds = [textureId];
            GL.deleteTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", textureIds));
        }
        __diagnostics.liveTextures = textures.length;
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
            if (__diagnostics.enabled) __diagnostics.renderStateChanges++;
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
            if (__diagnostics.enabled) __diagnostics.renderStateChanges++;
        }
    }
    
    public function setDepthWrite(enabled:Bool):Void {
        if (__currentDepthWrite != enabled) {
            GL.glDepthMask(enabled);
            __currentDepthWrite = enabled;
            if (__diagnostics.enabled) __diagnostics.renderStateChanges++;
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
            if (__diagnostics.enabled) __diagnostics.renderStateChanges++;
        }
    }

    // ===== SCISSOR CLIPPING =====

    /**
     * Sets a top-left-origin rectangular clip in current render-target pixels.
     * Push the current clip before nested/intersected clipping and pop it afterward.
     */
    public function setScissor(x:Int, y:Int, width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) {
            disableScissor();
            return;
        }

        var clamped = clampScissor(new ScissorRect(x, y, width, height));
        if (clamped.width <= 0 || clamped.height <= 0) {
            disableScissor();
            return;
        }

        __scissorRect = clamped;
        __scissorEnabled = true;
        GL.glEnable(GL.SCISSOR_TEST);
        applyScissor(clamped);

        if (__diagnostics.enabled) {
            __diagnostics.scissorChanges++;
            __diagnostics.renderStateChanges++;
        }
    }

    public function pushScissor(x:Int, y:Int, width:Int, height:Int):Void {
        __scissorStack.push(copyScissor(__scissorEnabled ? __scissorRect : null));

        if (!__scissorEnabled) {
            setScissor(x, y, width, height);
            return;
        }

        var current = __scissorRect;
        var x1 = current.x > x ? current.x : x;
        var y1 = current.y > y ? current.y : y;
        var x2 = (current.x + current.width) < (x + width)
            ? current.x + current.width : x + width;
        var y2 = (current.y + current.height) < (y + height)
            ? current.y + current.height : y + height;

        if (x2 <= x1 || y2 <= y1) {
            setScissor(x1, y1, 0, 0);
        } else {
            setScissor(x1, y1, x2 - x1, y2 - y1);
        }
    }

    public function popScissor():Bool {
        if (__scissorStack.length == 0) return false;

        var previous = __scissorStack.pop();
        if (previous == null) {
            disableScissor();
        } else {
            setScissor(previous.x, previous.y, previous.width, previous.height);
        }
        return true;
    }

    public function disableScissor():Void {
        if (__scissorEnabled) {
            __scissorEnabled = false;
            GL.glDisable(GL.SCISSOR_TEST);
            if (__diagnostics.enabled) {
                __diagnostics.scissorChanges++;
                __diagnostics.renderStateChanges++;
            }
        }
    }

    public function clearScissorStack():Void {
        __scissorStack = [];
        disableScissor();
    }

    private function applyScissor(rect:ScissorRect):Void {
        var glY = __viewportHeight - (rect.y + rect.height);
        GL.scissor(rect.x, glY, rect.width, rect.height);
    }

    private function clampScissor(rect:ScissorRect):ScissorRect {
        var x1 = rect.x < 0 ? 0 : rect.x;
        var y1 = rect.y < 0 ? 0 : rect.y;
        var x2 = rect.x + rect.width;
        var y2 = rect.y + rect.height;

        if (x2 > __viewportWidth) x2 = __viewportWidth;
        if (y2 > __viewportHeight) y2 = __viewportHeight;

        if (x2 <= x1 || y2 <= y1) {
            return new ScissorRect();
        }
        return new ScissorRect(x1, y1, x2 - x1, y2 - y1);
    }

    private function copyScissor(rect:Null<ScissorRect>):Null<ScissorRect> {
        if (rect == null) return null;
        return new ScissorRect(rect.x, rect.y, rect.width, rect.height);
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
        var framebufferId = framebuffers.add(framebuffer);
        __diagnostics.liveFramebuffers++;
        return framebufferId;
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
        if (__activeFramebufferId == frameBufferId) {
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
        var framebuffer = __activeFramebufferId >= 0
            ? framebuffers.get(__activeFramebufferId)
            : null;
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
            disposeTexture(attachment.texture);
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
            if (__diagnostics.liveFramebuffers > 0) __diagnostics.liveFramebuffers--;
        }
    }

    public function bindFramebuffer(frameBufferId:Int):Void {
        if (__activeFramebufferId >= 0) {
            throw "Cannot bind framebuffer " + frameBufferId
                + " while framebuffer " + __activeFramebufferId + " is active";
        }

        var framebuffer = getFramebufferOrThrow(frameBufferId);
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer.fbo);
        setViewport(framebuffer.width, framebuffer.height);
        __activeFramebufferId = frameBufferId;
        if (__diagnostics.enabled) __diagnostics.framebufferBindings++;
	}
	
	public function unbindFramebuffer(frameBufferId:Int):Void {
        if (__activeFramebufferId != frameBufferId) {
            throw "Framebuffer " + frameBufferId + " is not the active render target";
        }

        __activeFramebufferId = -1;
        GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
        var size = app.window.getWindowSizeInPixels();
        setViewport(size.width, size.height);
        if (__diagnostics.enabled) __diagnostics.framebufferBindings++;
	}
	
    public function disposeFramebuffer(frameBufferId:Int):Void {
        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer == null) {
            throw "Framebuffer with ID " + frameBufferId + " not found";
        }
        if (__activeFramebufferId == frameBufferId) {
            throw "Cannot dispose framebuffer " + frameBufferId + " while it is bound";
        }
        disposeFramebufferResources(framebuffer, true);
        framebuffers.remove(frameBufferId);
    }

    // ===== VIEWPORT =====

    private function setViewport(width:Int, height:Int):Void {
        __viewportWidth = width;
        __viewportHeight = height;
        GL.viewport(0, 0, width, height);
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return; // Ignore degenerate resize (e.g. window minimised)
        if (__activeFramebufferId >= 0) {
            var activeFramebuffer = framebuffers.get(__activeFramebufferId);
            if (activeFramebuffer == null) {
                throw "Active framebuffer no longer exists";
            }
            setViewport(activeFramebuffer.width, activeFramebuffer.height);
        } else {
            setViewport(width, height);
        }
    }

    // Setters and getters
    private function get_app():App {
        return __app;
    }

    private function get_frameCount():Int {
        return __frameCount;
    }

    private function get_scissorEnabled():Bool {
        return __scissorEnabled;
    }

    private function get_scissorStackDepth():Int {
        return __scissorStack.length;
    }

    private function get_diagnostics():RendererDiagnostics {
        return __diagnostics;
    }
}

class RendererDiagnostics {
    public var enabled(default, set):Bool = false;
    public var frameCount:Int = 0;
    public var drawCalls:Int = 0;
    public var drawElementsCalls:Int = 0;
    public var drawArraysCalls:Int = 0;
    public var indicesSubmitted:Int = 0;
    public var trianglesSubmitted:Int = 0;
    public var verticesSubmitted:Int = 0;
    public var bufferUploads:Int = 0;
    public var orphanUploads:Int = 0;
    public var uploadedVertexBytes:Int = 0;
    public var uploadedIndexBytes:Int = 0;
    public var programChanges:Int = 0;
    public var bufferBindings:Int = 0;
    public var textureBindings:Int = 0;
    public var framebufferBindings:Int = 0;
    public var renderStateChanges:Int = 0;
    public var scissorChanges:Int = 0;
    public var liveBuffers:Int = 0;
    public var livePrograms:Int = 0;
    public var liveFramebuffers:Int = 0;
    public var liveTextures:Int = 0;
    public var cumulativeDrawCalls:Int = 0;
    public var cumulativeBufferUploads:Int = 0;
    public var cumulativeOrphanUploads:Int = 0;

    public function new() {}

    public function beginFrame():Void {
        if (!enabled) return;
        frameCount++;
        drawCalls = 0;
        drawElementsCalls = 0;
        drawArraysCalls = 0;
        indicesSubmitted = 0;
        trianglesSubmitted = 0;
        verticesSubmitted = 0;
        bufferUploads = 0;
        orphanUploads = 0;
        uploadedVertexBytes = 0;
        uploadedIndexBytes = 0;
        programChanges = 0;
        bufferBindings = 0;
        textureBindings = 0;
        framebufferBindings = 0;
        renderStateChanges = 0;
        scissorChanges = 0;
    }

    public function resetCumulative():Void {
        cumulativeDrawCalls = 0;
        cumulativeBufferUploads = 0;
        cumulativeOrphanUploads = 0;
    }

    public function toString():String {
        return "drawCalls=" + drawCalls
            + " elements=" + drawElementsCalls
            + " arrays=" + drawArraysCalls
            + " triangles=" + trianglesSubmitted
            + " uploads=" + bufferUploads
            + " orphanUploads=" + orphanUploads
            + " scissorChanges=" + scissorChanges
            + " programs=" + livePrograms
            + " buffers=" + liveBuffers
            + " textures=" + liveTextures
            + " framebuffers=" + liveFramebuffers;
    }

    private function set_enabled(value:Bool):Bool {
        enabled = value;
        if (!enabled) {
            beginFrame();
        }
        return enabled;
    }
}