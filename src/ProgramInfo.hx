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
typedef AttributeFormatHelper = native.ProgramInfo.AttributeFormatHelper;
typedef UniformFormat         = native.ProgramInfo.UniformFormat;
typedef Attribute             = native.ProgramInfo.Attribute;
typedef Uniform               = native.ProgramInfo.Uniform;

#end
