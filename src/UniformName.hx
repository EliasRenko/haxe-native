package;

import haxe.ds.StringMap;
import haxe.ds.IntMap;

/**
 * OPTIMIZATION LAYER:
 * Converts strings to unique integer IDs automatically.
 * Zero string-hashing overhead inside the 60FPS render loop.
 */
abstract UniformName(String) from String to String {
    private static var currentId:Int = 0;
    private static var stringToIdMap:StringMap<Int> = new StringMap<Int>();

    public var id(get, never):Int;

    private inline function get_id():Int {
        // This check only runs once per unique string name across the application lifetime
        if (!stringToIdMap.exists(this)) {
            stringToIdMap.set(this, currentId);
            currentId++;
        }
        return stringToIdMap.get(this);
    }

    // Allows you to get the raw string back when calling native WebGL/OpenGL APIs
    public inline function toString():String {
        return this;
    }
}

/**
 * UNIFORM DATA STRUCTURE:
 * Holds the native driver location and a type-specific uploading function.
 */
class ShaderUniform {
    public var location:Dynamic; // WebGLUniformLocation or Int (depending on platform)
    public var upload:(location:Dynamic, value:Dynamic) -> Void;

    public function new(location:Dynamic, upload:(Dynamic, Dynamic) -> Void) {
        this.location = location;
        this.upload = upload;
    }
}

/**
 * MAIN SHADER CLASS:
 * Manages program state, caches uniform locations, and updates values via fast Int IDs.
 */
class Shader {
    public var program:Dynamic; // Your compiled WebGLProgram / Native Program
    private var gl:Dynamic;      // Your active GL context reference
    
    // Fast O(1) integer map storing the uniforms active on this specific shader
    private var uniforms:IntMap<ShaderUniform>;

    public function new(glContext:Dynamic, glProgram:Dynamic) {
        this.gl = glContext;
        this.program = glProgram;
        this.uniforms = new IntMap<ShaderUniform>();
    }

    /**
     * Call this ONCE during shader initialization/linking to register your uniforms.
     * @param name The string name of the uniform (e.g., "u_time")
     * @param type A string or enum representing the type to bind the correct GL setter
     */
    public function registerUniform(name:UniformName, type:String):Void {
        // Casts UniformName back to a raw string for the native driver lookup
        var loc = gl.getUniformLocation(this.program, name.toString());
        
        if (loc == null) {
            trace('Warning: Uniform "${name.toString()}" not found or optimized out by GLSL compiler.');
            return;
        }

        // Assign the correct WebGL/OpenGL function pointer based on type
        var setter = resolveGLSetter(type);

        if (setter != null) {
            // Store using the fast, pre-cached abstract integer ID
            var uniform = new ShaderUniform(loc, setter);
            this.uniforms.set(name.id, uniform);
        }
    }

    /**
     * High-performance method to update uniform data inside your render loop.
     * Bypasses all string maps and evaluates instantly using the integer ID.
     */
    public inline function setUniform(name:UniformName, value:Dynamic):Void {
        var uniform = uniforms.get(name.id);
        if (uniform != null) {
            uniform.upload(uniform.location, value);
        }
    }

    /**
     * Binds the shader program to the active GL context.
     */
    public inline function bind():Void {
        gl.useProgram(this.program);
    }

    /**
     * Maps your type string to the appropriate context upload wrapper.
     * Customize this method to fit your specific engine's math objects (Matrix, Vector, etc.).
     */
    private function resolveGLSetter(type:String):(Dynamic, Dynamic) -> Void {
        return switch (type) {
            case "float": 
                function(loc, val) gl.uniform1f(loc, cast val);
            case "vec2":  
                function(loc, val) gl.uniform2f(loc, val.x, val.y);
            case "vec3":  
                function(loc, val) gl.uniform3f(loc, val.x, val.y, val.z);
            case "mat4":  
                function(loc, val) gl.uniformMatrix4fv(loc, false, val); // Assumes val is Float32Array
            case "sampler2D": 
                function(loc, val) gl.uniform1i(loc, cast val); // Texture slot ID
            default:
                trace('Error: Unsupported uniform type "${type}"');
                null;
        };
    }
}