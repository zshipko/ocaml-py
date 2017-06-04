open Ctypes
open Foreign

exception Invalid_type

type pyobject = unit ptr
let pyobject : pyobject typ = ptr void

module type Version = sig
    val lib : string
end

module Init(V : Version) = struct
    let from =
        (* Try to open a bunch of different permutations to find the correct library
         * TODO: conside just using the output of pkg-config or something more definitive *)
        let flags = Dl.[RTLD_LAZY] in
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

    (* Object *)
    let _PyObject_Str = foreign ~from "PyObject_Str" (pyobject @-> returning pyobject)

    (* Unicode *)
    let _PyUnicode_AsUTF8 = foreign ~from "PyUnicode_AsUTF8" (pyobject @-> returning string)
    let _PyUnicode_FromStringAndSize = foreign ~from "PyUnicode_FromStringAndSize" (string @-> int @-> returning pyobject)

    (* Long *)
    let _PyLong_AsLong = foreign ~from "PyLong_AsLong" (pyobject @-> returning int)
    let _PyLong_FromLong = foreign ~from "PyLong_FromLong" (int @-> returning pyobject)

    (* Interpeter *)
    let _Py_IncRef = foreign ~from "Py_IncRef" (pyobject @-> returning void)
    let _Py_DecRef = foreign ~from "Py_DecRef" (pyobject @-> returning void)
    let _Py_InitializeEx = foreign ~from "Py_InitializeEx" (int @-> returning void)
    let _Py_Finalize = foreign ~from "Py_Finalize" (void @-> returning void)
    let _PyRun_SimpleStringFlags = foreign ~from "PyRun_SimpleStringFlags" (string @-> ptr void @-> returning bool)
    let _PyRun_StringFlags = foreign ~from "PyRun_StringFlags" (string @-> int @-> pyobject @-> pyobject @-> ptr void @-> returning pyobject)

    (* Module *)
    let _PyModule_GetDict = foreign ~from "PyModule_GetDict" (pyobject @-> returning pyobject)
    let _PyImport_AddModule = foreign ~from "PyImport_AddModule" (string @-> returning pyobject)

    (* Dict *)
    let _PyDict_New = foreign ~from "PyDict_New" (void @-> returning pyobject)
end

module Make(V : Version) = struct
    module C = Init(V)

    (** PyObject handle *)
    type t = pyobject

    let to_pyobject (x : t) : pyobject = x
    let from_pyobject (x : pyobject) : t = x

    (** Initialize the Python interpreter *)
    let initialize ?initsigs:(initsigs=true) () =
        C._Py_InitializeEx (if initsigs then 1 else 0)

    let finalize = C._Py_Finalize

    (** Returns the main module *)
    let main () =
        C._PyModule_GetDict(C._PyImport_AddModule("__main__"))

    let decref = C._Py_DecRef
    let incref = C._Py_IncRef

    let wrap x =
        Gc.finalise decref x; x

    module Dict = struct
        let create () =
            let d = C._PyDict_New () in
            wrap d
    end

    (** Evaluate a string in the global context returning false if an error occurs *)
    let eval s =
        not (C._PyRun_SimpleStringFlags s null)

    (** Run a string and return the result *)
    let run ?globals ?locals s =
        let g = match globals with
            | Some x -> x
            | None -> main () in
        let l = match locals with
            | Some x -> x
            | None -> Dict.create () in
        let res = C._PyRun_StringFlags s (258) g l null in
        (*let () = match locals with
            | Some _ -> ()
            | None -> decref l in*)
        if res = null then None
        else
            Some (wrap res)

    let to_string a =
        let x = C._PyObject_Str a in
        let res = C._PyUnicode_AsUTF8 x in
        decref x; res

    let from_string s =
        wrap (C._PyUnicode_FromStringAndSize s (String.length s))

    let to_int a =
        C._PyLong_AsLong a

    let from_int i =
        wrap (C._PyLong_FromLong i)

    let () = initialize ()
end


