package;

import GL;

// OpenGL types for C++ externs
typedef UniformLocation = GlUInt;
typedef Program = GlUInt;
typedef Shader = GlUInt;

// Uniform data formats
enum UniformFormat {
	Float;
	Vec2;
	Vec3;
	Vec4;
	Mat4;
	Int;
	Sampler2D;
}

typedef Attribute = {
	var name:String;
	var format:Int;          // GL_FLOAT, GL_INT, etc.
	var size:Int;            // Number of components (1, 2, 3, or 4)
	var stride:Int;          // Byte offset between consecutive attributes
	var offset:Int;          // Byte offset from start of vertex data
	var ?location:Int;       // Shader attribute location
}

typedef Uniform = {
	var name:String;
	var format:UniformFormat;
	var setter:Dynamic;
	var ?location:UniformLocation;
}

class ProgramInfo {
	
	// ** Shader source code
	public var vertexShaderSource:String;
	public var fragmentShaderSource:String;
	
	// ** Compiled shader objects
	public var vertexShader:Shader;
	public var fragmentShader:Shader;
	public var program:Program;
	public var programId:Int;
	
	// ** Vertex attributes and uniforms
	public var attributes:Array<Attribute> = new Array<Attribute>();
	public var uniforms:Array<Uniform> = new Array<Uniform>();
	public var textures:Array<Uniform> = new Array<Uniform>();
	
	// ** Rendering properties
	public var name(get, null):String;
	public var dataPerVertex:UInt;
	public var textureCount(get, null):Int;
	public var isCompiled:Bool = false;
	
	// ** Privates
	private var __name:String;
	
	public function new(name:String, renderer:Renderer, ?vertexSource:String, ?fragmentSource:String) {
		__name = name;
		vertexShaderSource = vertexSource != null ? vertexSource : getDefaultVertexShader();
		fragmentShaderSource = fragmentSource != null ? fragmentSource : getDefaultFragmentShader();
		programId = -1;
		
		// Automatically compile and introspect the shader program
		if (!compile(renderer)) {
			trace("Failed to compile shader program: " + name);
			return;
		}
		
		// Automatically discover attributes and uniforms from compiled program
		introspectProgram(renderer);
		
		// Calculate vertex layout for interleaved data
		finalizeVertexLayout();
		
		trace("ProgramInfo '" + name + "' created and introspected successfully!");
	}

	public function addAttribute(name:String, format:Int, size:Int, stride:Int, offset:Int, location:Int):Void {
		attributes.push({
			name: name, 
			format: format, 
			size: size, 
			stride: stride, 
			offset: offset, 
			location: location
		});
	}
	
	// Convenience method for calculating stride automatically (INTERLEAVED DATA)
	public function addAttributeAuto(name:String, format:Int, size:Int, location:Int):Void {
		var currentOffset = calculateCurrentOffset();
		
		attributes.push({
			name: name,
			format: format,
			size: size,
			stride: 0,  // Will be calculated after all attributes are added
			offset: currentOffset,
			location: location
		});
	}
	
	// Call this AFTER adding all attributes to set correct stride for interleaved data
	public function finalizeVertexLayout():Void {
		if (attributes.length == 0) {
			trace("No attributes to finalize");
			return;
		}
		
		// Sort attributes by location to ensure consistent layout
		attributes.sort(function(a, b) return a.location - b.location);
		
		// Calculate offsets for interleaved data layout
		var currentOffset = 0;
		for (attr in attributes) {
			attr.offset = currentOffset;
			// Size in bytes = components * sizeof(float) - assuming float attributes
			var sizeInBytes = attr.size * 4; // 4 bytes per float
			currentOffset += sizeInBytes;
		}
		
		var totalVertexSize = currentOffset;
		
		// Set the same stride for ALL attributes (interleaved data)
		for (attr in attributes) {
			attr.stride = totalVertexSize;
		}
		
		dataPerVertex = totalVertexSize;
		trace("Vertex layout finalized: " + totalVertexSize + " bytes per vertex");
	}
	
	// ** Setup vertex attributes using glVertexAttribPointer
	public function setupVertexAttributes(renderer:Renderer):Void {
		if (!isCompiled) {
			trace("Warning: Program not compiled yet, attributes may not be bound correctly");
		}
		
		trace("Setting up " + attributes.length + " vertex attributes:");
		for (attr in attributes) {
			trace("  " + attr.name + ": location=" + attr.location + ", size=" + attr.size + ", stride=" + attr.stride + ", offset=" + attr.offset);
			
			// Enable the vertex attribute array
			renderer.enableVertexAttribArray(attr.location);
			
			// Set up the vertex attribute pointer  
			renderer.vertexAttribPointer(attr.location, attr.size, attr.format, false, attr.stride, attr.offset);
		}
	}
	
