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
    let _PyObject_Bytes = foreign ~from "PyObject_Bytes" (pyobject @-> returning pyobject)
    let _PyObject_Length = foreign ~from "PyObject_Length" (pyobject @-> returning int64_t)
    let _PyObject_Call = foreign ~from "PyObject_Call" (pyobject @-> pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_GetItem = foreign ~from "PyObject_GetItem" (pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_DelItem = foreign ~from "PyObject_DelItem" (pyobject @-> pyobject @-> returning int)
    let _PyObject_SetItem = foreign ~from "PyObject_SetItem" (pyobject @-> pyobject @-> pyobject @-> returning int)
    let _PyObject_GetAttr = foreign ~from "PyObject_GetAttr" (pyobject @-> pyobject @-> returning pyobject)
    let _PyObject_SetAttr = foreign ~from "PyObject_SetAttr" (pyobject @-> pyobject @-> pyobject @-> returning int)
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
    let _PyFloat_AsDouble = foreign ~from "PyFloat_AsDouble" (pyobject @-> returning float)
    let _PyFloat_FromDouble = foreign ~from "PyFloat_FromDouble" (float @-> returning pyobject)

    (* Bool *)
    let _PyObject_IsTrue = foreign ~from "PyObject_IsTrue" (pyobject @-> returning int)
    let _PyBool_FromLong = foreign ~from "PyBool_FromLong" (int @-> returning pyobject)

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
    let _PyTuple_New = foreign ~from "PyTuple_New" (int64_t @-> returning pyobject)
    let _PyTuple_SetItem = foreign ~from "PyTuple_SetItem" (pyobject @-> int64_t @-> pyobject @-> returning int)

    (* List *)
    let _PyList_New = foreign ~from "PyList_New" (int64_t @-> returning pyobject)
    let _PyList_SetItem = foreign ~from "PyList_SetItem" (pyobject @-> int64_t @-> pyobject @-> returning int)

    (* Set *)
    let _PySet_New = foreign ~from "PySet_New" (pyobject @-> returning pyobject)
end

module Make(V : Version) = struct
    module C = Init(V)

    let wrap x =
        if x == null then raise Python_error
        else Gc.finalise C._Py_DecRef x; x

    module Object = struct
        (** PyObject handle *)
        type t = pyobject

        let to_pyobject (x : t) : pyobject = x
        let from_pyobject (x : pyobject) : t = x

        let decref = C._Py_DecRef
        let incref = C._Py_IncRef

        let length obj =
            C._PyObject_Length obj

        let create_dict l =
            let d = C._PyDict_New () in
            List.iter (fun (k, v) ->
                ignore (C._PyObject_SetItem d k v)) l; wrap d

        let create_tuple l =
            let tpl = C._PyTuple_New (Array.length l |> Int64.of_int) in
            Array.iteri (fun i x ->
                ignore (C._PyTuple_SetItem tpl (Int64.of_int i) x)) l; wrap tpl

        let create_list l =
            let lst = C._PyList_New (List.length l |> Int64.of_int) in
            List.iteri (fun i x ->
                ignore (C._PyList_SetItem lst (Int64.of_int i) x)) l; wrap lst

        let create_set obj =
            wrap (C._PySet_New obj)

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
            if C._PyObject_SetAttr obj k null = (-1) then raise Python_error

        let has_attr obj k =
            C._PyObject_HasAttr obj k

        (* Type conversions *)

        let to_string a =
            let x = C._PyObject_Str a in
            let res = C._PyUnicode_AsUTF8 x in
            decref x; res

        let from_string s =
            wrap (C._PyUnicode_FromStringAndSize s (String.length s))

        let to_bytes a =
            let x = C._PyObject_Bytes a in
            let res = C._PyBytes_AsString x in
            decref x; Bytes.of_string res

        let from_bytes s =
            wrap (C._PyBytes_FromStringAndSize (Bytes.to_string s) (Bytes.length s))

        let to_int a =
            C._PyLong_AsLong a

        let from_int i =
            wrap (C._PyLong_FromLong i)

        let to_int64 a =
            C._PyLong_AsLongLong a

        let from_int64 i =
            wrap (C._PyLong_FromLongLong i)

        let to_float a =
            C._PyFloat_AsDouble a

        let from_float i =
            wrap (C._PyFloat_FromDouble i)

        let to_bool a =
            C._PyObject_IsTrue a <> 0

        let from_bool b =
            wrap (C._PyBool_FromLong (if b then 1 else 0))
    end

    type t =
        | Object of Object.t
        | Module of Object.t
        | None
        | Bool of bool
        | Int of int
        | Int64 of int64
        | Float of float
        | String of string
        | Bytes of Bytes.t
        | List of t list
        | Tuple of t array
        | Dict of (t * t) list
        | Set of t list

    let rec to_object = function
        | Object o | Module o -> o
        | None -> null (* TODO: check to make sure this is okay *)
        | Bool b -> Object.from_bool b
        | Int i -> Object.from_int i
        | Int64 i -> Object.from_int64 i
        | Float f -> Object.from_float f
        | String s -> Object.from_string s
        | Bytes b -> Object.from_bytes b
        | List l -> Object.create_list (List.map to_object l)
        | Tuple t -> Object.create_tuple (Array.map to_object t)
        | Dict d -> Object.create_dict (List.map (fun (k, v) -> to_object k, to_object v) d)
        | Set l -> Object.create_set (Object.create_list (List.map to_object l))

    (** Initialize the Python interpreter *)
    let initialize ?initsigs:(initsigs=true) () =
        C._Py_InitializeEx (if initsigs then 1 else 0)

    let finalize = C._Py_Finalize

    (** Returns the main module *)
    module Module = struct
        let get name =
            wrap (C._PyImport_AddModule name)

        let get_dict name =
            wrap (C._PyModule_GetDict (get name))
    end

    (** Execute a string in the global context returning false if an error occurs *)
    let exec s =
        not (C._PyRun_SimpleStringFlags s null)

    (** Evalute a string and return the result *)
    let eval ?globals ?locals s =
        let g = match globals with
            | Some x -> x
            | None -> Module.get_dict "__main__" in
        let l = match locals with
            | Some x -> x
            | None -> Object.create_dict [] in
        wrap (C._PyRun_StringFlags s (258) g l null)

    (** Call a Python Object *)
    let call ?args:(args=Object.create_tuple [||]) ?kwargs fn =
        let kw = match kwargs with
        | Some k -> k
        | None -> null in
        C._PyObject_Call fn args kw

    let (!$) obj = to_object obj

    let (@) fn args =
        call ~args:!$(Tuple (Array.of_list args)) fn

    let () = initialize ()
end


