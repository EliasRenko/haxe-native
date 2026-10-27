package;

#if macro
import UniformFormat;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import sys.FileSystem;

/**
 * Compile-time shader discovery and registry generation.
 *
 * Usage:
 *   @:build(ShaderGenMacro.buildRegistry("shaders"))
 *   class ShaderRegistry { ... }
 *
 * Assumptions:
 * - "shaders" is a Haxe package relative to a classpath root (e.g. src/).
 * - Each shader class is in a matching .hx file.
 * - ShaderDefinition has fields:
 *     shaderClass:String, name:String, vertexSource:String,
 *     fragmentSource:String, uniforms:Array<ShaderUniformDefinition>
 * - ShaderRegistryEntry has fields:
 *     definition:ShaderDefinition,
 *     setProgramInfoIndex:Int->Void
 * - Uniform<T> has a constructor Uniform(index:Int).
 */
private typedef UniformInfo = {
    var name:String;
    var index:Int;
    var format:UniformFormat;
}

private typedef RegisteredShader = {
    var classPath:String;
    var shaderName:String;
    var vertexSource:Null<String>;
    var fragmentSource:String;
    var uniforms:Array<UniformInfo>;
}

class ShaderGenMacro {


	static var nextShaderId:Int = 0;

    public static function buildId():Array<Field> {
        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        // Don't generate the fields twice.
        for (field in fields) {
            if (field.name == "shaderId"
                || field.name == "programInfoIndex") {
                Context.error(
                    field.name + " is generated automatically.",
                    field.pos
                );
            }
        }

        var id = nextShaderId++;
		Context.getLocalClass().get().meta.add(":shaderId", [macro $v{id}], pos);

		// Static ID shared by the concrete shader class.
        fields.push({
            name: "shaderId",
            access: [APublic, AStatic, AInline],
            kind: FVar(macro:Int, macro $v{id}),
            pos: pos
        });

        // Instance-level lookup index.
        fields.push({
            name: "programInfoIndex",
            access: [APublic, AFinal],
            kind: FVar(macro:Int, macro $v{id}),
            pos: pos
        });

        var cls = Context.getLocalClass().get();
        var classPath = cls.pack.concat([cls.name]);
        macro this.shaderType = $p{classPath};

        Context.info(
            'Assigned shader ID $id',
            pos
        );

        return fields;
    }

    /**
     * Applied automatically to Shader subclasses through @:autoBuild.
     * Initializes @:uniform fields and adds a static index used by the registry.
     */
    public static function build():Array<Field> {
        var fields = Context.getBuildFields();
        var cls = Context.getLocalClass().get();
        var pos = Context.currentPos();

        var fragmentSource = getShaderSource(cls.meta.get(), ":shaderSourceFrag");
        if (fragmentSource == null) {
            Context.error(
                'Shader class ${cls.name} requires @:shaderSourceFrag("...").',
                pos
            );
        }

        var vertexSource = getShaderSource(cls.meta.get(), ":shaderSourceVert");
        var usedNames = new Map<String, Bool>();
        var usedIndices = new Map<Int, String>();

        for (field in fields) {
            var meta = findMetadata(field.meta, ":uniform");
            if (meta == null) continue;

            if (meta.params == null || meta.params.length != 2) {
                Context.error('@:uniform requires ("GLSLName", index).', meta.pos);
            }

            var uniformName = extractString(meta.params[0]);
            var index = extractInt(meta.params[1]);

            if (index < 0) {
                Context.error("Uniform indices must be zero or greater.", meta.pos);
            }
            if (usedNames.exists(uniformName)) {
                Context.error('Duplicate uniform name "$uniformName".', meta.pos);
            }
            if (usedIndices.exists(index)) {
                Context.error(
                    'Uniform index $index is already used by "${usedIndices.get(index)}".',
                    meta.pos
                );
            }

            usedNames.set(uniformName, true);
            usedIndices.set(index, uniformName);

            // Validate Uniform<T> and replace its initializer with new Uniform(index).
            validateUniformField(field, meta.pos);
            switch (field.kind) {
                case FVar(type, _):
                    field.kind = FVar(type, macro new Uniform($v{index}));
                default:
                    Context.error("@:uniform must be applied to a variable.", field.pos);
            }
        }

        // The registry setter writes this static field. Avoid adding it twice.
        if (!hasField(fields, "programInfoIndex")) {
            fields.push({
                name: "programInfoIndex",
                access: [APublic, AStatic],
                kind: FVar(macro :Int, macro -1),
                pos: pos
            });
        }

        return fields;
    }