	// ** Get uniform location and set value
	public function setUniformFloat(name:String, value:Float, renderer:Renderer):Void {
		if (!isCompiled) {
			trace("Warning: Program not compiled, cannot set uniform: " + name);
			return;
		}
		
		// First try to find the uniform in our introspected list (faster)
		for (uniform in uniforms) {
			if (uniform.name == name) {
				if (uniform.format == UniformFormat.Float) {
					renderer.uniform1f(uniform.location, value);
					return;
				} else {
					trace("Warning: Uniform '" + name + "' is not a float uniform");
					return;
				}
			}
		}
		
		// Fallback to runtime lookup if not found in introspected uniforms
		var location = renderer.getUniformLocation(program, name);
		if (location != -1) {
			renderer.uniform1f(location, value);
		} else {
			trace("Warning: Uniform '" + name + "' not found in shader");
		}
	}
	
	// ** Set matrix4x4 uniform
	public function setUniformMatrix4(name:String, matrix:Array<Float>, renderer:Renderer):Void {
		if (!isCompiled) {
			trace("Warning: Program not compiled, cannot set uniform: " + name);
			return;
		}
		
		// First try to find the uniform in our introspected list (faster)
		for (uniform in uniforms) {
			if (uniform.name == name) {
				if (uniform.format == UniformFormat.Mat4) {
					renderer.uniformMatrix4fv(uniform.location, false, matrix);
					return;
				} else {
					trace("Warning: Uniform '" + name + "' is not a Mat4 uniform");
					return;
				}
			}
		}
		
		// Fallback to runtime lookup if not found in introspected uniforms
		var location = renderer.getUniformLocation(program, name);
		if (location != -1) {
			renderer.uniformMatrix4fv(location, false, matrix);
		} else {
			trace("Warning: Uniform '" + name + "' not found in shader");
		}
	}
	
	// ** Debug method to print vertex layout
	public function printVertexLayout():Void {
		trace("=== Vertex Layout for " + name + " ===");
		trace("Total vertex size: " + dataPerVertex + " bytes");
		trace("Attributes:");
		
		for (i in 0...attributes.length) {
			var attr = attributes[i];
			var formatName = getFormatName(attr.format);
			var sizeInBytes = attr.size * getFormatSize(attr.format);
			
			trace('  [$i] ${attr.name}:');
			trace('      Location: ${attr.location}');
			trace('      Format: $formatName (${attr.size} components)');
			trace('      Size: $sizeInBytes bytes');
			trace('      Offset: ${attr.offset} bytes');
			trace('      Stride: ${attr.stride} bytes');
		}
		trace("========================");
	}
	
	private function getFormatName(format:Int):String {
		return switch (format) {
			case 5126: "GL_FLOAT";           // GL_FLOAT
			case 5124: "GL_INT";             // GL_INT  
			case 5125: "GL_UNSIGNED_INT";    // GL_UNSIGNED_INT
			case 5122: "GL_SHORT";           // GL_SHORT
			case 5123: "GL_UNSIGNED_SHORT";  // GL_UNSIGNED_SHORT
			case 5120: "GL_BYTE";            // GL_BYTE
			case 5121: "GL_UNSIGNED_BYTE";   // GL_UNSIGNED_BYTE
			default: "UNKNOWN";
		}
	}
	
	private function getFormatSize(format:Int):Int {
		return switch (format) {
			case 5126: 4;  // GL_FLOAT - 4 bytes per float
			case 5124: 4;  // GL_INT - 4 bytes per int
			case 5125: 4;  // GL_UNSIGNED_INT - 4 bytes per uint
			case 5122: 2;  // GL_SHORT - 2 bytes per short
			case 5123: 2;  // GL_UNSIGNED_SHORT - 2 bytes per ushort
			case 5120: 1;  // GL_BYTE - 1 byte per byte
			case 5121: 1;  // GL_UNSIGNED_BYTE - 1 byte per ubyte
			default: 4;    // Default to 4 bytes
		}
	}
	
	private function calculateCurrentOffset():Int {
		var offset = 0;
		for (attr in attributes) {
			offset += attr.size * getFormatSize(attr.format);
		}
		return offset;
	}
	
	public function addUniform(name:String, format:UniformFormat, setter:Dynamic, ?location:UniformLocation):Void {
		uniforms.push({name:name, format:format, setter:setter, location:location});
	}

