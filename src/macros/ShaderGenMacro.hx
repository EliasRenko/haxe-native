package macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class ShaderGenMacro {

    public static function patchForTarget(src:String):String {
        if (src == null) return src;
        src = StringTools.trim(src);
        #if js
        var reVersion = ~/#version\s+\d+\s+core/g;
        src = reVersion.replace(src, "#version 300 es\nprecision mediump float;");

        var reDefault = ~/^(\s*uniform\s+\S+\s+\S+)\s*=\s*[^;]+;/gm;
        src = reDefault.replace(src, "$1;");
        #end
        return src;
    }

    public static function extractUniformDefaults(src:String):Map<String, Dynamic> {
        var result:Map<String, Dynamic> = new Map();
        if (src == null) return result;

        var re = ~/^\s*uniform\s+(\S+)\s+(\w+)\s*=\s*([^;]+);/gm;
        var rest = src;
        while (re.match(rest)) {
            var type = re.matched(1);
            var name = re.matched(2);
            var expr = StringTools.trim(re.matched(3));
            var value = parseUniformExpr(type, expr);
            if (value != null) result.set(name, value);
            rest = re.matchedRight();
        }
        return result;
    }

    private static function parseUniformExpr(type:String, expr:String):Dynamic {
        var vecRe = ~/^vec(\d)\(([^)]+)\)/;
        if (vecRe.match(expr)) {
            var n = Std.parseInt(vecRe.matched(1));
            var args = vecRe.matched(2).split(",").map(function(s) return Std.parseFloat(StringTools.trim(s)));
            if (args.length == 1) return [for (_ in 0...n) args[0]];
            return args;
        }

        var value = Std.parseFloat(expr);
        if (!Math.isNaN(value)) return value;
        return null;
    }

    #if macro
    private static var nextShaderId:Int = 0;

    public static function buildId():Array<Field> {
        var fields = Context.getBuildFields();
        var pos = Context.currentPos();

        for (field in fields) {
            if (field.name == "shaderId" || field.name == "programInfoIndex") {
                Context.error(
                    field.name + " is generated automatically.",
                    field.pos
                );
            }
        }

        var id = nextShaderId++;
        var cls = Context.getLocalClass().get();

        cls.meta.add(":shaderId", [macro $v{id}], pos);

        fields.push({
            name: "shaderId",
            access: [APublic, AStatic],
            kind: FVar(macro:Int, macro $v{id}),
            pos: pos
        });
        var indexInitialization = macro this.programInfoIndex = $v{id};
        var hasConstructor = false;

        for (field in fields) {
            if (field.name != "new") continue;
            hasConstructor = true;

            switch (field.kind) {
                case FFun(fn):
                    switch (fn.expr) {
                        case {expr: EBlock(expressions)}:
                            expressions.push(indexInitialization);
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
                    },
                    params: []
                }),
                pos: pos
            });
        }

        return fields;
    }
    #end
}
