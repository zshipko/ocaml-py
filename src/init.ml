open Ctypes
open Foreign

type pyobject = S.pyobject
let pyobject : pyobject Ctypes.typ = ptr void

type wchar_string = unit ptr
let wchar_string : wchar_string typ = ptr void

module Init(V : S.VERSION) = struct
    let from =
        (* Try to open a bunch of different permutations to find the correct library
         * TODO: conside just using the output of pkg-config or something more definitive *)
        let flags = Dl.[RTLD_NOW; RTLD_GLOBAL] in
        try
            Dl.(dlopen ~filename:("lib" ^ V.lib ^ ".so") ~flags)
        with _ -> try
            Dl.(dlopen ~filename:("lib" ^ V.lib ^ ".dylib") ~flags)
        with _ -> try
            Dl.(dlopen ~filename:("lib" ^ V.lib ^ "m.so") ~flags)
        with _ -> try
            Dl.(dlopen ~filename:("lib" ^ V.lib ^ "m.dylib") ~flags)
        with _ -> try
            Dl.(dlopen ~filename:("lib" ^ V.lib) ~flags)
        with _ ->
            Dl.(dlopen ~filename:(V.lib) ~flags)

    let _Py_NoneStruct = foreign_value ~from "_Py_NoneStruct" void
    let _PyObject_RichCompareBool = foreign ~from "PyObject_RichCompareBool" (pyobject @-> pyobject @-> int @-> returning bool)
    let _PyMem_RawFree = foreign ~from "PyMem_RawFree" (ptr void @-> returning void)
    let _Py_DecodeLocale = foreign ~from "Py_DecodeLocale" (string @-> ptr void @-> returning wchar_string)
    let _Py_SetProgramName = foreign ~from "Py_SetProgramName" (wchar_string @-> returning void)
    let _PySys_SetArgvEx = foreign ~from "PySys_SetArgvEx" (int @-> ptr wchar_string @-> int @-> returning void)

    (* Iter *)
    let _PyObject_GetIter = foreign ~from "PyObject_GetIter" (pyobject @-> returning pyobject)
    let _PyIter_Next = foreign ~from "PyIter_Next" (pyobject @-> returning pyobject)

    (* Object *)
    let _PyObject_Str = foreign ~from "PyObject_Str" (pyobject @-> returning pyobject)
    let _PyObject_Bytes = foreign ~from "PyObject_Bytes" (pyobject @-> returning pyobject)
    let _PyObject_Length = foreign ~from "PyObject_Length" (pyobject @-> returning int64_t)
    let _PyObject_Call = foreign ~from "PyObject_Call" (pyobject @-> pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_GetItem = foreign ~from "PyObject_GetItem" (pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_DelItem = foreign ~from "PyObject_DelItem" (pyobject @-> pyobject @-> returning int)
    let _PyObject_SetItem = foreign ~from "PyObject_SetItem" (pyobject @-> pyobject @-> pyobject @-> returning int)
    let _PyObject_GetAttr = foreign ~from "PyObject_GenericGetAttr" (pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_SetAttr = foreign ~from "PyObject_GenericSetAttr" (pyobject @-> pyobject @-> pyobject @-> returning int)
    let _PyObject_HasAttr = foreign ~from "PyObject_HasAttr" (pyobject @-> pyobject @-> returning bool)

    (* Unicode *)
    let _PyUnicode_AsUTF8 = foreign ~from "PyUnicode_AsUTF8" (pyobject @-> returning string)
    let _PyUnicode_FromStringAndSize = foreign ~from "PyUnicode_FromStringAndSize" (string @-> int64_t @-> returning pyobject)

    (* Bytes *)
    let _PyBytes_AsString = foreign ~from "PyBytes_AsString" (pyobject @-> returning string)
    let _PyBytes_FromStringAndSize = foreign ~from "PyBytes_FromStringAndSize" (string @-> int64_t @-> returning pyobject)

    (* Long *)
    let _PyLong_AsLong = foreign ~from "PyLong_AsLong" (pyobject @-> returning int)
    let _PyLong_FromLong = foreign ~from "PyLong_FromLong" (int @-> returning pyobject)
    let _PyLong_AsLongLong = foreign ~from "PyLong_AsLongLong" (pyobject @-> returning int64_t)
    let _PyLong_FromLongLong = foreign ~from "PyLong_FromLongLong" (int64_t @-> returning pyobject)

    (* Float *)
    let _PyFloat_AsDouble = foreign ~from "PyFloat_AsDouble" (pyobject @-> returning double)
    let _PyFloat_FromDouble = foreign ~from "PyFloat_FromDouble" (double @-> returning pyobject)

    (* Bool *)
    let _PyObject_IsTrue = foreign ~from "PyObject_IsTrue" (pyobject @-> returning int)
    let _PyBool_FromLong = foreign ~from "PyBool_FromLong" (int @-> returning pyobject)

    (* Interpeter *)
    let _Py_IncRef = foreign ~from "Py_IncRef" (pyobject @-> returning void)
    let _Py_DecRef = foreign ~from "Py_DecRef" (pyobject @-> returning void)
    let _Py_InitializeEx = foreign ~from "Py_InitializeEx" (int @-> returning void)
    let _Py_Finalize = foreign ~from "Py_Finalize" (void @-> returning void)
    let _PyEval_InitThreads = foreign ~from "PyEval_InitThreads" (void @-> returning void)
    let _PyRun_SimpleStringFlags = foreign ~from "PyRun_SimpleStringFlags" (string @-> ptr void @-> returning bool)
    let _PyRun_StringFlags = foreign ~from "PyRun_StringFlags" (string @-> int @-> pyobject @-> pyobject @-> ptr void @-> returning pyobject)
    let _PyErr_Clear = foreign ~from "PyErr_Clear" (void @-> returning void)
    let _PyErr_Fetch = foreign ~from "PyErr_Fetch" (ptr pyobject @-> ptr pyobject @-> ptr pyobject @-> returning int)
    let _PyErr_Occurred = foreign ~from "PyErr_Occurred" (void @-> returning int)

    (* Module *)
    let _PyModule_GetDict = foreign ~from "PyModule_GetDict" (pyobject @-> returning pyobject)
    let _PyImport_AddModule = foreign ~from "PyImport_AddModule" (string @-> returning pyobject)
    let _PyImport_ImportModule = foreign ~from "PyImport_ImportModule" (string @-> returning pyobject)
    let _PyImport_ReloadModule = foreign ~from "PyImport_ReloadModule" (pyobject @-> returning pyobject)
    let _PyImport_GetModuleDict = foreign ~from "PyImport_GetModuleDict" (void @-> returning pyobject)

    (* Dict *)
    let _PyDict_New = foreign ~from "PyDict_New" (void @-> returning pyobject)
    let _PyDict_Items = foreign ~from "PyDict_Items" (pyobject @-> returning pyobject)
    let _PyDict_Values = foreign ~from "PyDict_Values" (pyobject @-> returning pyobject)
    let _PyDict_Keys = foreign ~from "PyDict_Keys" (pyobject @-> returning pyobject)
    let _PyDict_Contains = foreign ~from "PyDict_Contains" (pyobject @-> pyobject @-> returning int)
    let _PyDict_Merge = foreign ~from "PyDict_Merge" (pyobject @-> pyobject @-> bool @-> returning int)
    let _PyDict_Copy = foreign ~from "PyDict_Copy" (pyobject @-> returning pyobject)
    let _PyDict_Clear = foreign ~from "PyDict_Clear" (pyobject @-> returning void)

    (* Tuple *)
    let _PyTuple_New = foreign ~from "PyTuple_New" (int64_t @-> returning pyobject)
    let _PyTuple_SetItem = foreign ~from "PyTuple_SetItem" (pyobject @-> int64_t @-> pyobject @-> returning int)

    (* List *)
    let _PyList_New = foreign ~from "PyList_New" (int64_t @-> returning pyobject)
    let _PyList_SetItem = foreign ~from "PyList_SetItem" (pyobject @-> int64_t @-> pyobject @-> returning int)
    let _PyList_Insert = foreign ~from "PyList_Insert" (pyobject @-> int64_t @-> pyobject @-> returning int)
    let _PyList_Append = foreign ~from "PyList_Append" (pyobject @-> pyobject @-> returning int)
    let _PyList_GetSlice = foreign ~from "PyList_GetSlice" (pyobject @-> int64_t @-> int64_t @-> returning pyobject)
    let _PyList_SetSlice = foreign ~from "PyList_SetSlice" (pyobject @-> int64_t @-> int64_t @-> pyobject @-> returning int)
    let _PyList_Sort = foreign ~from "PyList_Sort" (pyobject @-> returning int)
    let _PyList_Reverse = foreign ~from "PyList_Reverse" (pyobject @-> returning int)
    let _PyList_AsTuple = foreign ~from "PyList_AsTuple" (pyobject @-> returning pyobject)

    (* Set *)
    let _PySet_New = foreign ~from "PySet_New" (pyobject @-> returning pyobject)

    (* Sequence *)
    let _PySequence_Concat = foreign ~from "PySequence_Concat" (pyobject @-> pyobject @-> returning pyobject)
    let _PySequence_InPlaceConcat = foreign ~from "PySequence_InPlaceConcat" (pyobject @-> pyobject @-> returning pyobject)
    let _PySequence_Contains = foreign ~from "PySequence_Contains" (pyobject @-> pyobject @-> returning int)

    (* Number *)
    let _PyNumber_Add = foreign ~from "PyNumber_Add" (pyobject @-> pyobject @-> returning pyobject)
    let _PyNumber_Subtract = foreign ~from "PyNumber_Subtract" (pyobject @-> pyobject @-> returning pyobject)
    let _PyNumber_Multiply = foreign ~from "PyNumber_Multiply" (pyobject @-> pyobject @-> returning pyobject)
    let _PyNumber_FloorDivide = foreign ~from "PyNumber_FloorDivide" (pyobject @-> pyobject @-> returning pyobject)
    let _PyNumber_TrueDivide = foreign ~from "PyNumber_TrueDivide" (pyobject @-> pyobject @-> returning pyobject)
    let _PyNumber_Remainder = foreign ~from "PyNumber_Remainder" (pyobject @-> pyobject @-> returning pyobject)
    let _PyNumber_Divmod = foreign ~from "PyNumber_Divmod" (pyobject @-> pyobject @-> returning pyobject)
    let _PyNumber_Negative = foreign ~from "PyNumber_Negative" (pyobject @-> returning pyobject)
    let _PyNumber_Positive = foreign ~from "PyNumber_Positive" (pyobject @-> returning pyobject)
    let _PyNumber_Absolute = foreign ~from "PyNumber_Absolute" (pyobject @-> returning pyobject)
    let _PyNumber_Invert = foreign ~from "PyNumber_Invert" (pyobject @-> returning pyobject)

    (* Buffer *)

    type _Py_buffer
    let _Py_buffer : _Py_buffer structure typ = structure "Py_buffer"
    let buf = field _Py_buffer "buf" (ptr char)
    let obj = field _Py_buffer "obj" (ptr void)
    let len = field _Py_buffer "len" int64_t
    let readonly = field _Py_buffer "readonly" int
    let itemsize = field _Py_buffer "itemsize" int64_t
    let format = field _Py_buffer "format" string
    let ndim = field _Py_buffer "ndim" int
    let shape = field _Py_buffer "shape" (ptr int64_t)
    let strides = field _Py_buffer "strides" (ptr int64_t)
    let suboffsets = field _Py_buffer "suboffsets" (ptr int64_t)
    let internal = field _Py_buffer "internal" (ptr void)
    let () = seal _Py_buffer

    type pybuffer = _Py_buffer structure ptr
    let pybuffer = ptr _Py_buffer

    let _PyObject_GetBuffer = foreign ~from "PyObject_GetBuffer" (pyobject @-> pybuffer @-> int @-> returning int)
    let _PyBuffer_Release = foreign ~from "PyBuffer_Release" (pybuffer @-> returning void)

    let _PyByteArray_FromObject = foreign ~from "PyByteArray_FromObject" (pyobject @-> returning pyobject)
    let _PyByteArray_AsString = foreign ~from "PyByteArray_AsString" (pyobject @-> returning (ptr char))
    let _PyByteArray_Size = foreign ~from "PyByteArray_Size" (pyobject @-> returning int64_t)
    let _PyByteArray_FromStringAndSize = foreign ~from "PyByteArray_FromStringAndSize" (ptr char @-> int64_t @-> returning pyobject)
end
