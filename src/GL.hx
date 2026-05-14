package;

#if js
typedef GL = web.GL;
#elseif cpp
typedef GL = native.GL;
#end
