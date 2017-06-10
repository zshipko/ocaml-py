open Ctypes
include Init

exception Invalid_type
exception Invalid_object
exception Python_error

type op = S.op =
    | LT
    | LE
    | EQ
    | NE
    | GT
    | GE

module type PYTHON = S.PYTHON
module type VERSION = S.VERSION

module Make(V : S.VERSION) : S.PYTHON = struct
    module C = Init(V)

    let wrap x =
        if x = null then let _ = C._PyErr_Clear () in raise Python_error
        else Gc.finalise C._Py_DecRef x; x

    module Object = struct
        (** PyObject handle *)
        type t = pyobject

        let to_pyobject (x : t) : pyobject =
            if x = null then raise Invalid_object
            else x

        let from_pyobject (x : pyobject) : t =
            if x = null then raise Invalid_object
            else x

        let is_null x = x = null

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

        let none = C._Py_NoneStruct
        let incref_none () = incref none; none

        let compare a b op =
            C._PyObject_RichCompareBool a b (Obj.magic op : int)

        let is_none x = compare x none EQ

        let id a = a

        let array fn x =
            let len = length x |> Int64.to_int in
            let arr = Array.make len null in
            for i = 0 to len - 1 do
                arr.(i) <- get_item x (from_int i)
            done;
            Array.map fn arr

        let list fn x = array fn x |> Array.to_list
        let dict_items x = wrap (C._PyDict_Items x)
        let dict_keys x = wrap (C._PyDict_Keys x)
        let dict_values x = wrap (C._PyDict_Values x)
        let items kf vf x =
            let keys = list kf (dict_keys x) in
            let values = list vf (dict_values x) in
            List.combine keys values
        let keys fn x = list fn (dict_keys x)
    end

    type t =
        | PyObject of Object.t
        | PyNone
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
        | PyObject o -> o
        | PyNone -> Object.none
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

    let initialized = ref false
    let program_name : wchar_string option ref = ref None

    let finalize () =
        match !program_name with
        | Some p ->
            C._PyMem_RawFree p;
            program_name := None
        | None -> ();
        C._Py_Finalize ();
        initialized := false

    (** Initialize the Python interpreter *)
    let initialize ?initsigs:(initsigs=true) () =
        if not !initialized then
            let name = C._Py_DecodeLocale Sys.argv.(0) null in
            let _ = if name <> null then
                let _ = program_name := Some name in
                C._Py_SetProgramName name in
            let _ = C._Py_InitializeEx (if initsigs then 1 else 0) in
            let _ = C._PyEval_InitThreads () in
            initialized := true;
            at_exit finalize

    (** Returns the main module *)
    module Module = struct
        let get name =
            wrap (C._PyImport_AddModule name)

        let get_dict name =
            wrap (C._PyModule_GetDict (get name))

        let reload m =
            wrap (C._PyImport_ReloadModule m)
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

    let run fn ?kwargs args =
        call ~args:!$(Tuple (Array.of_list args)) ?kwargs fn

    let import name = wrap (C._PyImport_ImportModule name)

    let ($) fn args = run fn args

    let append_path files =
        let sys = import "sys" in
        let pathString = !$(String "path") in
        let path = Object.get_attr sys pathString in
        let p = Object.list Object.to_string path @ files in
        Object.set_attr sys pathString (Object.create_list (List.map Object.from_string p))

    let () = initialize ()
end