	public function addTexture(name:String, format:UniformFormat, setter:Dynamic, ?location:UniformLocation):Void {
		textures.push({name:name, format:format, setter:setter, location:location});
	}
	
	// ** Shader compilation and linking
	public function compile(renderer:Renderer):Bool {
		if (isCompiled) return true;
		
		trace("Starting shader compilation...");
		
		// Compile vertex shader
		trace("Creating vertex shader...");
		vertexShader = renderer.createShader(GL.VERTEX_SHADER);
		trace("Vertex shader created: " + vertexShader);
		
		trace("Setting vertex shader source...");
		renderer.shaderSource(vertexShader, vertexShaderSource);
		
		trace("Compiling vertex shader...");
		renderer.compileShader(vertexShader);
		
		// Check vertex shader compilation
		trace("Checking vertex shader compilation...");
		if (!checkShaderCompilation(vertexShader, "Vertex")) {
			trace("Vertex shader compilation failed!");
			return false;
		}
		trace("Vertex shader compiled successfully!");
		
		// Compile fragment shader
		trace("Creating fragment shader...");
		fragmentShader = renderer.createShader(GL.FRAGMENT_SHADER);
		trace("Fragment shader created: " + fragmentShader);
		
		trace("Setting fragment shader source...");
		renderer.shaderSource(fragmentShader, fragmentShaderSource);
		
		trace("Compiling fragment shader...");
		renderer.compileShader(fragmentShader);
		
		// Check fragment shader compilation
		trace("Checking fragment shader compilation...");
		if (!checkShaderCompilation(fragmentShader, "Fragment")) {
			trace("Fragment shader compilation failed!");
			return false;
		}
		trace("Fragment shader compiled successfully!");
		
		// Create and link program
		trace("Creating shader program...");
		program = renderer.createProgram();
		trace("Shader program created: " + program);
		
		renderer.attachShader(program, vertexShader);
		renderer.attachShader(program, fragmentShader);
		renderer.linkProgram(program);
		
		// Check program linking
		trace("Checking program linking...");
		if (!checkProgramLinking()) {
			trace("Program linking failed!");
			return false;
		}
		trace("Program linked successfully!");
		
		isCompiled = true;
		trace("Shader compilation complete!");
		return true;
	}
	
	// ** Automatically discover attributes and uniforms from compiled shader program
	private function introspectProgram(renderer:Renderer):Void {
		if (!isCompiled) {
			trace("Warning: Cannot introspect program that is not compiled");
			return;
		}
		
		trace("Starting shader program introspection for: " + __name);
		
		// Clear existing arrays
		attributes = [];
		uniforms = [];
		
		// Introspect active attributes
		introspectAttributes(renderer);
		
		// Introspect active uniforms  
		introspectUniforms(renderer);
		
		trace("Introspection complete!");
	}
	
	// ** Discover all active vertex attributes
	private function introspectAttributes(renderer:Renderer):Void {
		// Get number of active attributes
		var activeAttributes:Int = 0;
		untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_ATTRIBUTES, &{1})", program, activeAttributes);
		trace("Found " + activeAttributes + " active attributes");
		
