package display;

import GL;
import Renderer;
import data.Shader;
import shaders.DepthVisualizationShader;

class DepthVisualizationScreenPass extends ScreenPass {
    public function new(renderer:Renderer, width:Int, height:Int) {
        super(
            renderer,
            width,
            height,
            [
                {
                    attachment: GL.COLOR_ATTACHMENT0,
                    internalFormat: GL.RGBA8,
                    format: GL.RGBA,
                    type: GL.UNSIGNED_BYTE
                },
                {
                    attachment: GL.DEPTH_ATTACHMENT,
                    internalFormat: GL.DEPTH_COMPONENT24,
                    format: GL.DEPTH_COMPONENT,
                    type: GL.UNSIGNED_INT
                }
            ],
            false,
            "Depth texture"
        );
        refreshDepthTexture(renderer);
    }

    override private function assignShader():Shader {
        return new DepthVisualizationShader();
    }

    override public function onFramebufferResized(renderer:Renderer):Void {
        refreshDepthTexture(renderer);
    }

    private function refreshDepthTexture(renderer:Renderer):Void {
        shader.setUniform("uDepthTexture", renderer.getFramebufferTexture(framebufferId, GL.DEPTH_ATTACHMENT));
    }
}
