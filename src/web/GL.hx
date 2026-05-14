package web;

#if js
import js.html.webgl.WebGL2RenderingContext as RenderingContext;
import js.lib.Float32Array;
import js.lib.Uint32Array;
import js.lib.Uint8Array;

/**
 * WebGL2 wrapper that mirrors the native GL extern class.
 * Uses integer ID registries to map OpenGL-style integer handles to JS WebGL objects,
 * so DisplayObject.vbo/ebo and ProgramInfo.vao remain plain Int types on both targets.
 */
class GL {

    // ** The underlying WebGL2 context — set once during Runtime.init()
    public static var context:RenderingContext;

    // -------------------------------------------------------------------------
    // Internal handle registries (Int ID → WebGL object)
    // -------------------------------------------------------------------------

    private static var __buffers:Map<Int, js.html.webgl.Buffer>               = new Map();
    private static var __textures:Map<Int, js.html.webgl.Texture>             = new Map();
    private static var __vaos:Map<Int, js.html.webgl.VertexArrayObject>       = new Map();
    private static var __programs:Map<Int, js.html.webgl.Program>             = new Map();
    private static var __shaders:Map<Int, js.html.webgl.Shader>               = new Map();
    private static var __uniformLocations:Map<Int, js.html.webgl.UniformLocation> = new Map();
    private static var __framebuffers:Map<Int, js.html.webgl.Framebuffer>     = new Map();
    private static var __renderbuffers:Map<Int, js.html.webgl.Renderbuffer>   = new Map();

    private static var __nextId:Int = 1;
    private static inline function nextId():Int { return __nextId++; }

    // -------------------------------------------------------------------------
    // OpenGL constants (matching native enum values)
    // -------------------------------------------------------------------------

    // Shader types
    public static var VERTEX_SHADER:Int   = 35633; // 0x8B31
    public static var FRAGMENT_SHADER:Int = 35632; // 0x8B30

    // Buffer targets
    public static var ARRAY_BUFFER:Int         = 34962; // 0x8892
    public static var ELEMENT_ARRAY_BUFFER:Int = 34963; // 0x8893

    // Buffer usage hints
    public static var STATIC_DRAW:Int  = 35044; // 0x88B4
    public static var DYNAMIC_DRAW:Int = 35048; // 0x88B8
    public static var STREAM_DRAW:Int  = 35040; // 0x88B0

    // Draw modes
    public static var POINTS:Int         = 0;
    public static var LINES:Int          = 1;
    public static var LINE_STRIP:Int     = 3;
    public static var TRIANGLES:Int      = 4;
    public static var TRIANGLE_STRIP:Int = 5;
    public static var TRIANGLE_FAN:Int   = 6;

    // Data types
    public static var BYTE:Int           = 5120; // 0x1400
    public static var UNSIGNED_BYTE:Int  = 5121; // 0x1401
    public static var SHORT:Int          = 5122; // 0x1402
    public static var UNSIGNED_SHORT:Int = 5123; // 0x1403
    public static var INT:Int            = 5124; // 0x1404
    public static var UNSIGNED_INT:Int   = 5125; // 0x1405
    public static var FLOAT:Int          = 5126; // 0x1406

    // Texture targets & units
    public static var TEXTURE_2D:Int   = 3553;  // 0x0DE1
    public static var TEXTURE0:Int     = 33984; // 0x84C0

    // Texture parameters
    public static var TEXTURE_WRAP_S:Int   = 10242; // 0x2802
    public static var TEXTURE_WRAP_T:Int   = 10243; // 0x2803
    public static var TEXTURE_MIN_FILTER:Int = 10241; // 0x2801
    public static var TEXTURE_MAG_FILTER:Int = 10240; // 0x2800
    public static var CLAMP_TO_EDGE:Int    = 33071; // 0x812F
    public static var REPEAT:Int           = 10497; // 0x2901
    public static var LINEAR:Int           = 9729;  // 0x2601
    public static var NEAREST:Int          = 9728;  // 0x2600
    public static var LINEAR_MIPMAP_LINEAR:Int = 9987; // 0x2703

