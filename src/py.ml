open Ctypes
open Foreign

exception Invalid_type
exception Invalid_object
exception Python_error

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
    let _PyObject_Length = foreign ~from "PyObject_Length" (pyobject @-> returning int64_t)
    let _PyObject_Call = foreign ~from "PyObject_Call" (pyobject @-> pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_GetItem = foreign ~from "PyObject_GetItem" (pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_DelItem = foreign ~from "PyObject_DelItem" (pyobject @-> pyobject @-> returning int)
    let _PyObject_SetItem = foreign ~from "PyObject_SetItem" (pyobject @-> pyobject @-> pyobject @-> returning int)
    let _PyObject_GetAttr = foreign ~from "PyObject_GetAttr" (pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_SetAttr = foreign ~from "PyObject_SetAttr" (pyobject @-> pyobject @-> pyobject @-> returning int)
    let _PyObject_DelAttr = foreign ~from "PyObject_DelAttr" (pyobject @-> pyobject @-> returning int)
    let _PyObject_HasAttr = foreign ~from "PyObject_HasAttr" (pyobject @-> pyobject @-> returning bool)

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

    (* Tuple *)
    let _PyTuple_New = foreign ~from "PyTuple_New" (int @-> returning pyobject)


end

module Make(V : Version) = struct
    module C = Init(V)

    let wrap x =
        if x == null then raise Python_error
        else Gc.finalise C._Py_DecRef x; x

    module Dict = struct
        let create () =
            wrap (C._PyDict_New ())
    end

    module Tuple = struct
        let create n =
            wrap (C._PyTuple_New n)
    end

    module Object = struct
        (** PyObject handle *)
        type t = pyobject

        let to_pyobject (x : t) : pyobject = x
        let from_pyobject (x : pyobject) : t = x

        let decref = C._Py_DecRef
        let incref = C._Py_IncRef

        let length obj =
            C._PyObject_Length obj

        let unwrap = function
        | Some s -> s
        | None -> raise Invalid_object

        (** Call a Python Object *)
        let call ?args:(args=Tuple.create 0) ?kwargs fn =
            let kw = match kwargs with
            | Some k -> k
            | None -> null in
            wrap (C._PyObject_Call fn args kw)

        let get_item obj k =
            wrap (C._PyObject_GetItem obj k)

        let del_item obj k =
            if C._PyObject_DelItem obj k = (-1) then raise Python_error

        let set_item obj k v =
            if C._PyObject_SetItem obj k v = (-1) then raise Python_error

        let get_attr obj k =
            wrap (C._PyObject_GetAttr obj k)

        let set_attr obj k v =
            if C._PyObject_SetAttr obj k v = (-1) then raise Python_error

        let del_attr obj k =
            if C._PyObject_DelAttr obj k = (-1) then raise Python_error

        let has_attr obj k =
            C._PyObject_HasAttr obj k

        (* Type conversions *)

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
    end

    (** Initialize the Python interpreter *)
    let initialize ?initsigs:(initsigs=true) () =
        C._Py_InitializeEx (if initsigs then 1 else 0)

    let finalize = C._Py_Finalize

    (** Returns the main module *)
    module Module = struct
        let get name =
            wrap (C._PyImport_AddModule(name))

        let dict m =
            wrap (C._PyModule_GetDict m)

        let main () =
            get "__main__"

        let main_dict () =
            dict (main ())
    end

    (** TODO: List.create, set_item, get_item, set_attr, get_attr etc... *)

    (** Evaluate a string in the global context returning false if an error occurs *)
    let eval s =
        not (C._PyRun_SimpleStringFlags s null)

    (** Run a string and return the result *)
    let run ?globals ?locals s =
        let g = match globals with
            | Some x -> x
            | None -> Module.main_dict () in
        let l = match locals with
            | Some x -> x
            | None -> Dict.create () in
        wrap (C._PyRun_StringFlags s (258) g l null)

    let () = initialize ()
end


