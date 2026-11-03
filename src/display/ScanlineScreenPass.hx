package display;

import GL;
import Renderer;
import shaders.PostProccessingShader;

class ScanlineScreenPass extends ScreenPass {
    public function new(renderer:Renderer, width:Int, height:Int) {
        super(
            renderer,
            width,
            height,
            new PostProccessingShader(),
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

}