    // Pixel formats (base/unsized — use as 'format' parameter)
    public static var RED:Int  = 6403; // 0x1903
    public static var RG:Int   = 33319; // 0x8227
    public static var RGB:Int  = 6407; // 0x1907
    public static var RGBA:Int = 6408; // 0x1908
    public static var DEPTH_COMPONENT:Int = 6402; // 0x1902

    // Sized internal formats — required by WebGL2 as 'internalformat' parameter
    public static var R8:Int   = 33321; // 0x8229
    public static var RG8:Int  = 33323; // 0x822B
    public static var RGB8:Int = 32849; // 0x8051
    public static var RGBA8:Int = 32856; // 0x8058

    // Clear flags
    public static var COLOR_BUFFER_BIT:Int = 16384; // 0x4000
    public static var DEPTH_BUFFER_BIT:Int = 256;   // 0x0100

    // Render state
    public static var DEPTH_TEST:Int = 2929; // 0x0B71
    public static var CULL_FACE:Int  = 2884; // 0x0B44
    public static var BLEND:Int      = 3042; // 0x0BE2

    // Blend factors
    public static var ZERO:Int                     = 0;
    public static var ONE:Int                      = 1;
    public static var SRC_ALPHA:Int                = 770;  // 0x0302
    public static var ONE_MINUS_SRC_ALPHA:Int      = 771;  // 0x0303
    public static var SRC_COLOR:Int                = 768;  // 0x0300
    public static var ONE_MINUS_SRC_COLOR:Int      = 769;  // 0x0301
    public static var DST_ALPHA:Int                = 772;
    public static var ONE_MINUS_DST_ALPHA:Int      = 773;

    // Shader/program status
    public static var COMPILE_STATUS:Int = 35713; // 0x8B81
    public static var LINK_STATUS:Int    = 35714; // 0x8B82

    // Program introspection
    public static var ACTIVE_ATTRIBUTES:Int = 35721; // 0x8B89
    public static var ACTIVE_UNIFORMS:Int   = 35718; // 0x8B86

    // Framebuffer
    public static var FRAMEBUFFER:Int           = 36160; // 0x8D40
    public static var COLOR_ATTACHMENT0:Int     = 36064; // 0x8CE0
    public static var DEPTH_ATTACHMENT:Int      = 36096; // 0x8D00
    public static var RENDERBUFFER:Int          = 36161; // 0x8D41
    public static var DEPTH_COMPONENT16:Int     = 33189; // 0x81A5
    public static var DEPTH_COMPONENT24:Int     = 33190; // 0x81A6
    public static var FRAMEBUFFER_COMPLETE:Int  = 36053; // 0x8CD5

    // -------------------------------------------------------------------------
    // Shader compilation
    // -------------------------------------------------------------------------

    public static function createShader(type:Int):Int {
        var shader = context.createShader(type);
        var id = nextId();
        __shaders.set(id, shader);
        return id;
    }

    public static function shaderSource(shader:Int, source:String):Void {
        context.shaderSource(__shaders.get(shader), source);
    }

    public static function compileShader(shader:Int):Void {
        context.compileShader(__shaders.get(shader));
    }

    public static function getShaderParameterValue(shader:Int, pname:Int):Int {
        var result:Dynamic = context.getShaderParameter(__shaders.get(shader), pname);
        return (result == true) ? 1 : 0;
    }

    public static function getShaderInfoLogString(shader:Int):String {
        var log = context.getShaderInfoLog(__shaders.get(shader));
        return log != null ? log : "";
    }

    public static function deleteShader(shader:Int):Void {
        context.deleteShader(__shaders.get(shader));
        __shaders.remove(shader);
    }

    // -------------------------------------------------------------------------
    // Program linking
    // -------------------------------------------------------------------------

    public static function createProgram():Int {
        var program = context.createProgram();
        var id = nextId();
        __programs.set(id, program);
        return id;
    }

    public static function attachShader(program:Int, shader:Int):Void {
        context.attachShader(__programs.get(program), __shaders.get(shader));
    }

