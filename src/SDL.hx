package;

import cpp.Star;
import cpp.UInt32;
import cpp.UInt64;
import cpp.ConstCharStar;
import cpp.Pointer;
import cpp.Struct;

import Window;

typedef SDL_PropertiesID = UInt64;

@:keep
@:buildXml(
'<target id="haxe">
   <lib name="C:/Users/efedorenko/Desktop/engine/lib/x64/SDL3.lib"/>
   <lib name="user32.lib"/>
   <lib name="gdi32.lib"/>
   <lib name="winmm.lib"/>
   <lib name="imm32.lib"/>
   <lib name="ole32.lib"/>
   <lib name="oleaut32.lib"/>
   <lib name="shell32.lib"/>
   <lib name="setupapi.lib"/>
   <lib name="version.lib"/>
   <lib name="uuid.lib"/>
</target>
<files id="haxe">
    <compilerflag value="-I../include"/>
</files>')
@:include("SDL3/SDL.h")
extern class SDL {
    
    // ** Init

    @:native("SDL_Init")
    static function init(flags:InitFlag):Bool;

    @:native("SDL_InitSubSystem")
    static function initSubSystem(flags:InitFlag):Bool;

    @:native("SDL_QuitSubSystem")
    static function quitSubSystem(flags:InitFlag):Void;

    @:native("SDL_WasInit")
    static function wasInit(flags:InitFlag):Int;

    @:native("SDL_Quit")
    static function quit():Void;

    @:native("SDL_IsMainThread")
    static function isMainThread():Bool;

    //@:native("SDL_RunOnMainThread")
    //static function runOnMainThread(callback:SDL_MainThreadCallback, userdata:cpp.Star<Dynamic>, wait_complete:Bool):Bool;

    @:native("SDL_SetAppMetadata")
    static function setAppMetadata(appname:cpp.ConstCharStar, appversion:cpp.ConstCharStar, appidentifier:cpp.ConstCharStar):Bool;

    @:native("SDL_SetAppMetadataProperty")
    static function setAppMetadataProperty(name:cpp.ConstCharStar, value:cpp.ConstCharStar):Bool;

    @:native("SDL_GetAppMetadataProperty")
    static function getAppMetadataProperty(name:cpp.ConstCharStar):cpp.ConstCharStar;

    // ** Video

    @:native("SDL_GetVideoDriver")
    static function getVideoDriver(index:Int):String;

    @:native("SDL_GetNumVideoDrivers")
    static function getNumVideoDrivers():Int;

    @:native("SDL_GetWindowSize")
    static function getWindowSize(window:Window, w:Pointer<Int>, h:Pointer<Int>):Bool;

    @:native("SDL_GetWindowSizeInPixels")
    static function getWindowSizeInPixels(window:Window, w:Pointer<Int>, h:Pointer<Int>):Bool;

    // ** 
    
    @:native("SDL_CreateWindow")
    static function createWindow(title:String, w:Int, h:Int, flags:CreateWindowFlag):Window;

    @:native("SDL_SetWindowFullscreen")
    static function setWindowFullscreen(window:Window, fullscreen:Bool):Int;

    @:native("SDL_GetPointerProperty")
    static function getPointerProperty(props:SDL_PropertiesID, name:cpp.ConstCharStar, defaultValue:cpp.RawPointer<Void>):cpp.RawPointer<Void>;

    @:native("SDL_GetWindowProperties")
    static function getWindowProperties(window:Window):SDL_PropertiesID;

    @:native("SDL_GL_CreateContext")
    static function createContext(window:Window):GLContext;

    @:native("SDL_GL_MakeCurrent")
    static function makeCurrent(window:Window, context:GLContext):Void;

    @:native("SDL_GL_GetProcAddress")
    static function getProcAddress(name:ConstCharStar):cpp.RawPointer<Void>;

    @:native("SDL_GL_GetProcAddress")
    static var getProcAddressPtr:(name:ConstCharStar) -> cpp.RawPointer<Void>;

    @:native("SDL_GL_SetAttribute")
    static function setAttribute(attr:SDL_GLAttr, value:Int):Int;

    @:native("SDL_GL_SwapWindow")
    static function swapWindow(window:Window):Void;

    @:native("SDL_PollEvent")
    static function pollEvent(event:Pointer<Event>):Bool;

    @:native("SDL_GetTicks")
    static function getTicks():UInt64;

    static inline function getEvent():Pointer<Event> {
        var event:Pointer<Event> = null;
        untyped __cpp__("SDL_Event __sdl_ev__; {0} = &__sdl_ev__", event);
        return event;
    }

    // ** Erros
    @:native("SDL_GetError")
    static function getError():String;

    // ** Log
    @:native("SDL_SetLogPriorities")
    static function setLogPriorities(priority:SDL_LogPriority):Void;

    @:native("SDL_SetLogPriority")
    static function setLogPriority(category:Int, priority:SDL_LogPriority):Void;

    @:native("SDL_GetLogPriority")
    static function getLogPriority(category:Int):Int;

    @:native("SDL_ResetLogPriorities")
    static function resetLogPriorities():Void;

    @:native("SDL_SetLogPriorityPrefix")
    static function setLogPriorityPrefix(priority:Int, prefix:cpp.ConstCharStar):Bool;

    @:native("SDL_Log")
    static function log(text:String):Void;

    @:native("SDL_LogTrace")
    static function logTrace(category:Int, text:String):Void;

    @:native("SDL_LogVerbose")
    static function logVerbose(category:Int, text:String):Void;

    @:native("SDL_LogDebug")
    static function logDebug(category:Int, text:String):Void;

    @:native("SDL_LogInfo")
    static function logInfo(category:Int, text:String):Void;

    @:native("SDL_LogWarn")
    static function logWarn(category:Int, text:String):Void;

    @:native("SDL_LogError")
    static function logError(category:Int, text:String):Void;

    @:native("SDL_LogCritical")
    static function logCritical(category:Int, text:String):Void;

    @:native("SDL_LogMessage")
    static function logMessage(category:Int, priority:SDL_LogPriority, text:String):Void;

    @:native("SDL_SetLogOutputFunction")
    static function setLogOutputFunction(callback:cpp.RawPointer<Void>, userdata:cpp.RawPointer<Void>):Void;

    //@:native("SDL_LogMessageV")
    //static function logMessageV(category:Int, priority:SDL_LogPriority, text:String, ?):Void;

    // ** Platform

    @:native("SDL_GetPlatform")
    public static function getPlatform():String;

    // ** Filesystem
    @:native("SDL_GetBasePath")
    static function getBasePath():String;
    @:native("SDL_GetPrefPath")
    static function getPrefPath(org:String, app:String):String;
    @:native("SDL_GetUserFolder")
    static function getUserFolder(folder:SDL_Folder):String;

    @:native("SDL_CreateDirectory")
    static function createDirectory(path:String):Bool;

    // @:native("SDL_EnumerateDirectory")
    // static function enumerateDirectory(
    //     path:cpp.ConstCharStar,
    //     callback:cpp.Star<cpp.Void>, // You may want to typedef SDL_EnumerateDirectoryCallback
    //     userdata:cpp.Star<cpp.Void>
    // ):Bool;

    @:native("SDL_RemovePath")
    static function removePath(path:String):Bool;

    @:native("SDL_RenamePath")
    static function renamePath(oldpath:String, newpath:String):Bool;

    @:native("SDL_CopyFile")
    static function copyFile(oldpath:String, newpath:String):Bool;

    @:native("SDL_GetPathInfo")
    static function getPathInfo(path:String, info:cpp.Star<cpp.Void>):Bool; // You may want to typedef SDL_PathInfo

    @:native("SDL_GlobDirectory")
    static function globDirectory(
        path:cpp.ConstCharStar,
        pattern:cpp.ConstCharStar,
        flags:Int, // SDL_GlobFlags
        count:cpp.Star<Int>
    ):cpp.Pointer<cpp.Pointer<cpp.Char>>;

    @:native("SDL_GetCurrentDirectory")
    static function getCurrentDirectory():cpp.Pointer<cpp.Char>;

    // ** IO stream
    @:native("SDL_LoadFile")
    static function loadFile(path:String, datasize:Star<UInt64>):cpp.Pointer<cpp.Char>;

    @:native("SDL_free")
    static function free(ptr:cpp.Pointer<cpp.Char>):Void;

    // ** Window flags
    @:native("SDL_WINDOW_FULLSCREEN")
    static var WINDOW_FULLSCREEN(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_OPENGL")
    static var WINDOW_OPENGL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_OCCLUDED")
    static var WINDOW_OCCLUDED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_HIDDEN")
    static var WINDOW_HIDDEN(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_BORDERLESS")
    static var WINDOW_BORDERLESS(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_RESIZABLE")
    static var WINDOW_RESIZABLE(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MINIMIZED")
    static var WINDOW_MINIMIZED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MAXIMIZED")
    static var WINDOW_MAXIMIZED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_GRABBED")
    static var WINDOW_MOUSE_GRABBED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_INPUT_FOCUS")
    static var WINDOW_INPUT_FOCUS(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_FOCUS")
    static var WINDOW_MOUSE_FOCUS(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_EXTERNAL")
    static var WINDOW_EXTERNAL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MODAL")
    static var WINDOW_MODAL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_HIGH_PIXEL_DENSITY")
    static var WINDOW_HIGH_PIXEL_DENSITY(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_CAPTURE")
    static var WINDOW_MOUSE_CAPTURE(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_RELATIVE_MODE")
    static var WINDOW_MOUSE_RELATIVE_MODE(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_ALWAYS_ON_TOP")
    static var WINDOW_ALWAYS_ON_TOP(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_UTILITY")
    static var WINDOW_UTILITY(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_TOOLTIP")
    static var WINDOW_TOOLTIP(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_POPUP_MENU")
    static var WINDOW_POPUP_MENU(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_KEYBOARD_GRABBED")
    static var WINDOW_KEYBOARD_GRABBED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_VULKAN")
    static var WINDOW_VULKAN(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_METAL")
    static var WINDOW_METAL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_TRANSPARENT")
    static var WINDOW_TRANSPARENT(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_NOT_FOCUSABLE")
    static var WINDOW_NOT_FOCUSABLE(default, null):CreateWindowFlag;

    // ** Folders

    @:native("SDL_FOLDER_HOME")
    static var FOLDER_HOME(default, null):SDL_Folder;
    @:native("SDL_FOLDER_DESKTOP")
    static var FOLDER_DESKTOP(default, null):SDL_Folder;
    @:native("SDL_FOLDER_DOCUMENTS")
    static var FOLDER_DOCUMENTS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_DOWNLOADS")
    static var FOLDER_DOWNLOADS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_MUSIC")
    static var FOLDER_MUSIC(default, null):SDL_Folder;
    @:native("SDL_FOLDER_PICTURES")
    static var FOLDER_PICTURES(default, null):SDL_Folder;
    @:native("SDL_FOLDER_PUBLICSHARE")
    static var FOLDER_PUBLICSHARE(default, null):SDL_Folder;
    @:native("SDL_FOLDER_SAVEDGAMES")
    static var FOLDER_SAVEDGAMES(default, null):SDL_Folder;
    @:native("SDL_FOLDER_SCREENSHOTS")
    static var FOLDER_SCREENSHOTS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_TEMPLATES")
    static var FOLDER_TEMPLATES(default, null):SDL_Folder;
    @:native("SDL_FOLDER_VIDEOS")
    static var FOLDER_VIDEOS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_COUNT")
    static var FOLDER_COUNT(default, null):SDL_Folder;
    
    // ** GL Attrs

    @:native("SDL_GL_RED_SIZE")
    static var GL_RED_SIZE(default, null):SDL_GLAttr;
    @:native("SDL_GL_CONTEXT_MAJOR_VERSION")
    static var GL_CONTEXT_MAJOR_VERSION(default, null):SDL_GLAttr;
    @:native("SDL_GL_CONTEXT_MINOR_VERSION")
    static var GL_CONTEXT_MINOR_VERSION(default, null):SDL_GLAttr;

    @:native("SDL_GL_CONTEXT_PROFILE_MASK")
    static var GL_CONTEXT_PROFILE_MASK(default, null):SDL_GLAttr;
    @:native("SDL_GL_CONTEXT_PROFILE_CORE")
    static var GL_CONTEXT_PROFILE_CORE(default, null):Int;

    // ** Log priorities

    @:native("SDL_LOG_PRIORITY_INVALID")
    static var LOG_PRIORITY_INVALID(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_TRACE")
    static var LOG_PRIORITY_TRACE(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_VERBOSE")
    static var LOG_PRIORITY_VERBOSE(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_DEBUG")
    static var LOG_PRIORITY_DEBUG(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_INFO")
    static var LOG_PRIORITY_INFO(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_WARN")
    static var LOG_PRIORITY_WARN(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_ERROR")
    static var LOG_PRIORITY_ERROR(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_CRITICAL")
    static var LOG_PRIORITY_CRITICAL(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_COUNT")
    static var LOG_PRIORITY_COUNT(default, null):SDL_LogPriority;


    // ** Event types

    // Unused events
    @:native("SDL_EVENT_FIRST")
    static var EVENT_FIRST(default, null):SDL_EventType;

    // Application events
    @:native("SDL_EVENT_QUIT")
    static var EVENT_QUIT(default, null):SDL_EventType;
    @:native("SDL_EVENT_TERMINATING")
    static var EVENT_TERMINATING(default, null):SDL_EventType;
    @:native("SDL_EVENT_LOW_MEMORY")
    static var EVENT_LOW_MEMORY(default, null):SDL_EventType;
    @:native("SDL_EVENT_WILL_ENTER_BACKGROUND")
    static var EVENT_WILL_ENTER_BACKGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_DID_ENTER_BACKGROUND")
    static var EVENT_DID_ENTER_BACKGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_WILL_ENTER_FOREGROUND")
    static var EVENT_WILL_ENTER_FOREGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_DID_ENTER_FOREGROUND")
    static var EVENT_DID_ENTER_FOREGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_LOCALE_CHANGED")
    static var EVENT_LOCALE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_SYSTEM_THEME_CHANGED")
    static var EVENT_SYSTEM_THEME_CHANGED(default, null):SDL_EventType;

    // Display events
    @:native("SDL_EVENT_DISPLAY_ORIENTATION")
    static var EVENT_DISPLAY_ORIENTATION(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_ADDED")
    static var EVENT_DISPLAY_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_REMOVED")
    static var EVENT_DISPLAY_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_MOVED")
    static var EVENT_DISPLAY_MOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED")
    static var EVENT_DISPLAY_DESKTOP_MODE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED")
    static var EVENT_DISPLAY_CURRENT_MODE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED")
    static var EVENT_DISPLAY_CONTENT_SCALE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_FIRST")
    static var EVENT_DISPLAY_FIRST(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_LAST")
    static var EVENT_DISPLAY_LAST(default, null):SDL_EventType;

    // Window events
    @:native("SDL_EVENT_WINDOW_SHOWN")
    static var EVENT_WINDOW_SHOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_HIDDEN")
    static var EVENT_WINDOW_HIDDEN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_EXPOSED")
    static var EVENT_WINDOW_EXPOSED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MOVED")
    static var EVENT_WINDOW_MOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_RESIZED")
    static var EVENT_WINDOW_RESIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED")
    static var EVENT_WINDOW_PIXEL_SIZE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_METAL_VIEW_RESIZED")
    static var EVENT_WINDOW_METAL_VIEW_RESIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MINIMIZED")
    static var EVENT_WINDOW_MINIMIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MAXIMIZED")
    static var EVENT_WINDOW_MAXIMIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_RESTORED")
    static var EVENT_WINDOW_RESTORED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MOUSE_ENTER")
    static var EVENT_WINDOW_MOUSE_ENTER(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MOUSE_LEAVE")
    static var EVENT_WINDOW_MOUSE_LEAVE(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_FOCUS_GAINED")
    static var EVENT_WINDOW_FOCUS_GAINED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_FOCUS_LOST")
    static var EVENT_WINDOW_FOCUS_LOST(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_CLOSE_REQUESTED")
    static var EVENT_WINDOW_CLOSE_REQUESTED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_HIT_TEST")
    static var EVENT_WINDOW_HIT_TEST(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_ICCPROF_CHANGED")
    static var EVENT_WINDOW_ICCPROF_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_DISPLAY_CHANGED")
    static var EVENT_WINDOW_DISPLAY_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED")
    static var EVENT_WINDOW_DISPLAY_SCALE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_SAFE_AREA_CHANGED")
    static var EVENT_WINDOW_SAFE_AREA_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_OCCLUDED")
    static var EVENT_WINDOW_OCCLUDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_ENTER_FULLSCREEN")
    static var EVENT_WINDOW_ENTER_FULLSCREEN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_LEAVE_FULLSCREEN")
    static var EVENT_WINDOW_LEAVE_FULLSCREEN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_DESTROYED")
    static var EVENT_WINDOW_DESTROYED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_HDR_STATE_CHANGED")
    static var EVENT_WINDOW_HDR_STATE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_FIRST")
    static var EVENT_WINDOW_FIRST(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_LAST")
    static var EVENT_WINDOW_LAST(default, null):SDL_EventType;

    // Keyboard events
    @:native("SDL_EVENT_KEY_DOWN")
    static var EVENT_KEY_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEY_UP")
    static var EVENT_KEY_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_TEXT_EDITING")
    static var EVENT_TEXT_EDITING(default, null):SDL_EventType;
    @:native("SDL_EVENT_TEXT_INPUT")
    static var EVENT_TEXT_INPUT(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEYMAP_CHANGED")
    static var EVENT_KEYMAP_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEYBOARD_ADDED")
    static var EVENT_KEYBOARD_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEYBOARD_REMOVED")
    static var EVENT_KEYBOARD_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_TEXT_EDITING_CANDIDATES")
    static var EVENT_TEXT_EDITING_CANDIDATES(default, null):SDL_EventType;

    // Mouse events
    @:native("SDL_EVENT_MOUSE_MOTION")
    static var EVENT_MOUSE_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_BUTTON_DOWN")
    static var EVENT_MOUSE_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_BUTTON_UP")
    static var EVENT_MOUSE_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_WHEEL")
    static var EVENT_MOUSE_WHEEL(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_ADDED")
    static var EVENT_MOUSE_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_REMOVED")
    static var EVENT_MOUSE_REMOVED(default, null):SDL_EventType;

    // Joystick events
    @:native("SDL_EVENT_JOYSTICK_AXIS_MOTION")
    static var EVENT_JOYSTICK_AXIS_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BALL_MOTION")
    static var EVENT_JOYSTICK_BALL_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_HAT_MOTION")
    static var EVENT_JOYSTICK_HAT_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BUTTON_DOWN")
    static var EVENT_JOYSTICK_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BUTTON_UP")
    static var EVENT_JOYSTICK_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_ADDED")
    static var EVENT_JOYSTICK_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_REMOVED")
    static var EVENT_JOYSTICK_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BATTERY_UPDATED")
    static var EVENT_JOYSTICK_BATTERY_UPDATED(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_UPDATE_COMPLETE")
    static var EVENT_JOYSTICK_UPDATE_COMPLETE(default, null):SDL_EventType;

    // Gamepad events
    @:native("SDL_EVENT_GAMEPAD_AXIS_MOTION")
    static var EVENT_GAMEPAD_AXIS_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_BUTTON_DOWN")
    static var EVENT_GAMEPAD_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_BUTTON_UP")
    static var EVENT_GAMEPAD_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_ADDED")
    static var EVENT_GAMEPAD_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_REMOVED")
    static var EVENT_GAMEPAD_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_REMAPPED")
    static var EVENT_GAMEPAD_REMAPPED(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN")
    static var EVENT_GAMEPAD_TOUCHPAD_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION")
    static var EVENT_GAMEPAD_TOUCHPAD_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_TOUCHPAD_UP")
    static var EVENT_GAMEPAD_TOUCHPAD_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_SENSOR_UPDATE")
    static var EVENT_GAMEPAD_SENSOR_UPDATE(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_UPDATE_COMPLETE")
    static var EVENT_GAMEPAD_UPDATE_COMPLETE(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED")
    static var EVENT_GAMEPAD_STEAM_HANDLE_UPDATED(default, null):SDL_EventType;

    // Touch events
    @:native("SDL_EVENT_FINGER_DOWN")
    static var EVENT_FINGER_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_FINGER_UP")
    static var EVENT_FINGER_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_FINGER_MOTION")
    static var EVENT_FINGER_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_FINGER_CANCELED")
    static var EVENT_FINGER_CANCELED(default, null):SDL_EventType;

    // Clipboard events
    @:native("SDL_EVENT_CLIPBOARD_UPDATE")
    static var EVENT_CLIPBOARD_UPDATE(default, null):SDL_EventType;

    // Drag and drop events
    @:native("SDL_EVENT_DROP_FILE")
    static var EVENT_DROP_FILE(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_TEXT")
    static var EVENT_DROP_TEXT(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_BEGIN")
    static var EVENT_DROP_BEGIN(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_COMPLETE")
    static var EVENT_DROP_COMPLETE(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_POSITION")
    static var EVENT_DROP_POSITION(default, null):SDL_EventType;

    // Audio hotplug events
    @:native("SDL_EVENT_AUDIO_DEVICE_ADDED")
    static var EVENT_AUDIO_DEVICE_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_AUDIO_DEVICE_REMOVED")
    static var EVENT_AUDIO_DEVICE_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED")
    static var EVENT_AUDIO_DEVICE_FORMAT_CHANGED(default, null):SDL_EventType;

    // Sensor events
    @:native("SDL_EVENT_SENSOR_UPDATE")
    static var EVENT_SENSOR_UPDATE(default, null):SDL_EventType;

    // Pen events
    @:native("SDL_EVENT_PEN_PROXIMITY_IN")
    static var EVENT_PEN_PROXIMITY_IN(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_PROXIMITY_OUT")
    static var EVENT_PEN_PROXIMITY_OUT(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_DOWN")
    static var EVENT_PEN_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_UP")
    static var EVENT_PEN_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_BUTTON_DOWN")
    static var EVENT_PEN_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_BUTTON_UP")
    static var EVENT_PEN_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_MOTION")
    static var EVENT_PEN_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_AXIS")
    static var EVENT_PEN_AXIS(default, null):SDL_EventType;

    // Camera hotplug events
    @:native("SDL_EVENT_CAMERA_DEVICE_ADDED")
    static var EVENT_CAMERA_DEVICE_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_CAMERA_DEVICE_REMOVED")
    static var EVENT_CAMERA_DEVICE_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_CAMERA_DEVICE_APPROVED")
    static var EVENT_CAMERA_DEVICE_APPROVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_CAMERA_DEVICE_DENIED")
    static var EVENT_CAMERA_DEVICE_DENIED(default, null):SDL_EventType;

    // Render events
    @:native("SDL_EVENT_RENDER_TARGETS_RESET")
    static var EVENT_RENDER_TARGETS_RESET(default, null):SDL_EventType;
    @:native("SDL_EVENT_RENDER_DEVICE_RESET")
    static var EVENT_RENDER_DEVICE_RESET(default, null):SDL_EventType;
    @:native("SDL_EVENT_RENDER_DEVICE_LOST")
    static var EVENT_RENDER_DEVICE_LOST(default, null):SDL_EventType;

    // Private events
    @:native("SDL_EVENT_PRIVATE0")
    static var EVENT_PRIVATE0(default, null):SDL_EventType;
    @:native("SDL_EVENT_PRIVATE1")
    static var EVENT_PRIVATE1(default, null):SDL_EventType;
    @:native("SDL_EVENT_PRIVATE2")
    static var EVENT_PRIVATE2(default, null):SDL_EventType;
    @:native("SDL_EVENT_PRIVATE3")
    static var EVENT_PRIVATE3(default, null):SDL_EventType;

    // Internal events
    @:native("SDL_EVENT_POLL_SENTINEL")
    static var EVENT_POLL_SENTINEL(default, null):SDL_EventType;

    // User events
    @:native("SDL_EVENT_USER")
    static var EVENT_USER(default, null):SDL_EventType;
    @:native("SDL_EVENT_LAST")
    static var EVENT_LAST(default, null):SDL_EventType;


    // ** Init flags

    @:native("SDL_INIT_VIDEO")
    static var INIT_VIDEO(default,null):InitFlag;
}

// @:native("SDL_Event")
// extern class Event {}

// @:native("::cpp::Reference<SDL_Window>")
// extern class Window {}

@:native("::cpp::Reference<SDL_GLContext>")
extern class GLContext {}

@:native("SDL_Event")
@:structAccess
extern class Event {

    var type:SDL_EventType;
    // var window:WindowEvent;
    // var key:KeyboardEvent;
    // var edit:TextEditingEvent;
    // var text:TextInputEvent;
    // var motion:MouseMotionEvent;
    // var button:MouseButtonEvent;
    // var wheel:MouseWheelEvent;
    // var jaxis:JoyAxisEvent;
    // var jball:JoyBallEvent;
    // var jhat:JoyHatEvent;
    // var jbutton:JoyButtonEvent;
    // var jdevice:JoyDeviceEvent;
    // var caxis:ControllerAxisEvent;
    // var cbutton:ControllerButtonEvent;
    // var cdevice:ControllerDeviceEvent;
    // var adevice:AudioDeviceEvent;
    // var quit:QuitEvent;
    // // var user:UserEvent;
    // // var syswm:SysWMEvent;
    // var tfinger:TouchFingerEvent;
    // var mgesture:MultiGestureEvent;
    // var dgesture:DollarGestureEvent;
    // var drop:DropEvent;
}

typedef PtrEvent = Pointer<Event>;

abstract InitFlag(UInt64) {
    @:op(A|B) static function _(a:InitFlag, b:InitFlag):InitFlag;
}

abstract CreateWindowFlag(UInt64) {
    @:op(A|B) static function _(a:CreateWindowFlag, b:CreateWindowFlag):CreateWindowFlag;
}

abstract SDL_GLAttr(UInt32) {
    @:op(A|B) static function _(a:SDL_GLAttr, b:SDL_GLAttr):SDL_GLAttr;
}

abstract SDL_LogPriority(UInt32) {
    @:op(A|B) static function _(a:SDL_LogPriority, b:SDL_LogPriority):SDL_LogPriority;
}

abstract SDL_EventType(UInt32) {
    @:op(A|B) static function _(a:SDL_EventType, b:SDL_EventType):SDL_EventType;
}

abstract SDL_Folder(UInt32) {
    @:op(A|B) static function _(a:SDL_Folder, b:SDL_Folder):SDL_Folder;
}

