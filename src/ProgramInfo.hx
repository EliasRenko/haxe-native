package;

#if js
typedef ProgramInfo           = web.ProgramInfo;
typedef UniformFormat         = web.ProgramInfo.UniformFormat;
#else
typedef ProgramInfo           = native.ProgramInfo;
typedef UniformLocation       = native.ProgramInfo.UniformLocation;
typedef Program               = native.ProgramInfo.Program;
typedef Shader                = native.ProgramInfo.Shader;
typedef AttributeFormat       = native.ProgramInfo.AttributeFormat;
typedef UniformFormat         = native.ProgramInfo.UniformFormat;
typedef AttributeInfo         = native.ProgramInfo.AttributeInfo;
typedef UniformInfo           = native.ProgramInfo.UniformInfo;
#end