    public static function linkProgram(program:Int):Void {
        context.linkProgram(__programs.get(program));
    }

    public static function useProgram(program:Int):Void {
        context.useProgram(program == 0 ? null : __programs.get(program));
    }

    public static function getProgramParameterValue(program:Int, pname:Int):Int {
        var result:Dynamic = context.getProgramParameter(__programs.get(program), pname);
        return (result == true) ? 1 : 0;
    }

    public static function getProgramInfoLogString(program:Int):String {
        var log = context.getProgramInfoLog(__programs.get(program));
        return log != null ? log : "";
    }

    public static function deleteProgram(program:Int):Void {
        context.deleteProgram(__programs.get(program));
        __programs.remove(program);
    }

    // -------------------------------------------------------------------------
    // Vertex attributes
    // -------------------------------------------------------------------------

    public static function getAttribLocation(program:Int, name:String):Int {
        return context.getAttribLocation(__programs.get(program), name);
    }

    public static function enableVertexAttribArray(index:Int):Void {
        context.enableVertexAttribArray(index);
    }

    public static function disableVertexAttribArray(index:Int):Void {
        context.disableVertexAttribArray(index);
    }

    public static function vertexAttribPointer(index:Int, size:Int, type:Int, normalized:Bool, stride:Int, offset:Int):Void {
        context.vertexAttribPointer(index, size, type, normalized, stride, offset);
    }

    // -------------------------------------------------------------------------
    // Uniforms
    // -------------------------------------------------------------------------

    public static function getUniformLocation(program:Int, name:String):Int {
        var loc = context.getUniformLocation(__programs.get(program), name);
        if (loc == null) return -1;
        var id = nextId();
        __uniformLocations.set(id, loc);
        return id;
    }

    public static function uniform1f(location:Int, v0:Float):Void {
        if (location < 0) return;
        context.uniform1f(__uniformLocations.get(location), v0);
    }

    public static function uniform1i(location:Int, v0:Int):Void {
        if (location < 0) return;
        context.uniform1i(__uniformLocations.get(location), v0);
    }

    public static function uniform2f(location:Int, v0:Float, v1:Float):Void {
        if (location < 0) return;
        context.uniform2f(__uniformLocations.get(location), v0, v1);
    }

    public static function uniform3f(location:Int, v0:Float, v1:Float, v2:Float):Void {
        if (location < 0) return;
        context.uniform3f(__uniformLocations.get(location), v0, v1, v2);
    }

    public static function uniform4f(location:Int, v0:Float, v1:Float, v2:Float, v3:Float):Void {
        if (location < 0) return;
        context.uniform4f(__uniformLocations.get(location), v0, v1, v2, v3);
    }

    public static function uniform2i(location:Int, v0:Int, v1:Int):Void {
        if (location < 0) return;
        context.uniform2i(__uniformLocations.get(location), v0, v1);
    }

    public static function uniform3i(location:Int, v0:Int, v1:Int, v2:Int):Void {
        if (location < 0) return;
        context.uniform3i(__uniformLocations.get(location), v0, v1, v2);
    }

    public static function uniform4i(location:Int, v0:Int, v1:Int, v2:Int, v3:Int):Void {
        if (location < 0) return;
        context.uniform4i(__uniformLocations.get(location), v0, v1, v2, v3);
    }

    public static function uniformMatrix2fv(location:Int, transpose:Bool, data:Array<Float>):Void {
        if (location < 0) return;
        context.uniformMatrix2fv(__uniformLocations.get(location), transpose, new Float32Array(data));
    }

    public static function uniformMatrix3fv(location:Int, transpose:Bool, data:Array<Float>):Void {
        if (location < 0) return;
        context.uniformMatrix3fv(__uniformLocations.get(location), transpose, new Float32Array(data));
    }

    public static function uniformMatrix4fv(location:Int, transpose:Bool, data:Array<Float>):Void {
        if (location < 0) return;
        context.uniformMatrix4fv(__uniformLocations.get(location), transpose, new Float32Array(data));
    }

    // -------------------------------------------------------------------------
    // Buffers
    // -------------------------------------------------------------------------

