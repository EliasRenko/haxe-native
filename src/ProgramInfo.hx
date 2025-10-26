package;

import GL;

// OpenGL types for C++ externs
typedef UniformLocation = GlUInt;
typedef Program = GlUInt;
typedef Shader = GlUInt;

// Attribute data formats
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
			case Vec2: 2;
			case Vec3: 3;
			case Vec4: 4;
			case Int | UnsignedInt | Byte | UnsignedByte | Short | UnsignedShort: 1;
		}
	}
	
	public static function getBytesPerVertex(format:AttributeFormat):Int {
		return switch (format) {
			case Float | Int | UnsignedInt: 4;
			case Vec2: 8;
			case Vec3: 12;
			case Vec4: 16;
			case Short | UnsignedShort: 2;
			case Byte | UnsignedByte: 1;
		}
	}
}

// Uniform data formats
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
	var format:AttributeFormat;  // Use our AttributeFormat enum
	var size:Int;               // Number of components (1, 2, 3, or 4)
	var stride:Int;             // Byte offset between consecutive attributes
	var offset:Int;             // Byte offset from start of vertex data
	var location:Int;           // Shader attribute location (required)
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
	
	// ** Performance optimization: O(1) uniform lookup map
	private var uniformMap:Map<String, Uniform> = new Map<String, Uniform>();
	
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
		if (!renderer.compileProgramInfo(this)) {
			trace("Failed to compile shader program: " + name);
			return;
		}
		
		// Automatically discover attributes and uniforms from compiled program
		introspectProgram(renderer);
		
		// Calculate vertex layout for interleaved data
		finalizeVertexLayout();
		
		trace("ProgramInfo '" + name + "' created and introspected successfully!");
	}

	/**
	 * Get uniform by name with O(1) lookup performance
	 */
	public function getUniform(name:String):Uniform {
		return uniformMap.get(name);
	}

	public function addAttribute(name:String, format:AttributeFormat, size:Int, stride:Int, offset:Int, location:Int):Void {
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
	public function addAttributeAuto(name:String, format:AttributeFormat, size:Int, location:Int):Void {
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
			// Size in bytes using our AttributeFormat system
			var sizeInBytes = AttributeFormatHelper.getBytesPerVertex(attr.format);
			currentOffset += sizeInBytes;
		}
		
		var totalVertexSize = currentOffset;
		
		// Set the same stride for ALL attributes (interleaved data)
		for (attr in attributes) {
			attr.stride = totalVertexSize;
		}
		
		dataPerVertex = totalVertexSize;
		//trace("Vertex layout finalized: " + totalVertexSize + " bytes per vertex");
	}
	
	// TODO: Must be called once when we init the ProgramInfo for drawing.
	// ** Setup vertex attributes using glVertexAttribPointer
	public function setupVertexAttributes(renderer:Renderer):Void {
		if (!isCompiled) {
			trace("Warning: Program not compiled yet, attributes may not be bound correctly");
		}
		
		//trace("Setting up " + attributes.length + " vertex attributes:");
		for (attr in attributes) {
			//trace("  " + attr.name + ": location=" + attr.location + ", size=" + attr.size + ", stride=" + attr.stride + ", offset=" + attr.offset);
			
			// Enable the vertex attribute array
			renderer.enableVertexAttribArray(attr.location);
			
			// Set up the vertex attribute pointer  
			renderer.vertexAttribPointer(attr.location, attr.size, getGLFormat(attr.format), false, attr.stride, attr.offset);
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
			var sizeInBytes = AttributeFormatHelper.getBytesPerVertex(attr.format);
			
			trace('  [$i] ${attr.name}:');
			trace('      Location: ${attr.location}');
			trace('      Format: $formatName (${attr.size} components)');
			trace('      Size: $sizeInBytes bytes');
			trace('      Offset: ${attr.offset} bytes');
			trace('      Stride: ${attr.stride} bytes');
		}
		trace("========================");
	}
	
	// ** Helper: Convert OpenGL type to AttributeFormat
	private function convertGLTypeToAttributeFormat(glType:Int):AttributeFormat {
		return switch (glType) {
			case 5126: AttributeFormat.Float;        // GL_FLOAT
			case 35664: AttributeFormat.Vec2;        // GL_FLOAT_VEC2
			case 35665: AttributeFormat.Vec3;        // GL_FLOAT_VEC3
			case 35666: AttributeFormat.Vec4;        // GL_FLOAT_VEC4
			case 5124: AttributeFormat.Int;          // GL_INT
			case 5125: AttributeFormat.UnsignedInt;  // GL_UNSIGNED_INT
			case 5120: AttributeFormat.Byte;         // GL_BYTE
			case 5121: AttributeFormat.UnsignedByte; // GL_UNSIGNED_BYTE
			case 5122: AttributeFormat.Short;        // GL_SHORT
			case 5123: AttributeFormat.UnsignedShort;// GL_UNSIGNED_SHORT
			default: AttributeFormat.Float;          // Default fallback
		}
	}

	private function getFormatName(format:AttributeFormat):String {
		return switch (format) {
			case AttributeFormat.Float: "FLOAT";
			case AttributeFormat.Vec2: "VEC2";
			case AttributeFormat.Vec3: "VEC3";
			case AttributeFormat.Vec4: "VEC4";
			case AttributeFormat.Int: "INT";
			case AttributeFormat.UnsignedInt: "UNSIGNED_INT";
			case AttributeFormat.Byte: "BYTE";
			case AttributeFormat.UnsignedByte: "UNSIGNED_BYTE";
			case AttributeFormat.Short: "SHORT";
			case AttributeFormat.UnsignedShort: "UNSIGNED_SHORT";
		}
	}
	
	private function getFormatSize(format:AttributeFormat):Int {
		return switch (format) {
			case AttributeFormat.Float | AttributeFormat.Int | AttributeFormat.UnsignedInt: 4;
			case AttributeFormat.Short | AttributeFormat.UnsignedShort: 2;
			case AttributeFormat.Byte | AttributeFormat.UnsignedByte: 1;
			case AttributeFormat.Vec2: 8;  // 2 * 4 bytes
			case AttributeFormat.Vec3: 12; // 3 * 4 bytes  
			case AttributeFormat.Vec4: 16; // 4 * 4 bytes
		}
	}
	
	// ** Helper: Convert AttributeFormat to GL constant for rendering
	private function getGLFormat(format:AttributeFormat):Int {
		return switch (format) {
			case AttributeFormat.Float | AttributeFormat.Vec2 | AttributeFormat.Vec3 | AttributeFormat.Vec4: 5126; // GL_FLOAT
			case AttributeFormat.Int: 5124;          // GL_INT
			case AttributeFormat.UnsignedInt: 5125;  // GL_UNSIGNED_INT
			case AttributeFormat.Byte: 5120;         // GL_BYTE
			case AttributeFormat.UnsignedByte: 5121; // GL_UNSIGNED_BYTE
			case AttributeFormat.Short: 5122;        // GL_SHORT
			case AttributeFormat.UnsignedShort: 5123;// GL_UNSIGNED_SHORT
		}
	}
	
	private function calculateCurrentOffset():Int {
		var offset = 0;
		for (attr in attributes) {
			offset += AttributeFormatHelper.getBytesPerVertex(attr.format);
		}
		return offset;
	}
	
	public function addUniform(name:String, format:UniformFormat, setter:Dynamic, ?location:UniformLocation):Void {
		var uniformData = {name:name, format:format, setter:setter, location:location};
		uniforms.push(uniformData);
		uniformMap.set(name, uniformData);
	}

	public function addTexture(name:String, format:UniformFormat, setter:Dynamic, ?location:UniformLocation):Void {
		var textureData = {name:name, format:format, setter:setter, location:location};
		textures.push(textureData);
		uniformMap.set(name, textureData); // Also add to uniform map for consistent lookup
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
			
			// Convert OpenGL type to our AttributeFormat
			var format = convertGLTypeToAttributeFormat(type);
			var componentCount = AttributeFormatHelper.getValuesPerVertex(format);
			
			trace("Attribute " + i + ": '" + name + "' location=" + location + " type=" + type + " format=" + format + " components=" + componentCount);
			
			// Add to attributes array (offset and stride will be calculated later)
			attributes.push({
				name: name,
				format: format,
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
			
			// Create the uniform data with pre-computed setter function
			var setter = createUniformSetter(format, location);
			var uniformData = {
				name: name,
				format: format,
				setter: setter, // Pre-computed setter function for O(1) uniform setting
				location: (location : UniformLocation)
			};
			
			// Add to uniforms array
			uniforms.push(uniformData);
			
			// Add to uniform map for O(1) lookup performance
			uniformMap.set(name, uniformData);
			
			// If it's a texture sampler, also add to textures array with proper setter
			if (format == UniformFormat.Sampler2D) {
				var textureData = {
					name: name,
					format: format,
					setter: function(slot:Int) {
						GL.uniform1i(location, slot);
					},
					location: (location : UniformLocation)
				};
				textures.push(textureData);
			}
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
	
	// ** Pre-computed uniform setter creation for optimal performance
	private function createUniformSetter(format:UniformFormat, location:UniformLocation):Dynamic {
		return switch (format) {
			case UniformFormat.Float:
				floatSetter(location);
			case UniformFormat.Vec2:
				floatVec2Setter(location);
			case UniformFormat.Vec3:
				floatVec3Setter(location);
			case UniformFormat.Vec4:
				floatVec4Setter(location);
			case UniformFormat.Mat2:
				floatMat2Setter(location);
			case UniformFormat.Mat3:
				floatMat3Setter(location);
			case UniformFormat.Mat4:
				floatMat4Setter(location);
			case UniformFormat.Int:
				intSetter(location);
			case UniformFormat.IntVec2:
				intVec2Setter(location);
			case UniformFormat.IntVec3:
				intVec3Setter(location);
			case UniformFormat.IntVec4:
				intVec4Setter(location);
			case UniformFormat.Bool:
				boolSetter(location);
			case UniformFormat.BoolVec2:
				boolVec2Setter(location);
			case UniformFormat.BoolVec3:
				boolVec3Setter(location);
			case UniformFormat.BoolVec4:
				boolVec4Setter(location);
			case UniformFormat.Sampler2D:
				sampler2DSetter(location);
			case UniformFormat.SamplerCube:
				samplerCubeSetter(location);
			default:
				throw "Unknown uniform format: " + format;
		}
	}
	
	// ** Individual setter function factories
	private function floatSetter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var floatValue:Float = cast value;
			GL.uniform1f(location, floatValue);
		};
	}
	
	private function intSetter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var intValue:Int = cast value;
			GL.uniform1i(location, intValue);
		};
	}
	
	private function floatVec2Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec2Data:Array<Float> = cast value;
			if (vec2Data.length >= 2) {
				untyped __cpp__("glUniform2f({0}, {1}, {2})", location, vec2Data[0], vec2Data[1]);
			}
		};
	}
	
	private function floatVec3Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec3Data:Array<Float> = cast value;
			if (vec3Data.length >= 3) {
				untyped __cpp__("glUniform3f({0}, {1}, {2}, {3})", location, vec3Data[0], vec3Data[1], vec3Data[2]);
			}
		};
	}
	
	private function floatVec4Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec4Data:Array<Float> = cast value;
			if (vec4Data.length >= 4) {
				untyped __cpp__("glUniform4f({0}, {1}, {2}, {3}, {4})", location, vec4Data[0], vec4Data[1], vec4Data[2], vec4Data[3]);
			}
		};
	}
	
	private function floatMat4Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var matrixData:Array<Float> = cast value;
			// Create a copy to ensure proper memory layout
			var matrixArray = new Array<Float>();
			for (i in 0...16) {
				matrixArray[i] = matrixData[i];
			}
			// Use transpose=false for column-major OpenGL matrix format
			untyped __cpp__("
				float matData[16];
				for(int i = 0; i < 16; i++) {
					matData[i] = {1}[i];
				}
				glUniformMatrix4fv({0}, 1, GL_FALSE, matData);
			", location, matrixArray);
		};
	}
	
	private function sampler2DSetter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var textureSlot:Int = cast value;
			GL.uniform1i(location, textureSlot);
		};
	}
	
	private function floatMat2Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var matrixData:Array<Float> = cast value;
			// Create a copy to ensure proper memory layout
			var matrixArray = new Array<Float>();
			for (i in 0...4) {
				matrixArray[i] = matrixData[i];
			}
			// Use transpose=false for column-major OpenGL matrix format
			untyped __cpp__("
				float matData[4];
				for(int i = 0; i < 4; i++) {
					matData[i] = {1}[i];
				}
				glUniformMatrix2fv({0}, 1, GL_FALSE, matData);
			", location, matrixArray);
		};
	}
	
	private function floatMat3Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var matrixData:Array<Float> = cast value;
			// Create a copy to ensure proper memory layout
			var matrixArray = new Array<Float>();
			for (i in 0...9) {
				matrixArray[i] = matrixData[i];
			}
			// Use transpose=false for column-major OpenGL matrix format
			untyped __cpp__("
				float matData[9];
				for(int i = 0; i < 9; i++) {
					matData[i] = {1}[i];
				}
				glUniformMatrix3fv({0}, 1, GL_FALSE, matData);
			", location, matrixArray);
		};
	}
	
	private function intVec2Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec2Data:Array<Int> = cast value;
			if (vec2Data.length >= 2) {
				untyped __cpp__("glUniform2i({0}, {1}, {2})", location, vec2Data[0], vec2Data[1]);
			}
		};
	}
	
	private function intVec3Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec3Data:Array<Int> = cast value;
			if (vec3Data.length >= 3) {
				untyped __cpp__("glUniform3i({0}, {1}, {2}, {3})", location, vec3Data[0], vec3Data[1], vec3Data[2]);
			}
		};
	}
	
	private function intVec4Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec4Data:Array<Int> = cast value;
			if (vec4Data.length >= 4) {
				untyped __cpp__("glUniform4i({0}, {1}, {2}, {3}, {4})", location, vec4Data[0], vec4Data[1], vec4Data[2], vec4Data[3]);
			}
		};
	}
	
	private function boolSetter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var boolValue:Bool = cast value;
			GL.uniform1i(location, boolValue ? 1 : 0);
		};
	}
	
	private function boolVec2Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec2Data:Array<Bool> = cast value;
			if (vec2Data.length >= 2) {
				untyped __cpp__("glUniform2i({0}, {1}, {2})", location, vec2Data[0] ? 1 : 0, vec2Data[1] ? 1 : 0);
			}
		};
	}
	
	private function boolVec3Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec3Data:Array<Bool> = cast value;
			if (vec3Data.length >= 3) {
				untyped __cpp__("glUniform3i({0}, {1}, {2}, {3})", location, vec3Data[0] ? 1 : 0, vec3Data[1] ? 1 : 0, vec3Data[2] ? 1 : 0);
			}
		};
	}
	
	private function boolVec4Setter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var vec4Data:Array<Bool> = cast value;
			if (vec4Data.length >= 4) {
				untyped __cpp__("glUniform4i({0}, {1}, {2}, {3}, {4})", location, vec4Data[0] ? 1 : 0, vec4Data[1] ? 1 : 0, vec4Data[2] ? 1 : 0, vec4Data[3] ? 1 : 0);
			}
		};
	}
	
	private function samplerCubeSetter(location:UniformLocation):Dynamic {
		return function(value:Dynamic):Void {
			var textureSlot:Int = cast value;
			GL.uniform1i(location, textureSlot);
		};
	}
	
	// ** Helper: Convert OpenGL type to UniformFormat
	private function convertGLTypeToUniformFormat(glType:Int):UniformFormat {
		return switch (glType) {
			case 5126: UniformFormat.Float;     // GL_FLOAT
			case 35664: UniformFormat.Vec2;     // GL_FLOAT_VEC2
			case 35665: UniformFormat.Vec3;     // GL_FLOAT_VEC3
			case 35666: UniformFormat.Vec4;     // GL_FLOAT_VEC4
			case 35674: UniformFormat.Mat2;     // GL_FLOAT_MAT2
			case 35675: UniformFormat.Mat3;     // GL_FLOAT_MAT3
			case 35676: UniformFormat.Mat4;     // GL_FLOAT_MAT4
			case 5124: UniformFormat.Int;       // GL_INT
			case 35667: UniformFormat.IntVec2;  // GL_INT_VEC2
			case 35668: UniformFormat.IntVec3;  // GL_INT_VEC3
			case 35669: UniformFormat.IntVec4;  // GL_INT_VEC4
			case 35670: UniformFormat.Bool;     // GL_BOOL
			case 35671: UniformFormat.BoolVec2; // GL_BOOL_VEC2
			case 35672: UniformFormat.BoolVec3; // GL_BOOL_VEC3
			case 35673: UniformFormat.BoolVec4; // GL_BOOL_VEC4
			case 35678: UniformFormat.Sampler2D; // GL_SAMPLER_2D
			case 35680: UniformFormat.SamplerCube; // GL_SAMPLER_CUBE
			default: UniformFormat.Float;       // Default fallback
		}
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