    /**
     * Builds the existing ShaderRegistry class by scanning a Haxe package.
     * Example: buildRegistry("shaders") scans <classpath>/shaders recursively.
     */
    public static function buildRegistry(packageName:String):Array<Field> {
        var fields = Context.getBuildFields();
        var packageDir = findPackageDirectory(packageName);
        if (packageDir == null) {
            Context.error(
                'Could not find package "$packageName" in any Haxe classpath. ' +
                'For src/shaders, make sure src is a classpath root and use "shaders".',
                Context.currentPos()
            );
        }

        var modulePaths:Array<String> = [];
        collectModules(packageDir, packageName.split("."), modulePaths);
        modulePaths.sort(Reflect.compare);

        var shaders:Array<RegisteredShader> = [];
        var seen = new Map<String, Bool>();

        for (modulePath in modulePaths) {
            // Typing the module makes Haxe include it and runs its build macros.
            var moduleType:Type;
            try {
                moduleType = Context.getType(modulePath);
            } catch (e:Dynamic) {
                // Some .hx files in the folder may be helpers, not shader classes.
                continue;
            }

            switch (Context.follow(moduleType)) {
                case TInst(classRef, _):
                    var cls = classRef.get();
                    if (!extendsShader(cls)) continue;

                    var classPath = cls.pack.concat([cls.name]).join(".");
                    if (seen.exists(classPath)) continue;
                    seen.set(classPath, true);

                    var fragmentSource = getShaderSource(cls.meta.get(), ":shaderSourceFrag");
                    if (fragmentSource == null) {
                        Context.error(
                            'Shader class "$classPath" is missing @:shaderSourceFrag("...").',
                            cls.pos
                        );
                    }
                    var vertexSource = getShaderSource(cls.meta.get(), ":shaderSourceVert");
                    var uniforms = readUniforms(cls);

                    shaders.push({
                        classPath: classPath,
                        shaderName: cls.name,
                        vertexSource: vertexSource,
                        fragmentSource: fragmentSource,
                        uniforms: uniforms
                    });

                default:
                    // Module's main type is not a class.
                    continue;
            }
        }

        shaders.sort(function(a, b) return Reflect.compare(a.classPath, b.classPath));

        var definitionExprs:Array<Expr> = [];
        var entryExprs:Array<Expr> = [];
        for (shader in shaders) {
            definitionExprs.push(createDefinitionExpression(shader));
            entryExprs.push(createRegistryEntryExpression(shader));
        }

        replaceStaticField(
            fields,
            "definitions",
            macro :Array<ShaderDefinition>,
            macro $a{definitionExprs}
        );
        replaceStaticField(
            fields,
            "entries",
            macro :Array<ShaderRegistryEntry>,
            macro $a{entryExprs}
        );

        return fields;
    }

    private static function findPackageDirectory(packageName:String):Null<String> {
        var relative = packageName.split(".").join("/");
        for (root in Context.getClassPath()) {
            var candidate = Path.join([root, relative]);
            if (FileSystem.exists(candidate) && FileSystem.isDirectory(candidate)) {
                return Path.normalize(candidate);
            }
        }
        return null;
    }

    private static function collectModules(
        directory:String,
        packageParts:Array<String>,
        output:Array<String>
    ):Void {
        var entries = FileSystem.readDirectory(directory);
        entries.sort(Reflect.compare);

        for (entry in entries) {
            var fullPath = Path.join([directory, entry]);
            if (FileSystem.isDirectory(fullPath)) {
                if (!StringTools.startsWith(entry, ".") && entry != "macro") {
                    collectModules(fullPath, packageParts.concat([entry]), output);
                }
            } else if (StringTools.endsWith(entry, ".hx")) {
                var name = entry.substr(0, entry.length - 3);
                // A Haxe module's main type normally matches its filename.
                output.push(packageParts.concat([name]).join("."));
            }
        }
    }

