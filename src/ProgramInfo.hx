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
typedef UniformLocation       = native.UniformLocation;
typedef Program               = native.Program;
typedef Shader                = native.Shader;
typedef AttributeFormat       = native.AttributeFormat;
typedef AttributeFormatHelper = native.AttributeFormatHelper;
typedef UniformFormat         = native.UniformFormat;
typedef Attribute             = native.Attribute;
typedef Uniform               = native.Uniform;

#end
