package macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class ShaderGenMacro {
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
}
#end
