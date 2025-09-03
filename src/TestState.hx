import display.Cube;
import display.Triangle;

/**
 * A test state that demonstrates the State/Entity system
 * This replaces the hardcoded test objects that were in the Renderer
 */
class TestState extends State {
    
    public function new(app:App) {
        super("TestState", app);
    }
    
    override public function onActivate():Void {
        super.onActivate();
        
        trace("TestState activated - creating test entities");
        
        // Configure this state's camera for 3D perspective
        camera.ortho = false;
        camera.x = 0.0;
        camera.y = 0.0;
        camera.z = 3.0; // Match the original camera distance
        camera.pitch = 0.0;
        camera.yaw = 0.0;
        camera.roll = 0.0;
        
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Request ProgramInfos from the Renderer (proper separation of concerns)
        var triangleProgramInfo = renderer.createProgramInfo("Triangle", Triangle.getVertexShader(), Triangle.getFragmentShader());
        var cubeProgramInfo = renderer.createProgramInfo("Cube", Cube.getVertexShader(), Cube.getFragmentShader());
        
        // Create a test triangle entity (replaces hardcoded triangle in Renderer)
        var triangleDisplay = new Triangle(triangleProgramInfo);
        triangleDisplay.x = -0.5;
        triangleDisplay.y = 0.0;
        triangleDisplay.z = 0.0;
        var triangleEntity = new Entity("triangle", triangleDisplay);
        addEntity(triangleEntity);
        
        // Create a test cube entity (replaces hardcoded cube in Renderer)
        var cubeDisplay = new Cube(cubeProgramInfo);
        cubeDisplay.x = 0.5;
        cubeDisplay.y = 0.0;
        cubeDisplay.z = 0.0;
        var cubeEntity = new Entity("cube", cubeDisplay);
        addEntity(cubeEntity);
        
        trace("TestState setup complete - " + entities.length + " entities created");
        trace("Camera configured: Z=" + camera.z + ", ortho=" + camera.ortho + " (original distance)");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Add some simple rotation animation to demonstrate entities updating
        for (entity in entities) {
            if (entity.displayObject != null) {
                // Very slow rotation: 1 degree per second (convert to radians)
                entity.rotationY += deltaTime * (1.0 * Math.PI / 180.0);
                
                // Simple static Y position (no floating for now)
                entity.y = 0.0;
            }
        }
    }
    
    override public function onDeactivate():Void {
        trace("TestState deactivated");
        super.onDeactivate();
    }
}
