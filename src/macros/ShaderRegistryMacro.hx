package macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.io.Path;
import sys.FileSystem;

typedef ShaderData = {
    var id:Int;
    var name:String;
    var vertexSource:String;
    var fragmentSource:String;
}

class ShaderRegistryMacro {

    static final DEFAULT_VERSION = "#version 330 core";

    static function defaultVertexFor(fragmentSource:String):String {
        if (fragmentSource == null || fragmentSource.length == 0) {
            return buildMinimalVertex(DEFAULT_VERSION);
        }

        var version = extractVersion(fragmentSource);
        var varyings = extractVaryings(fragmentSource);
        var source = new StringBuf();

        source.add(version);
        source.add("\n\n");
        source.add("layout (location = 0) in vec3 aPos;\n");
        for (i in 0...varyings.length) {
            var varying = varyings[i];
            source.add('layout (location = ${i + 1}) in ${varying.type} ${attributeName(varying.name)};\n');
        }

        if (varyings.length > 0) {
            source.add("\n");
            for (varying in varyings) {
                source.add('out ${varying.type} ${varying.name};\n');
            }
        }

        source.add("\nuniform mat4 uMatrix;\n");
        source.add("\nvoid main() {\n");
        source.add("    gl_Position = uMatrix * vec4(aPos, 1.0);\n");
        for (varying in varyings) {
            source.add('    ${varying.name} = ${attributeName(varying.name)};\n');
        }
        source.add("}\n");

        return source.toString();
    }

    static function attributeName(varyingName:String):String {
        if (varyingName.length == 0) return "a";
        return "a" + varyingName.charAt(0).toUpperCase() + varyingName.substr(1);
    }

    static function extractVersion(src:String):String {
        for (line in src.split("\n")) {
            var trimmed = StringTools.trim(line);
            if (StringTools.startsWith(trimmed, "#version")) return trimmed;
        }
        return DEFAULT_VERSION;
    }

    static function extractVaryings(src:String):Array<{type:String, name:String}> {
        var result:Array<{type:String, name:String}> = [];
        var inBody = false;
        var declaration = ~/^\s*in\s+(\w+)\s+(\w+)\s*;/;

        for (line in src.split("\n")) {
            var trimmed = StringTools.trim(line);
            if (trimmed.indexOf("{") >= 0) {
                inBody = true;
                continue;
            }
            if (trimmed.indexOf("}") >= 0) {
                inBody = false;
                continue;
            }
            if (inBody) continue;

            if (declaration.match(trimmed)) {
                result.push({type: declaration.matched(1), name: declaration.matched(2)});
            }
        }
        return result;
    }

    static function buildMinimalVertex(version:String):String {
        return '${version}\n\nlayout (location = 0) in vec3 aPos;\n\nuniform mat4 uMatrix;\n\nvoid main() {\n    gl_Position = uMatrix * vec4(aPos, 1.0);\n}\n';
    }

    public static function build(packageName:String):Array<Field> {
        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        var packagePath = StringTools.replace(packageName, ".", "/");
        var modules:Array<String> = [];
        var seenModules = new Map<String, Bool>();

        // 1. Scan every Haxe classpath.
        for (classPath in Context.getClassPath()) {
            var directory = Path.join([classPath, packagePath]);

            if (!FileSystem.exists(directory)
                || !FileSystem.isDirectory(directory)) {
                continue;
            }

            for (file in FileSystem.readDirectory(directory)) {
                if (Path.extension(file) != "hx") {
                    continue;
                }

                var moduleName = Path.withoutExtension(file);

                if (StringTools.startsWith(moduleName, "_")
                    || seenModules.exists(moduleName)) {
                    continue;
                }

                seenModules.set(moduleName, true);
                modules.push(packageName + "." + moduleName);
            }
        }

        modules.sort(Reflect.compare);

        if (modules.length == 0) {
            Context.error(
                'No Haxe modules found for package "$packageName".',
                pos
            );
        }

        // Discover shader classes.
        var shaders:Array<ShaderData> = [];
        var seen = new Map<String, Bool>();

        for (moduleName in modules) {
            var types:Array<Type>;

            try {
                types = Context.getModule(moduleName);
            } catch (e:Dynamic) {
                Context.error(
                    'Could not load shader module "$moduleName": $e',
                    pos
                );
                continue;
            }

            for (type in types) {
                switch (type) {
                    case TInst(classRef, _):
                        var cls = classRef.get();
                        var expectedName =
                            moduleName.split(".").pop();

                        // Only inspect the class matching the filename.
                        if (cls.name != expectedName) {
                            continue;
                        }

                        if (!extendsShader(cls)) {
                            continue;
                        }

                        var className =
                            cls.pack.concat([cls.name]).join(".");

                        if (seen.exists(className)) {
                            Context.error(
                                'Duplicate shader registration: $className',
                                cls.pos
                            );
                            continue;
                        }

                        seen.set(className, true);

                        validateUniformDefinitions(cls);

                        var fragmentSource = getMetadataString(
                            cls,
                            ":shaderSourceFrag"
                        );
                        var vertexSource = getMetadataString(
                            cls,
                            ":shaderSourceVert",
                            false
                        );
                        if (vertexSource == null) {
                            vertexSource = defaultVertexFor(fragmentSource);
                        }

                        shaders.push({
                            id: getShaderId(cls),
                            name: className,
                            vertexSource: vertexSource,
                            fragmentSource: fragmentSource
                        });

                    default:
                }
            }
        }

        // Sort using the IDs generated by ShaderGenMacro.
        shaders.sort(function(a, b) {
            return a.id - b.id;
        });

        // IDs used as array indices must be unique and contiguous.
        for (i in 0...shaders.length) {
            if (shaders[i].id != i) {
                Context.error(
                    'Shader IDs must be contiguous from 0. Expected $i, '
                    + 'got ${shaders[i].id} for ${shaders[i].name}.',
                    pos
                );
            }
        }

        // Generate shader definitions.
        var definitionExpressions:Array<Expr> = [];

        for (shader in shaders) {
            var name = shader.name;
            var vertexSource = shader.vertexSource;
            var fragmentSource = shader.fragmentSource;

            definitionExpressions.push(
                macro {
                    name: $v{name},
                    vertexSource: $v{vertexSource},
                    fragmentSource: $v{fragmentSource}
                }
            );
        }

        fields.push({
            name: "definitions",
            access: [APrivate, AStatic, AFinal],
            kind: FVar(
                macro:Array<ShaderDefinition>,
                macro $a{definitionExpressions}
            ),
            pos: pos
        });

        Context.info(
            'Discovered ${shaders.length} shaders in "$packageName".',
            pos
        );

        return fields;
    }

