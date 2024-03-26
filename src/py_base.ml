open Ctypes
include Init

exception Invalid_type
exception Invalid_object
exception Python_error of string
exception End_iteration

let initialized = ref already_initialized

type op =
    | LT
    | LE
    | EQ
    | NE
    | GT
    | GE

module C = Init

let maybe_raise_python_error () =
    if C._PyErr_Occurred () <> 0 then
        let ptype, pvalue, ptraceback =
            allocate_n pyobject ~count:1 ,
            allocate_n pyobject ~count:1,
            allocate_n pyobject ~count:1 in
        let _ = C._PyErr_Fetch ptype pvalue ptraceback in
        let x = C._PyObject_Str !@pvalue in
        let res = C._PyUnicode_AsUTF8 x in
        C._Py_DecRef x;
        C._PyErr_Clear ();
        raise (Python_error res)

let wrap x =
    if x = null then (
        maybe_raise_python_error ();
        raise Invalid_object)
    else Gc.finalise C._Py_DecRef x; x


let wrap_status x =
    if x = -1 then maybe_raise_python_error ()
    else ()


let wrap_iter x =
    let err = C._PyErr_Occurred () = 1 in
    if x = null && not err then
        raise End_iteration
    else
        wrap x

module PyList = struct
    let create l =
        let lst = C._PyList_New (List.length l |> Int64.of_int) in
        List.iteri (fun i x ->
            C._Py_IncRef x;
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
            C._Py_IncRef x;
            wrap_status (C._PyTuple_SetItem tpl (Int64.of_int i) x)) l; wrap tpl
end

module PySet = struct
    let create obj =
        wrap (C._PySet_New obj)
end

module PyUnicode = struct
    let create s =
        wrap (C._PyUnicode_FromStringAndSize s (String.length s |> Int64.of_int))
end

module PyBytes = struct
    let create b =
        wrap (C._PyBytes_FromStringAndSize (Bytes.to_string b) (Bytes.length b |> Int64.of_int))
end

