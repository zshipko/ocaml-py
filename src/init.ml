open Ctypes
open Foreign

type pyobject = unit ptr
let pyobject : pyobject typ = ptr void

type op =
    | LT
    | LE
    | EQ
    | NE
    | GT
    | GE

module type Version = sig
    val lib : string
end

type wchar_string = unit ptr
let wchar_string : wchar_string typ = ptr void

module Init(V : Version) = struct
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
    let _PyUnicode_FromStringAndSize = foreign ~from "PyUnicode_FromStringAndSize" (string @-> int @-> returning pyobject)

    (* Bytes *)
    let _PyBytes_AsString = foreign ~from "PyBytes_AsString" (pyobject @-> returning string)
    let _PyBytes_FromStringAndSize = foreign ~from "PyBytes_FromStringAndSize" (string @-> int @-> returning pyobject)

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

    (* Module *)
    let _PyModule_GetDict = foreign ~from "PyModule_GetDict" (pyobject @-> returning pyobject)
    let _PyImport_AddModule = foreign ~from "PyImport_AddModule" (string @-> returning pyobject)
    let _PyImport_ImportModule = foreign ~from "PyImport_ImportModule" (string @-> returning pyobject)
    let _PyImport_ReloadModule = foreign ~from "PyImport_ReloadModule" (pyobject @-> returning pyobject)

    (* Dict *)
    let _PyDict_New = foreign ~from "PyDict_New" (void @-> returning pyobject)
    let _PyDict_Items = foreign ~from "PyDict_Items" (pyobject @-> returning pyobject)
    let _PyDict_Values = foreign ~from "PyDict_Values" (pyobject @-> returning pyobject)
    let _PyDict_Keys = foreign ~from "PyDict_Keys" (pyobject @-> returning pyobject)

    (* Tuple *)
    let _PyTuple_New = foreign ~from "PyTuple_New" (int64_t @-> returning pyobject)
    let _PyTuple_SetItem = foreign ~from "PyTuple_SetItem" (pyobject @-> int64_t @-> pyobject @-> returning int)

    (* List *)
    let _PyList_New = foreign ~from "PyList_New" (int64_t @-> returning pyobject)
    let _PyList_SetItem = foreign ~from "PyList_SetItem" (pyobject @-> int64_t @-> pyobject @-> returning int)

    (* Set *)
    let _PySet_New = foreign ~from "PySet_New" (pyobject @-> returning pyobject)
end
