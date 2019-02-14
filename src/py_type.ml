module P = Py_base

let type_name obj =
  let ptr = P.Object.to_c_ptr obj |> Ctypes.from_voidp Init._Py_object in
  if Ctypes.is_null ptr
  then None
  else
    let ob_type = Ctypes.getf (Ctypes.(!@) ptr) Init.ob_type in
    if Ctypes.is_null ob_type
    then None
    else Some (Ctypes.getf (Ctypes.(!@) ob_type) Init.tp_name)

let tp_flags obj =
  let ptr = P.Object.to_c_ptr obj |> Ctypes.from_voidp Init._Py_object in
  if Ctypes.is_null ptr
  then None
  else
    let ob_type = Ctypes.getf (Ctypes.(!@) ptr) Init.ob_type in
    if Ctypes.is_null ob_type
    then None
    else
      let tp_flags = Ctypes.getf (Ctypes.(!@) ob_type) Init.tp_flags in
      Some (Unsigned.ULong.to_int tp_flags)

let has_flag' tp_flags ~flag_id =
  match tp_flags with
  | None -> false
  | Some tp_flags -> (tp_flags land (1 lsl flag_id)) <> 0

let has_flag obj ~flag_id = tp_flags obj |> has_flag' ~flag_id

(* The related cpython constants can be found in:
   https://github.com/python/cpython/blob/master/Include/object.h
*)

let long_subclass = has_flag ~flag_id:24
let list_subclass = has_flag ~flag_id:25
let tuple_subclass = has_flag ~flag_id:26
let bytes_subclass = has_flag ~flag_id:27
let unicode_subclass = has_flag ~flag_id:28
let dict_subclass = has_flag ~flag_id:29
let base_exc_subclass = has_flag ~flag_id:30
let type_subclass = has_flag ~flag_id:31

(* Floats are not handled in the same way as other basic
   types so we compare the object type with the float  object
   type. This will not work for float subclasses.
*)
let is_float obj =
  let ptr = P.Object.to_c_ptr obj |> Ctypes.from_voidp Init._Py_object in
  if Ctypes.is_null ptr
  then false
  else
    let ob_type = Ctypes.getf (Ctypes.(!@) ptr) Init.ob_type in
    Ctypes.ptr_compare ob_type Init._PyFloat_Type = 0

type t =
  | Null
  | None
  | Long
  | List
  | Tuple
  | Bytes
  | Unicode
  | Dict
  | Base_exc
  | Type
  | Float

let get obj =
  if P.Object.is_null obj
  then [ Null ]
  else if P.Object.is_none obj
  then [ None ]
  else
    let tp_flags = tp_flags obj in
    let maybe_add v ~flag_id acc =
      if has_flag' tp_flags ~flag_id
      then v :: acc
      else acc
    in
    (if is_float obj then [ Float ] else [])
    |> maybe_add Long ~flag_id:24
    |> maybe_add List ~flag_id:25
    |> maybe_add Tuple ~flag_id:26
    |> maybe_add Bytes ~flag_id:27
    |> maybe_add Unicode ~flag_id:28
    |> maybe_add Dict ~flag_id:29
    |> maybe_add Base_exc ~flag_id:30
    |> maybe_add Type ~flag_id:31

let rec of_object obj : P.t =
  match get obj with
  | [ Null ] | [ None ] -> Nil
  | [ Float ] -> Float (P.Object.to_float obj)
  | [ Long ] -> Int (P.Object.to_int obj)
  | [ List ] -> List (P.Object.to_list of_object obj)
  | [ Tuple ] -> Tuple (P.Object.to_array of_object obj)
  | [ Bytes ] -> Bytes (P.Object.to_bytes obj)
  | [ Unicode ] -> String (P.Object.to_string obj)
  | [ Dict ] -> Dict (P.PyDict.items of_object of_object obj)
  | _ -> Ptr obj