    private static function extendsShader(cls:ClassType):Bool {
        var parent = cls.superClass;
        while (parent != null) {
            var c = parent.t.get();
            if (c.name == "Shader" && c.pack.length == 0) return true;
            parent = c.superClass;
        }
        return false;
    }

    private static function readUniforms(cls:ClassType):Array<UniformInfo> {
        var result:Array<UniformInfo> = [];
        var names = new Map<String, Bool>();
        var indices = new Map<Int, String>();

        for (field in cls.fields.get()) {
            var meta = findMetadata(field.meta.get(), ":uniform");
            if (meta == null) continue;
            if (meta.params == null || meta.params.length != 2) {
                Context.error('@:uniform requires ("GLSLName", index).', meta.pos);
            }

            var name = extractString(meta.params[0]);
            var index = extractInt(meta.params[1]);
            var format = getUniformFormat(field.type, meta.pos);

            if (index < 0) Context.error("Uniform indices must be zero or greater.", meta.pos);
            if (names.exists(name)) Context.error('Duplicate uniform name "$name".', meta.pos);
            if (indices.exists(index)) {
                Context.error(
                    'Uniform index $index is already used by "${indices.get(index)}".',
                    meta.pos
                );
            }

            names.set(name, true);
            indices.set(index, name);
            result.push({name: name, index: index, format: format});
        }

        result.sort(function(a, b) return a.index - b.index);
        return result;
    }

    private static function getUniformFormat(type:Type, pos:Position):UniformFormat {
        return switch (Context.follow(type)) {
            case TInst(ref, params) if (ref.get().name == "Uniform"):
                if (params.length != 1) {
                    Context.error("Uniform<T> must have exactly one type parameter.", pos);
                }
                formatFromType(params[0], pos);
            default:
                Context.error("@:uniform fields must have type Uniform<T>.", pos);
                UniformFormat.Float;
        }
    }

    private static function formatFromType(type:Type, pos:Position):UniformFormat {
        var name = typeName(type);
        return switch (name) {
            case "Float": UniformFormat.Float;
            case "Vec2": UniformFormat.Vec2;
            case "Vec3": UniformFormat.Vec3;
            case "Vec4": UniformFormat.Vec4;
            case "Matrix": UniformFormat.Mat4;
            case "Int": UniformFormat.Int;
            case "Bool": UniformFormat.Bool;
            case "Texture": UniformFormat.Sampler2D;
            default:
                Context.error('Unsupported shader uniform value type "$name".', pos);
                UniformFormat.Float;
        }
    }

    private static function typeName(type:Type):String {
        return switch (Context.follow(type)) {
            case TInst(ref, _): ref.get().name;
            case TEnum(ref, _): ref.get().name;
            case TAbstract(ref, _): ref.get().name;
            case TType(ref, _): ref.get().name;
            case TFun(_, _): "Function";
            case TAnonymous(_): "Anonymous";
            case TDynamic(_): "Dynamic";
            case TMono(_): "Dynamic";
            case TLazy(resolve): typeName(resolve());
        }
    }

    private static function validateUniformField(field:Field, pos:Position):Void {
        switch (field.kind) {
            case FVar(type, _):
                if (type == null) {
                    Context.error("@:uniform field must explicitly declare Uniform<T>.", pos);
                }
                switch (type) {
                    case TPath(path):
                        if (path.name != "Uniform" || path.params == null || path.params.length != 1) {
                            Context.error("@:uniform fields must have type Uniform<T>.", pos);
                        }
                    default:
                        Context.error("@:uniform fields must have type Uniform<T>.", pos);
                }
            default:
                Context.error("@:uniform must be applied to a variable.", pos);
        }
    }