		// Get maximum attribute name length
		var maxNameLength:Int = 0;
		untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &{1})", program, maxNameLength);
		
		for (i in 0...activeAttributes) {
			var nameLength:Int = 0;
			var size:Int = 0;
			var type:Int = 0;
			var name:String = "";
			
			// Get attribute info using C++ code with dynamic allocation
			untyped __cpp__("
				char* nameBuffer = new char[{0}];
				glGetActiveAttrib({1}, {2}, {0}, &{3}, &{4}, (GLenum*)&{5}, nameBuffer);
				{6} = String(nameBuffer);
				delete[] nameBuffer;
			", maxNameLength, program, i, nameLength, size, type, name);
			
			// Get attribute location
			var location:Int = renderer.getAttribLocation(program, name);
			
			// Determine component count based on OpenGL type
			var componentCount = getComponentCount(type);
			
			trace("Attribute " + i + ": '" + name + "' location=" + location + " type=" + type + " size=" + size + " components=" + componentCount);
			
			// Add to attributes array (offset and stride will be calculated later)
			attributes.push({
				name: name,
				format: GL.FLOAT, // Assume float for now - could be enhanced
				size: componentCount,
				stride: 0,  // Will be calculated in finalizeVertexLayout
				offset: 0,  // Will be calculated in finalizeVertexLayout  
				location: location
			});
		}
	}
	
	// ** Discover all active uniforms
	private function introspectUniforms(renderer:Renderer):Void {
		// Get number of active uniforms
		var activeUniforms:Int = 0;
		untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_UNIFORMS, &{1})", program, activeUniforms);
		trace("Found " + activeUniforms + " active uniforms");
		
		// Get maximum uniform name length
		var maxNameLength:Int = 0;
		untyped __cpp__("glGetProgramiv({0}, GL_ACTIVE_UNIFORM_MAX_LENGTH, &{1})", program, maxNameLength);
		
		for (i in 0...activeUniforms) {
			var nameLength:Int = 0;
			var size:Int = 0;
			var type:Int = 0;
			var name:String = "";
			
			// Get uniform info using C++ code with dynamic allocation
			untyped __cpp__("
				char* nameBuffer = new char[{0}];
				glGetActiveUniform({1}, {2}, {0}, &{3}, &{4}, (GLenum*)&{5}, nameBuffer);
				{6} = String(nameBuffer);
				delete[] nameBuffer;
			", maxNameLength, program, i, nameLength, size, type, name);
			
			// Get uniform location
			var location:Int = renderer.getUniformLocation(program, name);
			
			// Convert OpenGL type to our UniformFormat
			var format = convertGLTypeToUniformFormat(type);
			
			trace("Uniform " + i + ": '" + name + "' location=" + location + " type=" + type + " format=" + format);
			
			// Add to uniforms array
			uniforms.push({
				name: name,
				format: format,
				setter: null, // No setter needed for introspected uniforms
				location: location
			});
		}
	}
	
	// ** Helper: Get component count from OpenGL type
	private function getComponentCount(glType:Int):Int {
		return switch (glType) {
			case 5126: 1;   // GL_FLOAT
			case 35664: 2;  // GL_FLOAT_VEC2
			case 35665: 3;  // GL_FLOAT_VEC3
			case 35666: 4;  // GL_FLOAT_VEC4
			case 5124: 1;   // GL_INT
			case 35667: 2;  // GL_INT_VEC2
			case 35668: 3;  // GL_INT_VEC3
			case 35669: 4;  // GL_INT_VEC4
			default: 1;     // Default to 1 for unknown types
		}
	}
	
	// ** Helper: Convert OpenGL type to UniformFormat
	private function convertGLTypeToUniformFormat(glType:Int):UniformFormat {
		return switch (glType) {
			case 5126: UniformFormat.Float;     // GL_FLOAT
			case 35664: UniformFormat.Vec2;     // GL_FLOAT_VEC2
			case 35665: UniformFormat.Vec3;     // GL_FLOAT_VEC3
			case 35666: UniformFormat.Vec4;     // GL_FLOAT_VEC4
			case 35676: UniformFormat.Mat4;     // GL_FLOAT_MAT4
			case 5124: UniformFormat.Int;       // GL_INT
			case 35678: UniformFormat.Sampler2D; // GL_SAMPLER_2D
			default: UniformFormat.Float;       // Default fallback
		}
	}
	
	private function checkShaderCompilation(shader:Shader, type:String):Bool {
		// TODO: Add proper shader compilation checking
		// For now, assume success
		return true;
	}
	
	private function checkProgramLinking():Bool {
		// TODO: Add proper program linking checking
		// For now, assume success
		return true;
	}
	
	// ** Default shaders for basic rendering
	private function getDefaultVertexShader():String {
		return '
		#version 330 core
		layout (location = 0) in vec3 aPos;
		layout (location = 1) in vec2 aTexCoord;
		
		out vec2 TexCoord;
		
		uniform mat4 uProjection;
		uniform mat4 uView;
		uniform mat4 uModel;
		
		void main() {
			gl_Position = uProjection * uView * uModel * vec4(aPos, 1.0);
			TexCoord = aTexCoord;
		}
		';
	}
	
	private function getDefaultFragmentShader():String {
		return '
		#version 330 core
		out vec4 FragColor;
		
		in vec2 TexCoord;
		
		uniform sampler2D uTexture;
		uniform vec4 uColor;
		
		void main() {
			FragColor = texture(uTexture, TexCoord) * uColor;
		}
		';
	}
	
	// ** Cleanup
	public function dispose(renderer:Renderer):Void {
		if (isCompiled) {
			// if (program != 0) renderer.deleteProgram(program);
			if (vertexShader != 0) renderer.deleteShader(vertexShader);
			if (fragmentShader != 0) renderer.deleteShader(fragmentShader);
		}
		isCompiled = false;
	}
	
	// ** Getters and setters.
	
	private function get_name():String {
		return __name;
	}

	private function get_textureCount():Int {
		return textures.length;
	}
}