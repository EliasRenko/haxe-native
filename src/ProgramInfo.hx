package;

#if js

typedef ProgramInfo           = web.ProgramInfo;
//typedef UniformLocation       = web.UniformLocation;
// typedef Program               = web.Program;
// typedef Shader                = web.Shader;
// typedef AttributeFormat       = web.AttributeFormat;
// typedef AttributeFormatHelper = web.AttributeFormatHelper;
typedef UniformFormat         = web.ProgramInfo.UniformFormat;
// typedef Attribute             = web.Attribute;
// typedef Uniform               = web.Uniform;

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