module PyBuffer = struct
    type b = C.pybuffer
    type t = {
        buf : b;
        data : char CArray.t;
    }

    let create ?readonly:(readonly=true) obj =
        let b = allocate_n ~finalise:C._PyBuffer_Release C._Py_buffer ~count:1 in
        wrap_status (C._PyObject_GetBuffer obj b (if readonly then 0 else 1));
        {
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
        CArray.from_ptr x n
        |> CArray.to_list
        |> Array.of_list

    let shape a =
        let x = getf !@(a.buf) C.shape in
        let n = ndim a in
        CArray.from_ptr x n
        |> CArray.to_list
        |> Array.of_list
end

module PyByteArray = struct
    let from_list x =
        wrap (C._PyByteArray_FromStringAndSize (CArray.of_list char x |> CArray.start) (List.length x |> Int64.of_int))

    let create x = wrap (C._PyByteArray_FromObject x)

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


module PyNumber = struct
    let create_int i =
        wrap (C._PyLong_FromLong i)

    let create_int64 i =
        wrap (C._PyLong_FromLongLong i)

    let create_float i =
        wrap (C._PyFloat_FromDouble i)

    let add a b =
        wrap (C._PyNumber_Add a b)

    let sub a b =
        wrap (C._PyNumber_Subtract a b)

    let mul a b =
        wrap (C._PyNumber_Multiply a b)

    let matmul a b =
        wrap (C._PyNumber_MatrixMultiply a b)

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

    let power a b =
        wrap (C._PyNumber_Power a b)

    let lshift a b =
        wrap (C._PyNumber_Lshift a b)

    let rshift a b =
        wrap (C._PyNumber_Rshift a b)

    let band a b =
        wrap (C._PyNumber_And a b)

    let bor a b =
        wrap (C._PyNumber_Or a b)

    let bxor a b =
        wrap (C._PyNumber_Xor a b)

    let add_inplace a b =
        wrap (C._PyNumber_InPlaceAdd a b)

    let sub_inplace a b =
        wrap (C._PyNumber_InPlaceSubtract a b)

    let mul_inplace a b =
        wrap (C._PyNumber_InPlaceMultiply a b)

    let matmul_inplace a b =
        wrap (C._PyNumber_InPlaceMatrixMultiply a b)

    let div_inplace a b =
        wrap (C._PyNumber_InPlaceTrueDivide a b)

    let floor_div_inplace a b =
        wrap (C._PyNumber_InPlaceFloorDivide a b)

    let rem_inplace a b =
        wrap (C._PyNumber_InPlaceRemainder a b)

    let power_inplace a b =
        wrap (C._PyNumber_InPlacePower a b)

    let lshift_inplace a b =
        wrap (C._PyNumber_InPlaceLshift a b)

    let rshift_inplace a b =
        wrap (C._PyNumber_InPlaceRshift a b)

    let band_inplace a b =
        wrap (C._PyNumber_InPlaceAnd a b)

    let bor_inplace a b =
        wrap (C._PyNumber_InPlaceOr a b)

    let bxor_inplace a b =
        wrap (C._PyNumber_InPlaceXor a b)
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



module Object = struct
    (** PyObject handle *)
    type t = pyobject

    let is_null x = x = null

    let decref = C._Py_DecRef
    let incref = C._Py_IncRef

    let length obj =
        let l = C._PyObject_Length obj in
        if Int64.to_int l = -1 then maybe_raise_python_error ();
        l

    (* Type conversions *)

    let to_string a =
        let x = wrap (C._PyObject_Str a) in
        C._PyUnicode_AsUTF8 x

    let to_bytes a =
        let x = wrap (C._PyObject_Bytes a) in
        Bytes.of_string (C._PyBytes_AsString x)

    let to_int a =
        let i = C._PyLong_AsLong a in
        maybe_raise_python_error ();
        i

    let to_int64 a =
        let i = C._PyLong_AsLongLong a in
        maybe_raise_python_error ();
        i

    let to_float a =
        let f = C._PyFloat_AsDouble a in
        maybe_raise_python_error ();
        f

    let to_bool a =
        let b = C._PyObject_IsTrue a <> 0 in
        maybe_raise_python_error ();
        b

    let from_bool b =
        wrap (C._PyBool_FromLong (if b then 1 else 0))

    let _none = C._Py_NoneStruct
    let none () = incref _none; _none

    let compare a b op =
        C._PyObject_RichCompareBool a b (Obj.magic op : int)

    let is_none x = compare x _none EQ

    (* Acessing attrs/items *)

    let get_item obj k =
        wrap (C._PyObject_GetItem obj k)

    let del_item obj k =
        wrap_status (C._PyObject_DelItem obj k)

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
        wrap (C._PyObject_GetItem obj (PyUnicode.create k))

    let del_item_s obj k =
        wrap_status (C._PyObject_DelItem obj (PyUnicode.create k))

    let set_item_s obj k v =
        wrap_status (C._PyObject_SetItem obj (PyUnicode.create k) v)

    let get_attr_s obj k =
        wrap (C._PyObject_GetAttrString obj k)

    let set_attr_s obj k v =
        wrap_status (C._PyObject_SetAttr obj (PyUnicode.create k) v)

    let del_attr_s obj k =
        wrap_status (C._PyObject_SetAttr obj (PyUnicode.create k) null)

    let has_attr_s obj k =
        C._PyObject_HasAttr obj (PyUnicode.create k)

    let get_item_i obj k =
        wrap (C._PyObject_GetItem obj (PyNumber.create_int k))

    let del_item_i obj k =
        wrap_status (C._PyObject_DelItem obj (PyNumber.create_int k))

    let set_item_i obj k v =
        wrap_status (C._PyObject_SetItem obj (PyNumber.create_int k) v)

    let to_array fn x =
        let len = length x |> Int64.to_int in
        let arr = Array.make len null in
        for i = 0 to len - 1 do
            arr.(i) <- get_item x (PyNumber.create_int i)
        done;
        Array.map fn arr

    let to_list fn x = to_array fn x |> Array.to_list

    let contains x i =
        let res = C._PySequence_Contains x i in
        if res < 0 then let () = wrap_status res in false
        else res = 1

    let concat a b =
        wrap (C._PySequence_Concat a b)

    let pp formatter t =
        let str =
            if is_null t then "PyNull"
            else try to_string t with _ -> "PyOpaque"
        in
        Format.open_box 0;
        Format.fprintf formatter "%s" str;
        Format.close_box ()

    let to_c_ptr x = x
    let of_c_ptr x = x

    let capsule_c_pointer t str_option =
        let str_or_null =
            match str_option with
            | Some str -> CArray.of_string str |> CArray.start
            | None -> from_voidp char null
        in
        let ptr = C._PyCapsule_GetPointer t str_or_null in
        if ptr = null
        then (
            maybe_raise_python_error ();
            raise Invalid_object;
        )
        else ptr

    let pydict_create l =
        let d = C._PyDict_New () in
        List.iter (fun (k, v) ->
            wrap_status (C._PyObject_SetItem d k v)) l; wrap d

    (** Call a Python Object *)
    let call ?args:(args=[||]) ?kwargs fn =
        let kw = match kwargs with
        | Some k -> pydict_create k
        | None -> null in
        (* PyObject_Call segfaults on Python 3.7 when args is not a tuple
           rather than setting a proper error, so we enforce that this always
           uses a tuple. *)
        wrap (C._PyObject_Call fn (PyTuple.create args) kw)

    let call_method ?args ?kwargs t method_name =
        call (get_attr_s t method_name) ?args ?kwargs
end

module PyDict = struct
    let create = Object.pydict_create

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
        let keys = Object.to_list kf (dict_keys x) in
        let values = Object.to_list vf (dict_values x) in
        List.combine keys values

    let keys fn x = Object.to_list fn (dict_keys x)
end

let get_module_dict () =
    C._PyImport_GetModuleDict ()

module PyModule = struct
    let import name =
        wrap (C._PyImport_Import (PyUnicode.create name))

    let set name m =
        let d = get_module_dict () in
        Object.set_item d (PyUnicode.create name) m

    let get name =
        wrap (C._PyImport_AddModule name)

    let get_dict name =
        wrap (C._PyModule_GetDict (get name))

    let reload m =
        wrap (C._PyImport_ReloadModule m)

    let add_int m name v =
        wrap_status (C._PyModuleAddIntConstant m name v)

    let add_string m name v =
        wrap_status (C._PyModuleAddStringConstant m name v)

    let add_object m name obj =
        (* PyModule_AddObject steals the reference to obj so we first increase
           the refcount. *)
        Object.incref obj;
        wrap_status (C._PyModuleAddObject m name obj)

    let main () =
        get "__main__"
end

module PyCell = struct
    let create obj =
        wrap (C._PyCell_New obj)

    let get cell =
        wrap (C._PyCell_Get cell)

    let set cell v =
        wrap_status (C._PyCell_Set cell v)
end

module PySlice = struct
    let create a b c =
        wrap (C._PySlice_New a b c)
end

module PyWeakref = struct
    let new_ref ?callback:(callback=Object.none ()) obj =
        wrap (C._PyWeakref_NewRef obj callback)

    let new_proxy ?callback:(callback=Object.none ()) obj =
        wrap (C._PyWeakref_NewProxy obj callback)

    let get_object ref =
        wrap (C._PyWeakref_GetObject ref)
end

module PyThreadState = struct
    type t = C.thread

    let save () =
        C._PyEval_SaveThread ()

    let restore thr =
        C._PyEval_RestoreThread thr

    let get () =
        C._PyThreadState_Get ()

    let swap thr =
        C._PyThreadState_Swap thr

    let clear thr =
        C._PyThreadState_Clear thr

    let delete thr =
        clear thr;
        C._PyThreadState_Delete thr

    let get_dict thr =
        wrap (C._PyThreadState_GetDict thr)

    let next thr =
        C._PyThreadState_Next thr
end

let new_interpreter () =
    C._Py_NewInterpreter ()

let end_interpreter thr =
    C._Py_EndInterpreter thr


type t =
    | Ptr of Object.t
    | Cell of Object.t
    | Nil
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
    | Slice of t * t * t

let rec to_object = function
    | Ptr o -> o
    | Cell c -> PyCell.create c
    | Nil -> Object.none ()
    | Bool b -> Object.from_bool b
    | Int i -> PyNumber.create_int i
    | Int64 i -> PyNumber.create_int64 i
    | Float f -> PyNumber.create_float f
    | String s -> PyUnicode.create s
    | Bytes b -> PyBytes.create b
    | List l -> PyList.create (List.map to_object l)
    | Tuple t -> PyTuple.create (Array.map to_object t)
    | Dict d -> PyDict.create (List.map (fun (k, v) -> to_object k, to_object v) d)
    | Set l -> PySet.create (PyList.create (List.map to_object l))
    | Slice (a, b, c) -> PySlice.create (to_object a) (to_object b) (to_object c)

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

(** Execute a string in the global context returning false if an error occurs *)
let exec s =
    not (C._PyRun_SimpleStringFlags s null)

let globals () =
    let x = C._PyEval_GetGlobals () in
    if Object.is_null x then None else Some x

let locals () =
    let x = C._PyEval_GetLocals () in
    if Object.is_null x then None else Some x

let builtins () =
    C._PyEval_GetBuiltins ()

(** Evalute a string and return the result *)
let eval ?globals ?locals s =
    let g = match globals with
        | Some x -> to_object x
        | None -> PyModule.get_dict "__main__" in
    let l = match locals with
        | Some x -> to_object x
        | None -> PyDict.create [] in
    wrap (C._PyRun_StringFlags s (258) g l null)

let ( !$ ) obj = to_object obj

let run fn ?kwargs:(kwargs=[]) args =
    Object.call fn
      ~args:(List.map to_object args |> Array.of_list)
      ~kwargs:(List.map (fun (key, value) -> !$ key, !$ value) kwargs)

let ( $ ) fn args = run fn args
let ( $. ) obj attr = Object.get_attr obj (!$attr)
let ( <-$.) (obj, key) value = Object.set_attr obj (!$key) (!$value)
let ( $| ) obj item = Object.get_item obj (!$item)
let ( <-$| ) (obj, key) value = Object.set_item obj (!$key) (!$value)

let append_path files =
    let sys = PyModule.import "sys" in
    let path = Object.get_attr_s sys "path" in
    let p = Object.to_list Object.to_string path @ files in
    Object.set_attr_s sys "path" (PyList.create (List.map PyUnicode.create p))

let prepend_path files =
    let sys = PyModule.import "sys" in
    let path = Object.get_attr_s sys "path" in
    let p = files @ Object.to_list Object.to_string path in
    Object.set_attr_s sys "path" (PyList.create (List.map PyUnicode.create p))

let pickle ?kwargs obj =
    let pickle = PyModule.import "pickle" in
    run (pickle $. String "dumps") ?kwargs [Ptr obj]
    |> Object.to_bytes

let unpickle ?kwargs b =
    let pickle = PyModule.import "pickle" in
    run (pickle $. String "loads") ?kwargs [Bytes b]

let print ?kwargs args =
    run (eval "print") args ?kwargs
    |> ignore

(* Avoid the GC collecting the struct as Python does not seem to copy them. *)
let all_methods = ref []
let c_function fn m ~name =
    let pymethod = allocate_n C._Py_method ~count:1 in
    all_methods := pymethod :: !all_methods;
    setf !@ pymethod ml_name name;
    setf !@ pymethod ml_meth fn;
    setf !@ pymethod ml_flags 1;
    setf !@ pymethod ml_doc "doc";
    let name = to_object (String name) in
    wrap (_PyCFunction_New pymethod m name)

module Numpy = struct
    (* Define some type aliases to match the numpy conventions. *)
    let npy_intp = intptr_t
    type npy_intp = Intptr.t

    let shape pyobject =
        Object.to_list Object.to_int (pyobject $. (String "shape"))

    type t = {
        get_version : unit -> Unsigned.uint;
        get_ptr : pyobject -> npy_intp ptr -> unit ptr;
        object_type : pyobject -> int -> int;
        new_array : pyobject -> int -> npy_intp ptr -> int -> npy_intp ptr -> unit ptr -> int -> int -> pyobject -> pyobject;
        array_type : pyobject;
        np : pyobject;
    }

    let is_available () =
        try
            let _ = PyModule.import "numpy" in
            true
        with _ -> false

    let init () =
        let np = PyModule.import "numpy" in
        let np_api =
            np $. String "core" $. String "multiarray" $. String "_ARRAY_API"
        in
        let np_api = Object.capsule_c_pointer np_api None in
        (* See [numpy/__multiarray_api.h] for the offset values. *)
        let ptr_offset ~offset = to_voidp (from_voidp (ptr void) np_api +@ offset) in
        let fn fn_typ ~offset =
            !@ (from_voidp (Foreign.funptr fn_typ) (ptr_offset ~offset))
        in
        let get_version = fn (void @-> returning uint) ~offset:0 in
        let get_ptr =
            fn (pyobject @-> ptr npy_intp @-> returning (ptr void)) ~offset:160
        in
        let object_type = fn (ptr void @-> int @-> returning int) ~offset:54 in
        let array_type = !@(from_voidp (ptr void) (ptr_offset ~offset:2)) in
        let new_array =
            (pyobject @->        (* subtype  *)
                int @->          (* ndims    *)
                ptr npy_intp @-> (* dims     *)
                int @->          (* type_num *)
                ptr npy_intp @-> (* strides  *)
                ptr void @->     (* data     *)
                int @->          (* itemsize *)
                int @->          (* flags    *)
                pyobject @->     (* obj      *)
                returning pyobject)
            |> fn ~offset:93
        in
        { get_version; get_ptr; object_type; new_array; array_type; np }

    let t = lazy (init ())

    let get_version () = (Lazy.force t).get_version () |> Unsigned.UInt.to_int

    let to_bigarray : type a b . pyobject -> (a, b) Bigarray.kind -> (a, b, Bigarray.c_layout) Bigarray.Genarray.t = fun pyobject kind ->
        let t = Lazy.force t in
        if not (Object.to_bool (pyobject $. String "flags" $. String "c_contiguous"))
        then failwith "the input array is not C contiguous";
        let shape = shape pyobject in
        let zeros =
            List.map (fun _ -> Intptr.of_int 0) shape
            |> CArray.of_list npy_intp
            |> CArray.start
        in
        let typeinfo = t.object_type pyobject 0 in
        let typ : a typ =
            (* The typeinfo values come from the NPY_TYPES order in
               numpy/ndarraytypes.h. *)
            match kind, typeinfo with
            | Bigarray.Float32, 11 -> float
            | Bigarray.Float64, 12 -> float
            | Bigarray.Float16, 23 -> float
            | Bigarray.Int8_signed, 1 -> int
            | Bigarray.Int8_unsigned, 2 -> int
            | Bigarray.Int16_signed, 3 -> int
            | Bigarray.Int16_unsigned, 4 -> int
            | Bigarray.Int32, (5 | 7) -> int32_t
            | Bigarray.Int64, 9 -> int64_t
            | Bigarray.Int, _ -> failwith "int is not supported"
            | Bigarray.Nativeint, _ -> failwith "native int is not supported"
            | Bigarray.Complex32, _ -> failwith "complex32 is not supported"
            | Bigarray.Complex64, _ -> failwith "complex64 is not supported"
            | Bigarray.Char, _ -> char
            | _ -> Printf.sprintf "incompatible numpy array type %d" typeinfo |> failwith
        in
        let ptr = t.get_ptr pyobject zeros |> from_voidp typ in
        let bigarray = bigarray_of_ptr Genarray (Array.of_list shape) kind ptr in
        C._Py_IncRef pyobject;
        Gc.finalise (fun _ -> C._Py_DecRef pyobject) bigarray;
        bigarray

    let from_bigarray (type a) (type b) (bigarray : (a, b, Bigarray.c_layout) Bigarray.Genarray.t) =
        let t = Lazy.force t in
        let ndims = Bigarray.Genarray.num_dims bigarray in
        let dims =
            Bigarray.Genarray.dims bigarray
            |> Array.to_list
            |> List.map Intptr.of_int
            |> CArray.of_list npy_intp
            |> CArray.start
        in
        let typeinfo =
            match Bigarray.Genarray.kind bigarray with
            | Bigarray.Float32        -> 11
            | Bigarray.Float64        -> 12
            | Bigarray.Int8_signed    -> 1
            | Bigarray.Int8_unsigned  -> 2
            | Bigarray.Int16_signed   -> 3
            | Bigarray.Int16_unsigned -> 4
            | Bigarray.Int32          -> 5
            | Bigarray.Int64          -> 9
            | Bigarray.Float16        -> 23
            | Bigarray.Int            -> failwith "int is not supported"
            | Bigarray.Nativeint      -> failwith "native int is not supported"
            | Bigarray.Complex32      -> failwith "complex32 is not supported"
            | Bigarray.Complex64      -> failwith "complex64 is not supported"
            | Bigarray.Char           -> failwith "char is not supported"
        in
        let data = bigarray_start Genarray bigarray |> to_voidp in
        let pyobject =
            (* NPY_ARRAY_C_CONTIGUOUS | NPY_ARRAY_ALIGNED | NPY_ARRAY_WRITEABLE *)
            let flag = 0x0001 lor 0x0100 lor 0x0400 in
            t.new_array t.array_type ndims dims typeinfo (from_voidp npy_intp null) data 0 flag null
            |> wrap
        in
        (* Ensure that the bigarray can only be collected after the numpy array. Use
           [Sys.opaque_identity] for this as it cannot be optimized.
        *)
        Gc.finalise (fun _ -> ignore (Sys.opaque_identity bigarray)) pyobject;
        pyobject
end

(* A simple module to wrap OCaml code that can be run from Python. *)
module CamlModule = struct
    type pyvalue = t
    type t = Object.t

    let create name = PyModule.get name

    let add_int = PyModule.add_int
    let add_string = PyModule.add_string
    let add_object t name o = PyModule.add_object t name (to_object o)

    (* In order to avoid the closures being potentially collected by the OCaml GC
       we store them in a global reference. *)
    let fns = ref []

    let add_fn t name fn =
        fns := fn :: !fns;
        let fn _none args =
            try
                fn args |> to_object
            with
            | exn ->
                (* Set an ocaml related exception then return null. *)
                _PyErr_SetString
                    (!@_PyExc_RuntimeError)
                    (Printf.sprintf "ocaml-error: %s" (Printexc.to_string exn));
                null
        in
        PyModule.add_object t name (c_function fn (Object.none ()) ~name)

    (* Wrap ocaml values so that they can be passed through Python and
       used by further OCaml code.
       The values are stored in a capsule. In order to keep the GC happy, we don't
       use a pointer but an identifier related to a hashtable where values are
       stored.
    *)
    let delete_fns = ref []
    let capsule_wrapper () =
        let values = Hashtbl.create 100 in
        let counter = ref 1 in
        let id_from_capsule capsule =
            _PyCapsule_GetPointer capsule (from_voidp char null)
            |> raw_address_of_ptr |> Nativeint.to_int
        in
        let delete_id ptr = Hashtbl.remove values (id_from_capsule ptr) in
        delete_fns := delete_id :: !delete_fns;
        let encapsulate v =
            let id = !counter in
            counter := !counter + 1;
            Hashtbl.add values id v;
            _PyCapsule_New
                (ptr_of_raw_address (Nativeint.of_int id))
                (from_voidp char null)
                delete_id
            |> wrap
        in
        let decapsulate capsule =
            let id = id_from_capsule capsule in
            match Hashtbl.find_opt values id with
            | None ->
                Printf.sprintf "internal error: id %d cannot be found" id |> failwith
            | Some v -> v
        in
        encapsulate, decapsulate
end

let () = initialize ()
