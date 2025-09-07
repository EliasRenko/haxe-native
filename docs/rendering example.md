public function render(displayObject:DisplayObject):Void {
        if (displayObject.vertices.length == 0) {
            return;
        }

        __render(displayObject);
		__drawCalls ++;
    }

    private function __render(drawable:DisplayObject):Void {
        
        var _buffer = __buffers[drawable.bufferId];

        if (_buffer == null) {
            throw "No buffer found for bufferId: " + drawable.bufferId + ". Ensure that the buffer is properly allocated.";
        }
        
        var currentProgram:Program = __programs[drawable.programInfo.programId];
        gl.useProgram(currentProgram);

        gl.bindBuffer(Context.ARRAY_BUFFER, _buffer.vertexBuffer);
		//gl.bufferData(Context.ARRAY_BUFFER, Float32Array.fromArray(drawable.vertices).getData(), Context.STATIC_DRAW);
        gl.bufferSubData(Context.ARRAY_BUFFER, 0, Float32Array.fromArray(drawable.vertices).getData());

        __renderUniforms(drawable.programInfo, drawable.uniforms);
		__renderAttributes(drawable.programInfo);
		__renderTextures(drawable.programInfo, drawable);

		if (drawable.__indicesToRender == 0) {

            gl.drawArrays(drawable.mode, 0, drawable.__verticesToRender);
		}
		else {

            gl.bindBuffer(Context.ELEMENT_ARRAY_BUFFER, _buffer.indexBuffer);
            gl.bufferSubData(Context.ELEMENT_ARRAY_BUFFER, 0, Int32Array.fromArray(drawable.indices).getData());
            gl.drawElements(drawable.mode, drawable.__indicesToRender, Context.UNSIGNED_INT, 0);
            gl.bindBuffer(Context.ELEMENT_ARRAY_BUFFER, null);
		}

        gl.bindBuffer(Context.ARRAY_BUFFER, null);
    }

    private function __renderUniforms(programInfo:ProgramInfo, uniforms:Map<String, Dynamic>):Void {

        // TODO: Improve current function
        for (u in programInfo.uniforms) {

            var uni = uniforms.get(u.name);

            if (uni == null) continue;

			u.setter(uni);
		}
    }

    private function __renderAttributes(programInfo:ProgramInfo):Void {

        var index:Int = 0;
		
        for (i in 0...programInfo.attributes.length) {

            var valuesPerVertex = AttributeFormat.getValuesPerVertex(programInfo.attributes[i].format);

			//setAttributePointer(index, valuesPerVertex, false,  drawable.profile.dataPerVertex * Float32Array.BYTES_PER_ELEMENT, index * Float32Array.BYTES_PER_ELEMENT);
			
            var location = programInfo.attributes[i].location;

            GL.enableVertexAttribArray(location);
		
		    //gl.vertexAttribPointer(index, valuesPerVertex, drawable.profile.attributes[i].format, false, drawable.profile.dataPerVertex * Float32Array.BYTES_PER_ELEMENT, index * Float32Array.BYTES_PER_ELEMENT);
		    GL.vertexAttribPointer(location, valuesPerVertex, Context.FLOAT, false, programInfo.dataPerVertex * Float32Array.BYTES_PER_ELEMENT, index * Float32Array.BYTES_PER_ELEMENT);

            // ** Get the number of values per vertex by calculate the offset on the spot.
            // ** This is done to avoid storing the number of values per vertex in the attribute object.
            // ** Must Remove the `offset` property from the attribute object.

			index += valuesPerVertex;
		}
    }

    private function __renderTextures(programInfo:ProgramInfo, drawable:DisplayObject):Void {

        for (i in 0...programInfo.textures.length) {

			//var name = drawable.profile.textures[i].name;

			//var loc = gl.getUniformLocation(currentProgram, name);
			//var loc = drawable.profile.textures[i].location;

            var x = Context.TEXTURE0 + i;

			gl.activeTexture(x);

            var glTexture = __textures[drawable.textures[i]];

			gl.bindTexture(glTexture.target, glTexture.inner);

            gl.blendFunc(drawable.blendFactors.source, drawable.blendFactors.destination);

            //gl.uniform1i(loc, 0);
            drawable.programInfo.textures[i].setter(i);

			//context.setSamplerState(drawable.textureParams);
		}
    }