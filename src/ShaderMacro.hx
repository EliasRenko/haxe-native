package;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Build macro applied to every DisplayObject subclass via @:autoBuild.
 *
 * Usage on a concrete subclass:
 *   @:shader("name")
 *   class MySprite extends DisplayObject { ... }
 *
 * The macro injects one override:
 *   override public function getShaderName() return "name";
 *
 * The state that owns this object is responsible for pre-compiling the
 * ProgramInfo under that name before constructing any instance.
 * DisplayObject.new() simply calls renderer.getProgramInfo(name).
 */
class ShaderMacro {
    #if macro
    public static function build():Array<Field> {
        var fields = Context.getBuildFields();
        var cls    = Context.getLocalClass().get();

        var shaderMetas = cls.meta.extract(":shader");
        if (shaderMetas.length == 0) return fields;

        var meta = shaderMetas[0];
        if (meta.params == null || meta.params.length < 1)
            Context.error('@:shader requires exactly 1 argument: ("name")', meta.pos);

        var shaderName = extractString(meta.params[0]);

        fields.push({
            name:   "getShaderName",
            pos:    meta.pos,
            access: [APublic, AOverride],
            kind:   FFun({ args: [], ret: macro :String, expr: macro return $v{shaderName} })
        });

        return fields;
    }

    static function extractString(e:Expr):String {
        return switch e.expr {
            case EConst(CString(s, _)): s;
            default: Context.error("Expected a string literal", e.pos); null;
        }
    }
    #end
}
