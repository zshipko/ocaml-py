open Ctypes
include Init

exception Invalid_type
exception Invalid_object
exception Python_error of string
exception End_iteration

let initialized = ref false

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

    let get_python_error () =
        if C._PyErr_Occurred () <> 0 then
            let ptype, pvalue, ptraceback =
                allocate_n pyobject ~count:1 ,
                allocate_n pyobject ~count:1,
                allocate_n pyobject ~count:1 in
            let _ = C._PyErr_Fetch ptype pvalue ptraceback in
            let x = C._PyObject_Str !@pvalue in
            let res = C._PyUnicode_AsUTF8 x in
            C._Py_DecRef x;
            Python_error (res)
        else Invalid_object

    let wrap x =
        if x = null then
            let err = get_python_error () in
            let _ = C._PyErr_Clear () in raise err
        else Gc.finalise C._Py_DecRef x; x

    let wrap_status x =
        if x = (-1) then
            let err = get_python_error () in
            let _ = C._PyErr_Clear () in raise err
        else ()


    let wrap_iter x =
        let err = C._PyErr_Occurred () = 1 in
        if x = null && not err then
            raise End_iteration
        else
            wrap x

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

        (* Type conversions *)

        let to_string a =
            let x = C._PyObject_Str a in
            let res = C._PyUnicode_AsUTF8 x in
            decref x; res

        let from_string s =
            wrap (C._PyUnicode_FromStringAndSize s (String.length s |> Int64.of_int))

        let to_bytes a =
            let x = C._PyObject_Bytes a in
            let res = C._PyBytes_AsString x in
            decref x; Bytes.of_string res

        let from_bytes s =
            wrap (C._PyBytes_FromStringAndSize (Bytes.to_string s) (Bytes.length s |> Int64.of_int))

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

        (* Acessing attrs/items *)

        let get_item obj k =
            wrap (C._PyObject_GetItem obj k)

        let del_item obj k =
            if C._PyObject_DelItem obj k = (-1) then raise (get_python_error ())

        let set_item obj k v =
            wrap_status (C._PyObject_SetItem obj k v)

        let get_attr obj k =
            wrap (C._PyObject_GetAttr obj k)

        let set_attr obj k v =
            wrap_status (C._PyObject_SetAttr obj k v)

        let del_attr obj k =
            wrap_status (C._PyObject_SetAttr obj k null)

        let has_attr obj k =
            C._PyObject_HasAttr obj k

        let get_item_s obj k =
            wrap (C._PyObject_GetItem obj (from_string k))

        let del_item_s obj k =
            wrap_status (C._PyObject_DelItem obj (from_string k))

        let set_item_s obj k v =
            wrap_status (C._PyObject_SetItem obj (from_string k) v)

        let get_attr_s obj k =
            wrap (C._PyObject_GetAttr obj (from_string k))

        let set_attr_s obj k v =
            wrap_status (C._PyObject_SetAttr obj (from_string k) v)

        let del_attr_s obj k =
            wrap_status (C._PyObject_SetAttr obj (from_string k) null)

        let has_attr_s obj k =
            C._PyObject_HasAttr obj (from_string k)

        let get_item_i obj k =
            wrap (C._PyObject_GetItem obj (from_int k))

        let del_item_i obj k =
            wrap_status (C._PyObject_DelItem obj (from_int k))

        let set_item_i obj k v =
            wrap_status (C._PyObject_SetItem obj (from_int k) v)


        let id a = a

        let array fn x =
            let len = length x |> Int64.to_int in
            let arr = Array.make len null in
            for i = 0 to len - 1 do
                arr.(i) <- get_item x (from_int i)
            done;
            Array.map fn arr

        let list fn x = array fn x |> Array.to_list

        let contains x i =
            let res = C._PySequence_Contains x i in
            if res < 0 then let () = wrap_status res in false
            else res = 1

        let concat a b =
            wrap (C._PySequence_Concat a b)

        let add a b =
            wrap (C._PyNumber_Add a b)

        let sub a b =
            wrap (C._PyNumber_Subtract a b)

        let mul a b =
            wrap (C._PyNumber_Multiply a b)

        let div a b =
            wrap (C._PyNumber_TrueDivide a b)

        let floor_div a b =
            wrap (C._PyNumber_FloorDivide a b)

        let divmod a b =
            wrap (C._PyNumber_Divmod a b)

        let rem a b =
            wrap (C._PyNumber_Remainder a b)

        let neg a =
            wrap (C._PyNumber_Negative a)

        let pos a =
            wrap (C._PyNumber_Positive a)

        let abs a =
            wrap (C._PyNumber_Absolute a)

        let invert a =
            wrap (C._PyNumber_Invert a)
    end

    module PyIter = struct
        type t = pyobject

        let get x : t = wrap (C._PyObject_GetIter x)

        let next x =
            wrap_iter (C._PyIter_Next x)

        let map fn x =
            let dst = ref [] in
            let _ = try
                while true do
                    let n = next x in
                    dst := fn n::!dst
                done
            with End_iteration -> () in
            List.rev !dst
    end

    module PyDict = struct
        let create l =
            let d = C._PyDict_New () in
            List.iter (fun (k, v) ->
                wrap_status (C._PyObject_SetItem d k v)) l; wrap d

        let contains d k =
            C._PyDict_Contains d k = 1

        let copy d =
            wrap (C._PyDict_Copy d)

        let clear d =
            C._PyDict_Clear d

        let merge a b update =
            wrap_status (C._PyDict_Merge a b update)

        let dict_items x = wrap (C._PyDict_Items x)
        let dict_keys x = wrap (C._PyDict_Keys x)
        let dict_values x = wrap (C._PyDict_Values x)

        let items kf vf x =
            let keys = Object.list kf (dict_keys x) in
            let values = Object.list vf (dict_values x) in
            List.combine keys values

        let keys fn x = Object.list fn (dict_keys x)
    end

    module PyList = struct
        let create l =
            let lst = C._PyList_New (List.length l |> Int64.of_int) in
            List.iteri (fun i x ->
                wrap_status (C._PyList_SetItem lst (Int64.of_int i) x)) l; wrap lst

        let insert l i v =
            wrap_status (C._PyList_Insert l i v)

        let append l v =
            wrap_status (C._PyList_Append l v)

        let get_slice l s e =
            wrap (C._PyList_GetSlice l s e)

        let set_slice l s e v =
            wrap_status (C._PyList_SetSlice l s e v)

        let sort l =
            wrap_status (C._PyList_Sort l)

        let rev l =
            wrap_status (C._PyList_Reverse l)

        let tuple l =
            wrap (C._PyList_AsTuple l)
    end

    module PyTuple = struct
        let create l =
            let tpl = C._PyTuple_New (Array.length l |> Int64.of_int) in
            Array.iteri (fun i x ->
                wrap_status (C._PyTuple_SetItem tpl (Int64.of_int i) x)) l; wrap tpl
    end

    module PySet = struct
        let create obj =
            wrap (C._PySet_New obj)
    end

    module PyUnicode = struct
        let create = Object.from_string
    end

    module PyBytes = struct
        let create = Object.from_bytes
    end

    module PyBuffer = struct
        type b = C.pybuffer
        type t = {
            buf : b;
            data : char CArray.t;
        }

        let from_object ?readonly:(readonly=true) obj =
            let b = allocate_n ~finalise:C._PyBuffer_Release C._Py_buffer ~count:1 in
            if C._PyObject_GetBuffer obj b (if readonly then 0 else 1) = -1 then
                raise (get_python_error ())
            else {
                buf = b;
                data = CArray.from_ptr (getf !@b C.buf) (getf !@b C.len |> Int64.to_int);
            }

        let get b i =
            CArray.get b.data i

        let set b i x =
            let ro = getf !@(b.buf) C.readonly in
            if ro <> 0 then
                CArray.set b.data i x

        let length a =
            getf !@(a.buf) C.len |> Int64.to_int

        let ndim a =
            getf !@(a.buf) C.ndim

        let strides a =
            let x = getf !@(a.buf) C.strides in
            let n = ndim a in
            CArray.from_ptr x n |> CArray.to_list |> Array.of_list

        let shape a =
            let x = getf !@(a.buf) C.shape in
            let n = ndim a in
            CArray.from_ptr x n |> CArray.to_list |> Array.of_list
    end

    module PyByteArray = struct
        let from_list x =
            wrap (C._PyByteArray_FromStringAndSize (CArray.of_list char x |> CArray.start) (List.length x |> Int64.of_int))

        let from_object x = wrap (C._PyByteArray_FromObject x)

        let get_string x =
            let s = C._PyByteArray_AsString x in
            let len = C._PyByteArray_Size x in
            string_from_ptr s ~length:(Int64.to_int len)

        let get a i : char =
            let b = C._PyByteArray_AsString a in
            let b = CArray.from_ptr b (C._PyByteArray_Size a |> Int64.to_int) in
            CArray.get b i

        let set a i x =
            let b = C._PyByteArray_AsString a in
            let b = CArray.from_ptr b (C._PyByteArray_Size a |> Int64.to_int) in
            CArray.set b i x

        let length a =
            let b = C._PyByteArray_AsString a in
            let b = CArray.from_ptr b (C._PyByteArray_Size a |> Int64.to_int) in
            CArray.length b
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
        | String s -> PyUnicode.create s
        | Bytes b -> PyBytes.create b
        | List l -> PyList.create (List.map to_object l)
        | Tuple t -> PyTuple.create (Array.map to_object t)
        | Dict d -> PyDict.create (List.map (fun (k, v) -> to_object k, to_object v) d)
        | Set l -> PySet.create (PyList.create (List.map to_object l))

    let program_name : wchar_string option ref = ref None

    let finalize () =
        match !program_name with
        | Some p ->
            C._PyMem_RawFree p;
            program_name := None
        | None -> ();
        C._Py_Finalize ();
        initialized := false

    let wchar_s s =
        let s' = C._Py_DecodeLocale s null in
        Gc.finalise C._PyMem_RawFree s'; s'

    (** Initialize the Python interpreter *)
    let initialize ?initsigs:(initsigs=true) () =
        if not !initialized then
            let name = wchar_s Sys.argv.(0) in
            let _ = if name <> null then
                let _ = program_name := Some name in
                C._Py_SetProgramName name in
            let _ = C._Py_InitializeEx (if initsigs then 1 else 0) in
            let _ = C._PyEval_InitThreads () in
            let argv = allocate_n wchar_string ~count:1 in
            let _ = argv <-@ name in
            C._PySys_SetArgvEx 1 argv 1;
            initialized := true;
            at_exit finalize

    let get_module_dict () =
        C._PyImport_GetModuleDict ()

    (** Returns the main module *)
    module PyModule = struct
        let set name m =
            let d = get_module_dict () in
            Object.set_item d (Object.from_string name) m

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
            | None -> PyModule.get_dict "__main__" in
        let l = match locals with
            | Some x -> x
            | None -> PyDict.create [] in
        wrap (C._PyRun_StringFlags s (258) g l null)

    (** Call a Python Object *)
    let call ?args:(args=PyTuple.create [||]) ?kwargs fn =
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
        Object.set_attr sys pathString (PyList.create (List.map Object.from_string p))

    let () = initialize ()
end
