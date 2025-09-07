    private function getUniformSetter(type:UniformFormat, location:UniformLocation):Dynamic {
        return switch (type) {
            case UniformFormat.SAMPLER_2D:
                sampler2DSetter(location);
            case UniformFormat.SAMPLER_CUBE:
                sampler2DSetter(location);
            case UniformFormat.FLOAT:
                floatSetter(location);
            case UniformFormat.VEC2:
                floatVec2Setter(location);
            case UniformFormat.VEC3:
                floatVec3Setter(location);
            case UniformFormat.VEC4:
                floatVec4Setter(location);
            case UniformFormat.MAT2:
                floatMat2Setter(location);
            case UniformFormat.MAT3:
                floatMat3Setter(location);
            case UniformFormat.MAT4:
                floatMat4Setter(location);
            default:
                throw "Unknown uniform type: " + type;
        }
    }

    private function floatSetter(location:UniformLocation) {
        return function(v) {
            gl.uniform1f(location, v);
        };
    }

    private function floatArraySetter(location:UniformLocation) {
        return function(v) {
            gl.uniform1fv(location, v);
        };
    }

    private function floatVec2Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform2fv(location, v);
        };
    }

    private function floatVec3Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform3fv(location, v);
        };
    }

    private function floatVec4Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform4fv(location, v);
        };
    }

    private function intSetter(location:UniformLocation) {
        return function(v) {
            gl.uniform1i(location, v);
        };
    }
    private function intArraySetter(location:UniformLocation) {
        return function(v) {
            gl.uniform1iv(location, v);
        };
    }

    private function intVec2Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform2iv(location, v);
        };
    }

    private function intVec3Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform3iv(location, v);
        };
    }

    private function intVec4Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform4iv(location, v);
        };
    }

    private function uintSetter(location:UniformLocation) {
        return function(v) {
            gl.uniform1ui(location, v);
        };
    }

    private function uintArraySetter(location:UniformLocation) {
        return function(v) {
            gl.uniform1uiv(location, v);
        };
    }

    private function uintVec2Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform2uiv(location, v);
        };
    }

    private function uintVec3Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform3uiv(location, v);
        };
    }

    private function uintVec4Setter(location:UniformLocation) {
        return function(v) {
            gl.uniform4uiv(location, v);
        };
    }

    private function floatMat2Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix2fv(location, false, v);
        };
    }

    private function floatMat3Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix3fv(location, false, v);
        };
    }

    private function floatMat4Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix4fv(location, false, v);
        };
    }

    private function floatMat23Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix2x3fv(location, false, v);
        };
    }

    private function floatMat32Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix3x2fv(location, false, v);
        };
    }

    private function floatMat24Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix2x4fv(location, false, v);
        };
    }

    private function floatMat42Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix4x2fv(location, false, v);
        };
    }

    private function floatMat34Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix3x4fv(location, false, v);
        };
    }

    private function floatMat43Setter(location:UniformLocation) {
        return function(v) {
            gl.uniformMatrix4x3fv(location, false, v);
        };
    }

    private function sampler2DSetter(location:UniformLocation) {
        return function(v) {
            gl.uniform1i(location, v);
        };
    }
}