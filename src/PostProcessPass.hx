package;

import GL;
import DisplayObject;
import data.BlendFactors;
import data.Indices;
import data.Vertices;
import math.Matrix;

class PostProcessPass {
    public var framebuffer:Framebuffer = null;
    public var shader:ProgramInfo = null;
    public var screenQuad:ScreenQuadDisplayObject = null;
    public var enabled:Bool = true;

    private var __renderer:Renderer;
    private var __width:Int;
    private var __height:Int;

    public function new(renderer:Renderer, width:Int, height:Int) {
        __renderer = renderer;
        __width = width;
        __height = height;
        initialize(renderer);
    }

    public function initialize(renderer:Renderer):Void {
        if (framebuffer != null) {
            framebuffer.dispose();
            framebuffer = null;
        }

        if (__width <= 0 || __height <= 0) {
            return;
        }

        framebuffer = new Framebuffer(__width, __height, false, true);
        framebuffer.initialize(renderer);

        createScreenQuad(renderer);
    }

    public function begin():Void {
        if (framebuffer != null) {
            framebuffer.bind();
        }
    }

    public function end():Void {
        if (framebuffer != null) {
            framebuffer.unbind();
        }

        var size = __renderer.app.window.getWindowSizeInPixels();
        GL.viewport(0, 0, size.width, size.height);
    }

    public function render(renderer:Renderer):Void {
        if (!enabled || framebuffer == null || screenQuad == null || shader == null) {
            return;
        }

        if (framebuffer.colorTexture != null) {
            screenQuad.setTexture(framebuffer.colorTexture);
        } else {
            screenQuad.setTexture(null);
        }

        renderer.renderDisplayObject(screenQuad, new Matrix(), true);
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) {
            return;
        }

        __width = width;
        __height = height;
        initialize(__renderer);
    }

    public function dispose():Void {
        if (screenQuad != null) {
            screenQuad.release(__renderer);
            screenQuad = null;
        }

        if (framebuffer != null) {
            framebuffer.dispose();
            framebuffer = null;
        }

        shader = null;
    }

    private function createScreenQuad(renderer:Renderer):Void {
        var vertShader = renderer.app.resources.getText("shaders/postprocess.vert");
        var fragShader = renderer.app.resources.getText("shaders/postprocess.frag");
        
        shader = renderer.createProgramInfo("postprocess", vertShader, fragShader);
        screenQuad = new ScreenQuadDisplayObject(renderer);
    }
}

@:shader("postprocess")
class ScreenQuadDisplayObject extends DisplayObject {
    public function new(renderer:Renderer) {
        var vertices = new Vertices([
            -1.0,  1.0,  0.0, 1.0,
            -1.0, -1.0,  0.0, 0.0,
             1.0, -1.0,  1.0, 0.0,
             1.0,  1.0,  1.0, 1.0
        ]);

        var indices = new Indices([0, 1, 2, 0, 2, 3]);
        super(renderer, vertices, indices);

        __verticesToRender = 4;
        __indicesToRender = 6;
        mode = GL.TRIANGLES;
        needsBufferUpdate = true;
        blending = {
            source: BlendFactors.SRC_ALPHA,
            destination: BlendFactors.ONE_MINUS_SRC_ALPHA
        };
    }

    override public function render(cameraMatrix:Matrix, cameraDirty:Bool):Void {
        uniforms.set("uScreenTexture", 0);
    }
}
