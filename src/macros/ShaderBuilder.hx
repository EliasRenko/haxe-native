package macros;

/**
 * Generates a standard vertex shader from a fragment shader source.
 *
 * Convention (matches all shaders in res/shaders/):
 *   - #version 330 core
 *   - Position always at layout(location = 0) in vec3 aPos
 *   - Each fragment `in <type> <name>` becomes layout(location = N) in <type> a<Name>
 *     plus a matching vertex `out <type> <name>`
 *   - uniform mat4 uMatrix is always emitted; main() uses:
 *       gl_Position = uMatrix * vec4(aPos, 1.0);
 *       <name> = a<Name>;  // for each varying
 */
class ShaderBuilder {

	static final DEFAULT_VERSION = "#version 330 core";

	// -------------------------------------------------------------------------
	// Public API
	// -------------------------------------------------------------------------

	/**
	 * Patch a shader source string for the current compile target.
	 *
	 * On JS (WebGL2 / GLSL ES 3.0):
	 *   - Replaces `#version 330 core` (or any `#version NNN core`) with
	 *     `#version 300 es\nprecision mediump float;`
	 *   - Strips uniform default-value initialisers  (e.g. `= vec4(1.0, ...)`)
	 *     because GLSL ES 3.0 does not support them.
	 *
	 * On CPP (OpenGL 3.3 desktop):
	 *   - Returns the source unchanged.
	 */
	public static function patchForTarget(src:String):String {
		if (src == null) return src;
		src = StringTools.trim(src);
		#if js
		// 1. Replace version directive
		var reVersion = ~/#version\s+\d+\s+core/g;
		src = reVersion.replace(src, "#version 300 es\nprecision mediump float;");

		// 2. Strip uniform default initialisers:  `uniform <type> <name> = <expr>;`
		//    -> `uniform <type> <name>;`
		var reDefault = ~/^(\s*uniform\s+\S+\s+\S+)\s*=\s*[^;]+;/gm;
		src = reDefault.replace(src, "$1;");
		#end
		return src;
	}

	/**
	 * Build a vertex shader that feeds into the given fragment shader.
	 * Returns a minimal position-only shader when fragmentSource is null/empty.
	 */
	public static function defaultVertexFor(fragmentSource:String):String {
		if (fragmentSource == null || fragmentSource.length == 0)
			return buildMinimal(DEFAULT_VERSION);

		var version  = extractVersion(fragmentSource);
		var varyings = extractVaryings(fragmentSource);

		var sb = new StringBuf();

		// --- version ---
		sb.add(version);
		sb.add("\n\n");

		// --- attribute declarations ---
		sb.add("layout (location = 0) in vec3 aPos;\n");
		for (i in 0...varyings.length) {
			var v = varyings[i];
			sb.add('layout (location = ${i + 1}) in ${v.type} ${attrName(v.name)};\n');
		}

		// --- varying outputs ---
		if (varyings.length > 0) {
			sb.add("\n");
			for (v in varyings)
				sb.add('out ${v.type} ${v.name};\n');
		}

		// --- uniforms ---
		sb.add("\nuniform mat4 uMatrix;\n");

		// --- main ---
		sb.add("\nvoid main() {\n");
		sb.add("    gl_Position = uMatrix * vec4(aPos, 1.0);\n");
		for (v in varyings)
			sb.add('    ${v.name} = ${attrName(v.name)};\n');
		sb.add("}\n");

		return sb.toString();
	}

	// -------------------------------------------------------------------------
	// Helpers
	// -------------------------------------------------------------------------

	/** "TexCoord" -> "aTexCoord",  "vertexColor" -> "aVertexColor" */
	static function attrName(varyingName:String):String {
		if (varyingName.length == 0) return "a";
		return "a" + varyingName.charAt(0).toUpperCase() + varyingName.substr(1);
	}

	/** Extract `#version` line or return the default. */
	static function extractVersion(src:String):String {
		for (line in src.split("\n")) {
			var t = StringTools.trim(line);
			if (StringTools.startsWith(t, "#version")) return t;
		}
		return DEFAULT_VERSION;
	}

	/**
	 * Extract all `in <type> <name>;` declarations from a fragment shader.
	 * Skips anything inside a function body (lines containing `{` or `}`).
	 */
	static function extractVaryings(src:String):Array<{type:String, name:String}> {
		var result:Array<{type:String, name:String}> = [];
		var inBody = false;
		var re = ~/^\s*in\s+(\w+)\s+(\w+)\s*;/;

		for (line in src.split("\n")) {
			var t = StringTools.trim(line);
			if (t.indexOf("{") >= 0) { inBody = true;  continue; }
			if (t.indexOf("}") >= 0) { inBody = false; continue; }
			if (inBody) continue;

			if (re.match(t))
				result.push({ type: re.matched(1), name: re.matched(2) });
		}
		return result;
	}

	/**
	 * Parse uniform default-value initialisers from GLSL source and return them
	 * as a map of name → value.  Supports vec2/3/4 constructors and plain
	 * float/int literals.  Call this on the RAW source before patchForTarget().
	 */
	public static function extractUniformDefaults(src:String):Map<String, Dynamic> {
		var result:Map<String, Dynamic> = new Map();
		if (src == null) return result;

		var re = ~/^\s*uniform\s+(\S+)\s+(\w+)\s*=\s*([^;]+);/gm;
		var rest = src;
		while (re.match(rest)) {
			var type = re.matched(1);
			var name = re.matched(2);
			var expr = StringTools.trim(re.matched(3));
			var value = __parseUniformExpr(type, expr);
			if (value != null) result.set(name, value);
			rest = re.matchedRight();
		}
		return result;
	}

	private static function __parseUniformExpr(type:String, expr:String):Dynamic {
		// vec2/3/4 constructor
		var vecRe = ~/^vec(\d)\(([^)]+)\)/;
		if (vecRe.match(expr)) {
			var n = Std.parseInt(vecRe.matched(1));
			var args = vecRe.matched(2).split(",").map(function(s) return Std.parseFloat(StringTools.trim(s)));
			if (args.length == 1) return [for (_ in 0...n) args[0]];
			return args;
		}
		// Plain numeric literal
		var f = Std.parseFloat(expr);
		if (!Math.isNaN(f)) return f;
		return null;
	}

	/** Minimal shader: just transforms position, no varyings. */
	static function buildMinimal(version:String):String {
		return '${version}\n\nlayout (location = 0) in vec3 aPos;\n\nuniform mat4 uMatrix;\n\nvoid main() {\n    gl_Position = uMatrix * vec4(aPos, 1.0);\n}\n';
	}
}
