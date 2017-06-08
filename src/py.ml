open Ctypes
include Init

exception Invalid_type
exception Invalid_object
exception Python_error

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


