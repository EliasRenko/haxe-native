package display;

import GL;
import Renderer;
import types.BlendFactors;
import data.Vertices;
import data.Indices;
import data.Shader;

typedef ScreenPassTextureConfig = {
    final attachment:Int;
    final internalFormat:Int;
    final format:Int;
    final type:Int;
}

abstract class ScreenPass extends DisplayObject {

    public var framebufferId:Int = -1;
    public var width:Int;
    public var height:Int;
    public var label:String;

	public function new(renderer:Renderer, width:Int, height:Int, textureConfigs:Array<ScreenPassTextureConfig>, useDepthRenderbuffer:Bool = false, label:String = "Screen Pass") {
        this.width = width;
        this.height = height;
        this.label = label;
        var vertices = new Vertices([
            -1.0,  1.0,  0.0, 1.0,
            -1.0, -1.0,  0.0, 0.0,
             1.0, -1.0,  1.0, 0.0,
             1.0,  1.0,  1.0, 1.0
        ]);

        var indices = new Indices([0, 1, 2, 0, 2, 3]);
        super(renderer, vertices, indices);

        try {
            framebufferId = renderer.createFramebuffer(width, height, textureConfigs, useDepthRenderbuffer);
        } catch (error:Dynamic) {
            release(renderer);
            throw error;
        }
        shader.setUniform("uScreenTexture", renderer.getFramebufferTexture(framebufferId, GL.COLOR_ATTACHMENT0));

        mode = GL.TRIANGLES;

        __needsBufferUpdate = true;
        
        blending = {
            source: BlendFactors.SRC_ALPHA,
            destination: BlendFactors.ONE_MINUS_SRC_ALPHA
        };
    }

    private function assignShader():Shader {
        throw "ScreenPass requires a concrete screen shader";
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

        renderer.resizeFramebuffer(framebufferId, width, height);
        this.width = width;
        this.height = height;
        shader.setUniform("uScreenTexture", renderer.getFramebufferTexture(framebufferId, GL.COLOR_ATTACHMENT0));
        onFramebufferResized(renderer);
    }

    @:noCompletion
    public function onFramebufferResized(renderer:Renderer):Void {
    }

    public function dispose(renderer:Renderer):Void {
        if (framebufferId >= 0) {
            renderer.disposeFramebuffer(framebufferId);
            framebufferId = -1;
        }
    }

    override public function updateBuffers(renderer:Renderer):Void {
        super.updateBuffers(renderer);
	}

    public function render(renderer:Renderer):Void {
        updateBuffers(renderer);

		// 1. Get the program info for the current shader program
        var programInfo = renderer.getProgramInfo(shader.programInfoIndex);

		// 2. Use the shader program (binds the program and VAO)
		renderer.useProgram(programInfo);

		// 3. Bind the buffers (VAO) for this object
		renderer.bindBuffers(__bufferId, programInfo.vertexStride);

		// 4. Set the blending factors for transparency
		renderer.setBlendFunction(blending.source, blending.destination);

		// 5. Set the uniform values for the shader program
		renderer.renderUniforms(programInfo, shader);

		// 6. Draw the object using the specified mode and count
		renderer.drawElements(mode, indices.length);
    }
}