    public static function createBuffer():Int {
        var buf = context.createBuffer();
        var id = nextId();
        __buffers.set(id, buf);
        return id;
    }

    /** Compatibility shim — ignores n, fills id in-place is not possible in JS;
        callers in web Renderer should use createBuffer() directly. */
    public static function genBuffers(n:Int, id:Int):Void {
        // No-op shim; web Renderer uses createBuffer() instead
    }

    public static function bindBuffer(target:Int, id:Int):Void {
        context.bindBuffer(target, id == 0 ? null : __buffers.get(id));
    }

    public static function bufferFloatArray(target:Int, data:Array<Float>, usage:Int, length:Int):Void {
        context.bufferData(target, new Float32Array(data), usage);
    }

    public static function bufferUIntArray(target:Int, data:Array<UInt>, usage:Int, length:Int):Void {
        context.bufferData(target, new Uint32Array(cast data), usage);
    }

    public static function bufferSubFloatArray(target:Int, offset:Int, data:Array<Float>, length:Int):Void {
        context.bufferSubData(target, offset, new Float32Array(data));
    }

    public static function deleteBuffers(n:Int, id:Int):Void {
        var buf = __buffers.get(id);
        if (buf != null) {
            context.deleteBuffer(buf);
            __buffers.remove(id);
        }
    }

    // -------------------------------------------------------------------------
    // Vertex Array Objects
    // -------------------------------------------------------------------------

    public static function createVertexArray():Int {
        var vao = context.createVertexArray();
        var id = nextId();
        __vaos.set(id, vao);
        return id;
    }

    public static function bindVertexArray(id:Int):Void {
        context.bindVertexArray(id == 0 ? null : __vaos.get(id));
    }

    public static function deleteVertexArray(id:Int):Void {
        var vao = __vaos.get(id);
        if (vao != null) {
            context.deleteVertexArray(vao);
            __vaos.remove(id);
        }
    }

    // -------------------------------------------------------------------------
    // Draw calls
    // -------------------------------------------------------------------------

    public static function drawArrays(mode:Int, first:Int, count:Int):Void {
        context.drawArrays(mode, first, count);
    }

    public static function drawElements(mode:Int, count:Int, type:Int, offset:Int):Void {
        context.drawElements(mode, count, type, offset);
    }

    // -------------------------------------------------------------------------
    // Viewport and render state
    // -------------------------------------------------------------------------

    public static function viewport(x:Int, y:Int, width:Int, height:Int):Void {
        context.viewport(x, y, width, height);
    }

    /** Alias used by native Renderer — routes to viewport() */
    public static function glViewport(x:Int, y:Int, width:Int, height:Int):Void {
        context.viewport(x, y, width, height);
    }

    public static function glClearColor(r:Float, g:Float, b:Float, a:Float):Void {
        context.clearColor(r, g, b, a);
    }

    public static function glClear(mask:Int):Void {
        context.clear(mask);
    }

    public static function glEnable(cap:Int):Void {
        context.enable(cap);
    }

    public static function glDisable(cap:Int):Void {
        context.disable(cap);
    }

    public static function blendFunc(sfactor:Int, dfactor:Int):Void {
        context.blendFunc(sfactor, dfactor);
    }

    // -------------------------------------------------------------------------
    // Textures
    // -------------------------------------------------------------------------

    public static function createTexture():Int {
        var tex = context.createTexture();
        var id = nextId();
        __textures.set(id, tex);
        return id;
    }

    /** Shim for genTextures — web Renderer must use createTexture() instead */
    public static function genTextures(n:Int, id:Int):Void {
        // No-op shim
    }

    public static function bindTexture(target:Int, id:Int):Void {
        context.bindTexture(target, id == 0 ? null : __textures.get(id));
    }

    public static function activeTexture(texture:Int):Void {
        context.activeTexture(texture);
    }

    public static function texParameteri(target:Int, pname:Int, param:Int):Void {
        context.texParameteri(target, pname, param);
    }

