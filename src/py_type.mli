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

val get : Py_base.pyobject -> t list

val long_subclass : Py_base.pyobject -> bool
val list_subclass : Py_base.pyobject -> bool
val tuple_subclass : Py_base.pyobject -> bool
val bytes_subclass : Py_base.pyobject -> bool
val unicode_subclass : Py_base.pyobject -> bool
val dict_subclass : Py_base.pyobject -> bool
val base_exc_subclass : Py_base.pyobject -> bool
val type_subclass : Py_base.pyobject -> bool

val is_float : Py_base.pyobject -> bool