    static function extendsShader(
        cls:haxe.macro.Type.ClassType
    ):Bool {
        var parent = cls.superClass;

        while (parent != null) {
            var parentClass = parent.t.get();

            if (parentClass.name == "Shader"
                && parentClass.pack.length == 1
                && parentClass.pack[0] == "data") {
                return true;
            }

            parent = parentClass.superClass;
        }

        return false;
    }

    static function getMetadataString(
        cls:haxe.macro.Type.ClassType,
        metadataName:String,
        required:Bool = true
    ):String {
        for (meta in cls.meta.get()) {
            if (meta.name != metadataName) {
                continue;
            }

            if (meta.params == null || meta.params.length != 1) {
                Context.error(
                    '$metadataName on ${cls.name} must have one argument.',
                    cls.pos
                );
                return "";
            }

            switch (meta.params[0].expr) {
                case EConst(CString(value, _)):
                    return value;

                default:
                    Context.error(
                        '$metadataName on ${cls.name} must contain a string literal.',
                        meta.params[0].pos
                    );
                    return "";
            }
        }

        if (required) {
            Context.error(
                '${cls.name} is missing $metadataName metadata.',
                cls.pos
            );
        }

        return null;
    }

    static function getShaderId(
        cls:haxe.macro.Type.ClassType
    ):Int {
        for (meta in cls.meta.get()) {
            if (meta.name != ":shaderId") {
                continue;
            }

            if (meta.params == null || meta.params.length != 1) {
                Context.error(
                    'Invalid shaderId metadata on ${cls.name}.',
                    cls.pos
                );
                return -1;
            }

            switch (meta.params[0].expr) {
                case EConst(CInt(value)):
                    return Std.parseInt(value);

                default:
                    Context.error(
                        'shaderId on ${cls.name} must be an integer.',
                        meta.params[0].pos
                    );
                    return -1;
            }
        }

        Context.error(
            'No generated :shaderId metadata found for ${cls.name}. '
            + 'Check that ShaderGenMacro adds the metadata.',
            cls.pos
        );

        return -1;
    }

    static function validateUniformDefinitions(
        cls:haxe.macro.Type.ClassType
    ):Void {
        var seenNames = new Map<String, Bool>();

        for (meta in cls.meta.get()) {
            if (meta.name != ":uniform") {
                continue;
            }

            var params = meta.params;

            if (params == null || params.length != 2) {
                Context.error(
                    '@:uniform on ${cls.name} must have exactly two '
                    + 'arguments: ("name", Type).',
                    meta.pos
                );
                continue;
            }

            var uniformName:String;

            switch (params[0].expr) {
                case EConst(CString(value, _)):
                    uniformName = value;

                default:
                    Context.error(
                        'The first @:uniform argument on ${cls.name} '
                        + 'must be a string.',
                        params[0].pos
                    );
                    continue;
            }

            var uniformType = getUniformTypeName(params[1]);
            validateUniformType(uniformType, params[1].pos);

            if (uniformName.length == 0) {
                Context.error(
                    'Uniform names cannot be empty in ${cls.name}.',
                    meta.pos
                );
                continue;
            }

            if (seenNames.exists(uniformName)) {
                Context.error(
                    'Duplicate uniform name "$uniformName" '
                    + 'in shader ${cls.name}.',
                    meta.pos
                );
                continue;
            }

            seenNames.set(uniformName, true);

        }
    }

    static function getUniformTypeName(expr:Expr):String {
        return switch (expr.expr) {
            case EConst(CIdent(name)): name;
            case EField(_, name): name;
            default:
                Context.error(
                    "The second @:uniform argument must be a type name.",
                    expr.pos
                );
                "";
        }
    }

    static function validateUniformType(name:String, pos:Position):Void {
        switch (name) {
            case "Float" | "Vec2" | "Vec3" | "Vec4" | "Matrix"
                | "Int" | "Bool" | "Texture":
            default:
                Context.error(
                    'Unsupported shader uniform value type "$name".',
                    pos
                );
        }
    }

}
#end
