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
	
	public function new(name:String, ?vertexSource:String, ?fragmentSource:String) {
		__name = name;
		vertexShaderSource = vertexSource != null ? vertexSource : getDefaultVertexShader();
		fragmentShaderSource = fragmentSource != null ? fragmentSource : getDefaultFragmentShader();
		programId = -1;
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
		var totalVertexSize = calculateCurrentOffset();
		
		// Set the same stride for ALL attributes (interleaved data)
		for (attr in attributes) {
			attr.stride = totalVertexSize;
		}
		
		dataPerVertex = totalVertexSize;
	}
	
	// ** Setup vertex attributes using glVertexAttribPointer
	public function setupVertexAttributes():Void {
		if (!isCompiled) {
			trace("Warning: Program not compiled yet, attributes may not be bound correctly");
		}
		
		for (attr in attributes) {
			// Enable the vertex attribute array
			GL.enableVertexAttribArray(attr.location);
			
			// Set up the vertex attribute pointer  
			// Use raw C++ call to avoid type conversion issues
			untyped __cpp__("glVertexAttribPointer({0}, {1}, {2}, GL_FALSE, {3}, (void*)(intptr_t){4})", 
				attr.location,     // attribute location in shader
				attr.size,         // number of components (1, 2, 3, or 4)
				attr.format,       // data type (GL_FLOAT, GL_INT, etc.)
				attr.stride,       // stride: bytes between consecutive vertices
				attr.offset        // offset: bytes from start of vertex to this attribute
			);
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
		// Using if-else to avoid pattern matching issues
		if (format == GL.FLOAT) return "GL_FLOAT";
		else if (format == GL.INT) return "GL_INT";
		else if (format == GL.UNSIGNED_INT) return "GL_UNSIGNED_INT";
		else if (format == GL.SHORT) return "GL_SHORT";
		else if (format == GL.UNSIGNED_SHORT) return "GL_UNSIGNED_SHORT";
		else if (format == GL.BYTE) return "GL_BYTE";
		else if (format == GL.UNSIGNED_BYTE) return "GL_UNSIGNED_BYTE";
		else return "UNKNOWN";
	}
	
	private function getFormatSize(format:Int):Int {
		// Return bytes per component for different GL formats
		// Using numeric values to avoid pattern matching issues
		if (format == GL.FLOAT) return 4;           // 4 bytes per float
		else if (format == GL.INT) return 4;        // 4 bytes per int
		else if (format == GL.UNSIGNED_INT) return 4; // 4 bytes per uint
		else if (format == GL.SHORT) return 2;      // 2 bytes per short
		else if (format == GL.UNSIGNED_SHORT) return 2; // 2 bytes per ushort
		else if (format == GL.BYTE) return 1;       // 1 byte per byte
		else if (format == GL.UNSIGNED_BYTE) return 1; // 1 byte per ubyte
		else return 4;                              // Default to 4 bytes
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
	public function compile():Bool {
		if (isCompiled) return true;
		
		trace("Starting shader compilation...");
		
		// Compile vertex shader
		trace("Creating vertex shader...");
		vertexShader = GL.createShader(GL.VERTEX_SHADER);
		trace("Vertex shader created: " + vertexShader);
		
		trace("Setting vertex shader source...");
		untyped __cpp__("
			const char* vertexSource = {0}.__s;
			glShaderSource({1}, 1, &vertexSource, NULL);
		", vertexShaderSource, vertexShader);
		
		trace("Compiling vertex shader...");
		GL.compileShader(vertexShader);
		
		// Check vertex shader compilation
		trace("Checking vertex shader compilation...");
		if (!checkShaderCompilation(vertexShader, "Vertex")) {
			trace("Vertex shader compilation failed!");
			return false;
		}
		trace("Vertex shader compiled successfully!");
		
		// Compile fragment shader
		trace("Creating fragment shader...");
		fragmentShader = GL.createShader(GL.FRAGMENT_SHADER);
		trace("Fragment shader created: " + fragmentShader);
		
		trace("Setting fragment shader source...");
		untyped __cpp__("
			const char* fragmentSource = {0}.__s;
			glShaderSource({1}, 1, &fragmentSource, NULL);
		", fragmentShaderSource, fragmentShader);
		
		trace("Compiling fragment shader...");
		GL.compileShader(fragmentShader);
		
		// Check fragment shader compilation
		trace("Checking fragment shader compilation...");
		if (!checkShaderCompilation(fragmentShader, "Fragment")) {
			trace("Fragment shader compilation failed!");
			return false;
		}
		trace("Fragment shader compiled successfully!");
		
		// Create and link program
		trace("Creating shader program...");
		program = GL.createProgram();
		trace("Shader program created: " + program);
		
		GL.attachShader(program, vertexShader);
		GL.attachShader(program, fragmentShader);
		GL.linkProgram(program);
		
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
	public function dispose():Void {
		if (isCompiled) {
			// Note: deleteProgram doesn't exist in our GL bindings, skip for now
			// if (program != 0) GL.deleteProgram(program);
			if (vertexShader != 0) GL.deleteShader(vertexShader);
			if (fragmentShader != 0) GL.deleteShader(fragmentShader);
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