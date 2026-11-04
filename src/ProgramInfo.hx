package;

#if js
typedef ProgramInfo           = web.ProgramInfo;
typedef UniformFormat         = web.ProgramInfo.UniformFormat;
#else
typedef ProgramInfo           = native.ProgramInfo;
typedef Program               = native.ProgramInfo.Program;
typedef AttributeInfo         = data.AttributeInfo;
typedef UniformInfo           = data.UniformInfo;
#end