    public static function texImage2D(target:Int, level:Int, internalFormat:Int, width:Int, height:Int, border:Int, format:Int, type:Int, data:Dynamic):Void {
        context.texImage2D(target, level, internalFormat, width, height, border, format, type, data);
    }

    public static function generateMipmap(target:Int):Void {
        context.generateMipmap(target);
    }

    public static function deleteTexture(id:Int):Void {
        var tex = __textures.get(id);
        if (tex != null) {
            context.deleteTexture(tex);
            __textures.remove(id);
        }
    }

    /** Plural shim — deletes the single texture referenced by id. */
    public static function deleteTextures(n:Int, id:Int):Void {
        deleteTexture(id);
    }

    // -------------------------------------------------------------------------
    // Framebuffers
    // -------------------------------------------------------------------------

    public static function createFramebuffer():Int {
        var fb = context.createFramebuffer();
        var id = nextId();
        __framebuffers.set(id, fb);
        return id;
    }

    public static function bindFramebuffer(target:Int, id:Int):Void {
        context.bindFramebuffer(target, id == 0 ? null : __framebuffers.get(id));
    }

    public static function framebufferTexture2D(target:Int, attachment:Int, textarget:Int, textureId:Int, level:Int):Void {
        context.framebufferTexture2D(target, attachment, textarget, __textures.get(textureId), level);
    }

    public static function createRenderbuffer():Int {
        var rb = context.createRenderbuffer();
        var id = nextId();
        __renderbuffers.set(id, rb);
        return id;
    }

    public static function bindRenderbuffer(target:Int, id:Int):Void {
        context.bindRenderbuffer(target, id == 0 ? null : __renderbuffers.get(id));
    }

    public static function renderbufferStorage(target:Int, internalFormat:Int, width:Int, height:Int):Void {
        context.renderbufferStorage(target, internalFormat, width, height);
    }

    public static function framebufferRenderbuffer(target:Int, attachment:Int, renderbuffertarget:Int, renderbufferId:Int):Void {
        context.framebufferRenderbuffer(target, attachment, renderbuffertarget, __renderbuffers.get(renderbufferId));
    }

    public static function deleteFramebuffer(id:Int):Void {
        var fb = __framebuffers.get(id);
        if (fb != null) {
            context.deleteFramebuffer(fb);
            __framebuffers.remove(id);
        }
    }

    /** Plural shim — deletes the single framebuffer referenced by id. */
    public static function deleteFramebuffers(n:Int, id:Int):Void {
        deleteFramebuffer(id);
    }

    /** WebGL2 genRenderbuffers shim — returns a new renderbuffer id. */
    public static function genRenderbuffers(n:Int, id:Int):Int {
        return createRenderbuffer();
    }

    /** Plural shim — deletes the single renderbuffer referenced by id. */
    public static function deleteRenderbuffers(n:Int, id:Int):Void {
        var rb = __renderbuffers.get(id);
        if (rb != null) {
            context.deleteRenderbuffer(rb);
            __renderbuffers.remove(id);
        }
    }

    public static function checkFramebufferStatus(target:Int):Int {
        return context.checkFramebufferStatus(target);
    }

    // -------------------------------------------------------------------------
    // Program introspection helpers (used by web ProgramInfo)
    // -------------------------------------------------------------------------

    public static function getProgramActiveAttributes(program:Int):Int {
        var result:Dynamic = context.getProgramParameter(__programs.get(program), RenderingContext.ACTIVE_ATTRIBUTES);
        return result != null ? Std.int(result) : 0;
    }

    public static function getProgramActiveUniforms(program:Int):Int {
        var result:Dynamic = context.getProgramParameter(__programs.get(program), RenderingContext.ACTIVE_UNIFORMS);
        return result != null ? Std.int(result) : 0;
    }

    /** Returns {name, size, type} for the attribute at index. */
    public static function getActiveAttrib(program:Int, index:Int):Dynamic {
        return context.getActiveAttrib(__programs.get(program), index);
    }

    /** Returns {name, size, type} for the uniform at index. */
    public static function getActiveUniform(program:Int, index:Int):Dynamic {
        return context.getActiveUniform(__programs.get(program), index);
    }
}
#end
