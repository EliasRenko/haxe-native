package display;

import Renderer;

class PostProcessing {
    public var enabled:Bool = true;
    public var activePass(get, null):ScreenPass;

    private var __renderer:Renderer;
    private var __passes:Array<ScreenPass> = [];
    private var __activePassIndex:Int = 0;

    public function new(renderer:Renderer) {
        __renderer = renderer;

        var size = renderer.app.window.getWindowSizeInPixels();
        try {
            __passes.push(new ScanlineScreenPass(renderer, size.width, size.height));
            __passes.push(new GrayscaleScreenPass(renderer, size.width, size.height));
            __passes.push(new DepthVisualizationScreenPass(renderer, size.width, size.height));
        } catch (error:Dynamic) {
            releasePasses();
            throw error;
        }
    }

    public function cycle(delta:Int):Void {
        if (__passes.length == 0) {
            throw "Post-processing screen passes are not initialized";
        }

        __activePassIndex = (__activePassIndex + delta) % __passes.length;
        if (__activePassIndex < 0) {
            __activePassIndex += __passes.length;
        }

        __renderer.app.log.info(
            Log.LogCategory.RENDERER,
            "Selected screen pass " + (__activePassIndex + 1) + "/" + __passes.length
                + ": " + activePass.label
        );
    }

    public function resize(width:Int, height:Int):Void {
        for (screenPass in __passes) {
            screenPass.resize(__renderer, width, height);
        }
    }

    public function release():Void {
        releasePasses();
    }

    private function releasePasses():Void {
        for (screenPass in __passes) {
            screenPass.dispose(__renderer);
            screenPass.release(__renderer);
        }
        __passes = [];
    }

    private function get_activePass():ScreenPass {
        return __passes.length > 0 ? __passes[__activePassIndex] : null;
    }
}
