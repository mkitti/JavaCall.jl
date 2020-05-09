struct JavaMetaClass{T}
    ptr::Ptr{Nothing}
end

#The metaclass, sort of equivalent to a the
JavaMetaClass(T, ptr) = JavaMetaClass{T}(ptr)

mutable struct JavaObject{T}
    ptr::Ptr{Nothing}

    #This below is ugly. Once we stop supporting 0.5, this can be replaced by
    # function JavaObject{T}(ptr) where T
    function JavaObject{T}(ptr) where T
        j = new{T}(ptr)
        finalizer(deleteref, j)
        return j
    end

    #replace with: JavaObject{T}(argtypes::Tuple, args...) where T
    JavaObject{T}(argtypes::Tuple, args...) where {T} = jnew(T, argtypes, args...)
end

JavaObject(T, ptr) = JavaObject{T}(ptr)
JavaObject{T}() where {T} = JavaObject{T}((),)

function deleteref(x::JavaObject)
    if x.ptr == C_NULL; return; end
    if !JNI.is_env_loaded(); return; end;
    JNI.DeleteLocalRef(x.ptr)
    x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize
    return
end


"""
```
isnull(obj::JavaObject)
```
Checks if the passed JavaObject is null or not

### Args
* obj: The object of type JavaObject

### Returns
true if the passed object is null else false
"""
isnull(obj::JavaObject) = obj.ptr == C_NULL
isnull(obj::Ptr{Nothing}) = obj == C_NULL

"""
```
isnull(obj::JavaMetaClass)
```
Checks if the passed JavaMetaClass is null or not

### Args
* obj: The object of type JavaMetaClass

### Returns
true if the passed object is null else false
"""
isnull(obj::JavaMetaClass) = obj.ptr == C_NULL

const JClass = JavaObject{Symbol("java.lang.Class")}
const JObject = JavaObject{Symbol("java.lang.Object")}
const JMethod = JavaObject{Symbol("java.lang.reflect.Method")}
const JThread = JavaObject{Symbol("java.lang.Thread")}
const JClassLoader = JavaObject{Symbol("java.lang.ClassLoader")}
const JString = JavaObject{Symbol("java.lang.String")}

function JString(str::AbstractString)
    jstring = JNI.NewStringUTF(String(str))
    if jstring == C_NULL
        geterror()
    else
        return JString(jstring)
    end
end

# jvalue(v::Integer) = int64(v) << (64-8*sizeof(v))
jvalue(v::Integer) = Int64(v)
jvalue(v::Float32) = jvalue(reinterpret(Int32, v))
jvalue(v::Float64) = jvalue(reinterpret(Int64, v))
jvalue(v::Ptr) = jvalue(Int(v))


function _jimport(juliaclass)
    for str ∈ [" ", "(", ")"]
        juliaclass = replace(juliaclass, str=>"")
    end
    :(JavaObject{Symbol($juliaclass)})
end

macro jimport(class::Expr)
    juliaclass = sprint(Base.show_unquoted, class)
    _jimport(juliaclass)
end
macro jimport(class::Symbol)
    juliaclass = string(class)
    _jimport(juliaclass)
end
macro jimport(class::AbstractString)
    _jimport(class)
end


function jnew(T::Symbol, argtypes::Tuple, args...)
    assertroottask_or_goodenv()
    sig = method_signature(Nothing, argtypes...)
    jmethodId = JNI.GetMethodID(metaclass(T).ptr, String("<init>"), sig)
    if jmethodId == C_NULL
        throw(JavaCallError("No constructor for $T with signature $sig"))
    end
    return  _jcall(metaclass(T), jmethodId, JNI.NewObjectA, JavaObject{T}, argtypes, args...)
end

# Call static methods
function jcall(typ::Type{JavaObject{T}}, method::AbstractString, rettype::Type, argtypes::Tuple,
               args... ) where T
    assertroottask_or_goodenv()
    sig = method_signature(rettype, argtypes...)
    metaT = metaclass(T)
    jmethodId = JNI.GetStaticMethodID(metaT.ptr, String(method), sig)
    jmethodId==C_NULL && geterror(true)
    _jcall(metaT, jmethodId, C_NULL, rettype, argtypes, args...)