    private static function getShaderSource(
        metadata:Array<MetadataEntry>,
        metadataName:String
    ):Null<String> {
        for (meta in metadata) {
            if (meta.name != metadataName) continue;
            if (meta.params == null || meta.params.length != 1) {
                Context.error(metadataName + ' requires exactly one string argument.', meta.pos);
            }
            return extractString(meta.params[0]);
        }
        return null;
    }

    private static function findMetadata(
        metadata:Array<MetadataEntry>,
        name:String
    ):Null<MetadataEntry> {
        for (meta in metadata) if (meta.name == name) return meta;
        return null;
    }

    private static function extractString(expr:Expr):String {
        return switch (expr.expr) {
            case EConst(CString(value)): value;
            default:
                Context.error("Expected a string literal.", expr.pos);
                "";
        }
    }

    private static function extractInt(expr:Expr):Int {
        return switch (expr.expr) {
            case EConst(CInt(value)):
                var parsed = Std.parseInt(value);
                if (parsed == null) {
                    Context.error("Expected an integer literal.", expr.pos);
                    0;
                } else parsed;
            default:
                Context.error("Expected an integer literal.", expr.pos);
                0;
        }
    }

    private static function createDefinitionExpression(shader:RegisteredShader):Expr {
        var uniformExprs:Array<Expr> = [];
        for (uniform in shader.uniforms) {
            uniformExprs.push(macro {
                name: $v{uniform.name},
                index: $v{uniform.index},
                format: $e{uniformFormatExpression(uniform.format)}
            });
        }

        return macro {
            shaderClass: $v{shader.classPath},
            name: $v{shader.shaderName},
            vertexSource: $v{shader.vertexSource},
            fragmentSource: $v{shader.fragmentSource},
            uniforms: $a{uniformExprs}
        };
    }

    private static function createRegistryEntryExpression(shader:RegisteredShader):Expr {
        var classExpr = macro $p{shader.classPath.split(".")};
        var definitionExpr = createDefinitionExpression(shader);
        return macro {
            definition: $e{definitionExpr},
            setProgramInfoIndex: function(index:Int):Void {
                $e{classExpr}.programInfoIndex = index;
            }
        };
    }

    private static function uniformFormatExpression(format:UniformFormat):Expr {
        return switch (format) {
            case UniformFormat.Float: macro UniformFormat.Float;
            case UniformFormat.Vec2: macro UniformFormat.Vec2;
            case UniformFormat.Vec3: macro UniformFormat.Vec3;
            case UniformFormat.Vec4: macro UniformFormat.Vec4;
            case UniformFormat.Mat2: macro UniformFormat.Mat2;
            case UniformFormat.Mat3: macro UniformFormat.Mat3;
            case UniformFormat.Mat4: macro UniformFormat.Mat4;
            case UniformFormat.Int: macro UniformFormat.Int;
            case UniformFormat.IntVec2: macro UniformFormat.IntVec2;
            case UniformFormat.IntVec3: macro UniformFormat.IntVec3;
            case UniformFormat.IntVec4: macro UniformFormat.IntVec4;
            case UniformFormat.Bool: macro UniformFormat.Bool;
            case UniformFormat.BoolVec2: macro UniformFormat.BoolVec2;
            case UniformFormat.BoolVec3: macro UniformFormat.BoolVec3;
            case UniformFormat.BoolVec4: macro UniformFormat.BoolVec4;
            case UniformFormat.Sampler2D: macro UniformFormat.Sampler2D;
            case UniformFormat.SamplerCube: macro UniformFormat.SamplerCube;
        };
    }

    private static function hasField(fields:Array<Field>, name:String):Bool {
        for (field in fields) if (field.name == name) return true;
        return false;
    }

    private static function replaceStaticField(
        fields:Array<Field>,
        name:String,
        type:ComplexType,
        value:Expr
    ):Void {
        var replacement:Field = {
            name: name,
            access: [APublic, AStatic],
            kind: FVar(type, value),
            pos: Context.currentPos()
        };

        for (i in 0...fields.length) {
            if (fields[i].name == name) {
                fields[i] = replacement;
                return;
            }
        }
        fields.push(replacement);
    }

    #end
}
