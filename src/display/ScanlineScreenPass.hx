package display;

import GL;
import Renderer;
import data.Shader;
import shaders.PostProccessingShader;

class ScanlineScreenPass extends ScreenPass {
    public function new(renderer:Renderer, width:Int, height:Int) {
        super(
            renderer,
            width,
            height,
            [{
                attachment: GL.COLOR_ATTACHMENT0,
                internalFormat: GL.RGBA8,
                format: GL.RGBA,
                type: GL.UNSIGNED_BYTE
            }],
            false,
            "Scanlines + vignette"
        );
    }

    override private function assignShader():Shader {
        return new PostProccessingShader();
    }
}