end

# Call instance methods
function jcall(obj::JavaObject, method::AbstractString, rettype::Type, argtypes::Tuple, args... )
    assertroottask_or_goodenv()
    sig = method_signature(rettype, argtypes...)
    jmethodId = JNI.GetMethodID(metaclass(obj).ptr, String(method), sig)
    jmethodId==C_NULL && geterror(true)
    _jcall(obj, jmethodId, C_NULL, rettype,  argtypes, args...)
end

function jfield(typ::Type{JavaObject{T}}, field::AbstractString, fieldType::Type) where T
    assertroottask_or_goodenv()
    jfieldID  = JNI.GetStaticFieldID(metaclass(T).ptr, String(field), signature(fieldType))
    jfieldID==C_NULL && geterror(true)
    _jfield(metaclass(T), jfieldID, fieldType)
end

function jfield(obj::JavaObject, field::AbstractString, fieldType::Type)
    assertroottask_or_goodenv()
    jfieldID  = JNI.GetFieldID(metaclass(obj).ptr, String(field), signature(fieldType))
    jfieldID==C_NULL && geterror(true)
    _jfield(obj, jfieldID, fieldType)
end

for (x, y, z) in [(:jboolean, :(JNI.GetBooleanField), :(JNI.GetStaticBooleanField)),
                  (:jchar,    :(JNI.GetCharField),    :(JNI.GetStaticCharField))   ,
                  (:jbyte,    :(JNI.GetByteField),    :(JNI.GetStaticBypeField))   ,
                  (:jshort,   :(JNI.GetShortField),   :(JNI.GetStaticShortField))  ,
                  (:jint,     :(JNI.GetIntField),     :(JNI.GetStaticIntField))    ,
                  (:jlong,    :(JNI.GetLongField),    :(JNI.GetStaticLongField))   ,
                  (:jfloat,   :(JNI.GetFloatField),   :(JNI.GetStaticFloatField))  ,
                  (:jdouble,  :(JNI.GetDoubleField),  :(JNI.GetStaticDoubleField)) ]

    m = quote
        function _jfield(obj, jfieldID::Ptr{Nothing}, fieldType::Type{$(x)})
            callmethod = ifelse( typeof(obj)<:JavaObject, $y , $z )
            result = callmethod(obj.ptr, jfieldID)
            result==C_NULL && geterror()
            return convert_result(fieldType, result)
        end
    end
    eval(m)
end

function _jfield(obj, jfieldID::Ptr{Nothing}, fieldType::Type)
    callmethod = ifelse( typeof(obj)<:JavaObject, JNI.GetObjectField , JNI.GetStaticObjectField )
    result = callmethod(obj.ptr, jfieldID)
    result==C_NULL && geterror()
    return convert_result(fieldType, result)
end

#Generate these methods to satisfy ccall's compile time constant requirement
#_jcall for primitive and Nothing return types
for (x, y, z) in [(:jboolean, :(JNI.CallBooleanMethodA), :(JNI.CallStaticBooleanMethodA)),
                  (:jchar,    :(JNI.CallCharMethodA),    :(JNI.CallStaticCharMethodA))   ,
                  (:jbyte,    :(JNI.CallByteMethodA),    :(JNI.CallStaticByteMethodA))   ,
                  (:jshort,   :(JNI.CallShortMethodA),   :(JNI.CallStaticShortMethodA))  ,
                  (:jint,     :(JNI.CallIntMethodA),     :(JNI.CallStaticIntMethodA))    ,
                  (:jlong,    :(JNI.CallLongMethodA),    :(JNI.CallStaticLongMethodA))   ,
                  (:jfloat,   :(JNI.CallFloatMethodA),   :(JNI.CallStaticFloatMethodA))  ,
                  (:jdouble,  :(JNI.CallDoubleMethodA),  :(JNI.CallStaticDoubleMethodA)) ,
                  (:Nothing,  :(JNI.CallVoidMethodA),    :(JNI.CallStaticVoidMethodA))   ]
    m = quote
        function _jcall(obj, jmethodId::Ptr{Nothing}, callmethod::Ptr{Nothing}, rettype::Type{$(x)},
                        argtypes::Tuple, args...)
            if callmethod == C_NULL #!
                callmethod = ifelse( typeof(obj)<:JavaObject, $y , $z )
            end
            @assert callmethod != C_NULL
            @assert jmethodId != C_NULL
            isnull(obj) && throw(JavaCallError("Attempt to call method on Java NULL"))
            savedArgs, convertedArgs = convert_args(argtypes, args...)
            result = callmethod(obj.ptr, jmethodId, convertedArgs)
            result==C_NULL && geterror()
            result == nothing && (return)
            return convert_result(rettype, result)
        end
    end
    eval(m)
