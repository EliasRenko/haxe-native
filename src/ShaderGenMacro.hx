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
 */
private typedef UniformInfo = {
    var name:String;
    var typeName:String;
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
            access: [APublic, AStatic],
            kind: FVar(macro:Int, macro $v{id}),
            pos: pos
        });

        var cls = Context.getLocalClass().get();
        var classPath = cls.pack.concat([cls.name]);
        var indexInitialization = macro this.programInfoIndex = $v{id};
        var typeInitialization = macro this.shaderType = $p{classPath};
        var hasConstructor = false;
        for (field in fields) {
            if (field.name != "new") continue;
            hasConstructor = true;
            switch (field.kind) {
                case FFun(fn):
                    switch (fn.expr) {
                        case {expr: EBlock(expressions)}:
                            expressions.push(indexInitialization);
                            expressions.push(typeInitialization);
                            fn.expr = {expr: EBlock(expressions), pos: field.pos};
                        default:
                            Context.error(
                                "Shader constructor body must be a block.",
                                field.pos
                            );
                    }
                default:
                    Context.error("Shader constructor must be a function.", field.pos);
            }
        }
        if (!hasConstructor) {
            fields.push({
                name: "new",
                access: [APublic],
                kind: FFun({
                    args: [],
                    ret: null,
                    expr: macro {
                        super();
                        this.programInfoIndex = $v{id};
                        this.shaderType = $p{classPath};
                    },
                    params: []
                }),
                pos: pos
            });
        }

        Context.info(
            'Assigned shader ID $id',
            pos
        );

        return fields;
    }

    /** Applied automatically to Shader subclasses through @:autoBuild. */
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
        readUniformMetadata(cls.meta.get());

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
        return readUniformMetadata(cls.meta.get());
    }

    private static function readUniformMetadata(
        metadata:Array<MetadataEntry>
    ):Array<UniformInfo> {
        var result:Array<UniformInfo> = [];
        var names = new Map<String, Bool>();

        for (meta in metadata) {
            if (meta.name != ":uniform") continue;
            if (meta.params == null || meta.params.length != 2) {
                Context.error(
                    '@:uniform requires ("GLSLName", Type).',
                    meta.pos
                );
            }

            var name = extractString(meta.params[0]);
            var typeName = extractUniformTypeName(meta.params[1]);
            var format = formatFromTypeName(typeName, meta.params[1].pos);
            var index = result.length;

            if (names.exists(name)) Context.error('Duplicate uniform name "$name".', meta.pos);

            names.set(name, true);
            result.push({
                name: name,
                typeName: typeName,
                index: index,
                format: format
            });
        }

        return result;
    }

    private static function extractUniformTypeName(expr:Expr):String {
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

    private static function formatFromTypeName(
        name:String,
        pos:Position
    ):UniformFormat {
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

    private static function extractString(expr:Expr):String {
        return switch (expr.expr) {
            case EConst(CString(value)): value;
            default:
                Context.error("Expected a string literal.", expr.pos);
                "";
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
