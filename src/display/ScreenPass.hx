package display;

import GL;
import Renderer;
import Texture;
import data.BlendFactors;
import data.Vertices;
import data.Indices;
import math.Matrix;

@:shader("postprocess")
class ScreenPass extends DisplayObject {

    public var framebufferId:Null<Int> = null;
    public var width:Int;
    public var height:Int;

    public function new(renderer:Renderer, width:Int, height:Int) {
        this.width = width;
        this.height = height;
        var vertices = new Vertices([
            -1.0,  1.0,  0.0, 1.0,
            -1.0, -1.0,  0.0, 0.0,
             1.0, -1.0,  1.0, 0.0,
             1.0,  1.0,  1.0, 1.0
        ]);

        var indices = new Indices([0, 1, 2, 0, 2, 3]);
        super(renderer, vertices, indices);

        framebufferId = renderer.createFramebuffer(width, height);

        __verticesToRender = 4;
        __indicesToRender = 6;

        mode = GL.TRIANGLES;

        needsBufferUpdate = true;
        
        blending = {
            source: BlendFactors.SRC_ALPHA,
            destination: BlendFactors.ONE_MINUS_SRC_ALPHA
        };
    }

    public function bindFramebuffer(renderer:Renderer):Void {
        renderer.bindFramebuffer(framebufferId);
    }

    public function unbindFramebuffer(renderer:Renderer):Void {
        renderer.unbindFramebuffer(framebufferId);
    }

    public function resize(renderer:Renderer, width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) {
            return;
        }

        this.width = width;
        this.height = height;

        if (framebufferId != null) {
            renderer.disposeFramebuffer(framebufferId);
        }

        framebufferId = renderer.createFramebuffer(width, height);
    }

    public function dispose(renderer:Renderer):Void {
        if (framebufferId != null) {
            renderer.disposeFramebuffer(framebufferId);
            framebufferId = null;
        }
    }

    override public function updateBuffers(renderer:Renderer):Void {
        super.updateBuffers(renderer);
	}

    override public function render(renderer:Renderer, cameraMatrix:Matrix, cameraDirty:Bool):Void {
        uniforms.set("uScreenTexture", 0);

        var framebuffer = renderer.framebuffers.get(framebufferId);

        if (framebuffer.colorTexture != null) {
            setTexture(framebuffer.colorTexture);
        } else {
            setTexture(null);
        }

        super.render(renderer, cameraMatrix, cameraDirty);
    }
}