end

#_jcall for Object return types
#obj -- receiver - Class pointer or object prointer
#jmethodId -- Java method ID
#callmethod -- the C method pointer to call
function _jcall(obj, jmethodId::Ptr{Nothing}, callmethod::Union{Function,Ptr{Nothing}}, rettype::Type, argtypes::Tuple,
                args...)
    if callmethod == C_NULL
        callmethod = ifelse(typeof(obj)<:JavaObject,
                            JNI.CallObjectMethodA  ,
                            JNI.CallStaticObjectMethodA)
    end
    @assert callmethod != C_NULL
    @assert jmethodId != C_NULL
    isnull(obj) && error("Attempt to call method on Java NULL")
    savedArgs, convertedArgs = convert_args(argtypes, args...)
    result = callmethod(obj.ptr, jmethodId, convertedArgs)
    result==C_NULL && geterror()
    return convert_result(rettype, result)
end


global const _jmc_cache = Dict{Symbol, JavaMetaClass}()

function _metaclass(class::Symbol)
    jclass=javaclassname(class)
    jclassptr = JNI.FindClass(jclass)
    jclassptr == C_NULL && throw(JavaCallError("Class Not Found $jclass"))
    return JavaMetaClass(class, jclassptr)
end

function metaclass(class::Symbol)
    if !haskey(_jmc_cache, class)
        _jmc_cache[class] = _metaclass(class)
    end
    return _jmc_cache[class]
end

metaclass(::Type{JavaObject{T}}) where {T} = metaclass(T)
metaclass(::JavaObject{T}) where {T} = metaclass(T)

javaclassname(class::Symbol) = replace(string(class), "."=>"/")

function geterror(allow=false)
    isexception = JNI.ExceptionCheck()

    if isexception == JNI_TRUE
        jthrow = JNI.ExceptionOccurred()
        jthrow==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        JNI.ExceptionDescribe() #Print java stackstrace to stdout
        JNI.ExceptionClear()
        jclass = JNI.FindClass("java/lang/Throwable")
        jclass==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        jmethodId=JNI.GetMethodID(jclass, "toString", "()Ljava/lang/String;")
        jmethodId==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        res = JNI.CallObjectMethodA(jthrow, jmethodId, Int[])
        res==C_NULL && throw(JavaCallError("Java Exception thrown, but no details could be retrieved from the JVM"))
        msg = unsafe_string(JString(res))
        JNI.DeleteLocalRef(jthrow)
        throw(JavaCallError(string("Error calling Java: ",msg)))
    else
        if allow==false
            return #No exception pending, legitimate NULL returned from Java
        else
            throw(JavaCallError("Null from Java. Not known how"))
        end
    end
end

#get the JNI signature string for a method, given its
#return type and argument types
function method_signature(rettype, argtypes...)
    s=IOBuffer()
    write(s, "(")
    for arg in argtypes
        write(s, signature(arg))
    end
    write(s, ")")
    write(s, signature(rettype))
    return String(take!(s))
end


#get the JNI signature string for a given type
function signature(arg::Type)
    if arg === jboolean
        return "Z"
    elseif arg === jbyte
        return "B"
    elseif arg === jchar
        return "C"
    elseif arg === jshort
        return "S"
    elseif arg === jint
        return "I"
    elseif arg === jlong
        return "J"
    elseif arg === jfloat
        return "F"
    elseif arg === jdouble
        return "D"
    elseif arg === Nothing
        return "V"
    elseif arg <: Array
        dims = "[" ^ ndims(arg)
        return string(dims, signature(eltype(arg)))
    end
end

signature(arg::Type{JavaObject{T}}) where {T} = string("L", javaclassname(T), ";")
