type pyobject = unit Ctypes.ptr
val pyobject : pyobject Ctypes.typ

module type VERSION = sig
    val lib : string
end

type op =
    | LT
    | LE
    | EQ
    | NE
    | GT
    | GE

module type PYTHON = sig
    module C : sig
        val from : Dl.library
    end

    module Object : sig
        type t
        val to_pyobject : t -> pyobject
        val from_pyobject : pyobject -> t
        val is_null : t -> bool
        val is_none : t -> bool
        val incref : t -> unit
        val decref : t -> unit
        val length : t -> int64
        val create_dict : (t * t) list -> t
        val create_tuple : t array -> t
        val create_list : t list -> t
        val create_set : t -> t

        val get_item : t -> t -> t
        val del_item : t -> t -> unit
        val set_item : t -> t -> t -> unit
        val get_attr : t -> t -> t
        val del_attr : t -> t -> unit
        val set_attr : t -> t -> t -> unit

        val to_string : t -> string
        val from_string : string -> t
        val to_bytes : t -> bytes
        val from_bytes : bytes -> t
        val to_int : t -> int
        val from_int : int -> t
        val to_int64 : t -> int64
        val from_int64 : int64 -> t
        val to_float : t -> float
        val from_float : float -> t
        val to_bool : t -> bool
        val from_bool : bool -> t
        val none : t
        val incref_none : unit -> t
        val compare : t -> t -> op -> bool

        val id : 'a -> 'a
        val array : (t -> 'a) -> t -> 'a array
        val list : (t -> 'a) -> t -> 'a list
        val dict_items : t -> t
        val dict_keys : t -> t
        val dict_values : t -> t
        val items : (t -> 'a) -> (t -> 'b) -> t -> ('a * 'b) list
        val keys : (t -> 'a) -> t -> 'a list
    end

    val wrap : pyobject -> Object.t

    module Module : sig
        val get : string -> Object.t
        val get_dict : string -> Object.t
        val reload : Object.t -> Object.t
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

    val to_object : t -> Object.t

    val initialize : ?initsigs:bool -> unit -> unit
    val finalize : unit -> unit

    (** Execute a string for side-effects only *)
    val exec : string -> bool

    (** Evaluate a string and return the response *)
    val eval : ?globals:Object.t -> ?locals:Object.t -> string -> Object.t

    (** Call a Python Object *)
    val call : ?args:Object.t -> ?kwargs:Object.t -> Object.t -> Object.t

    val run : Object.t -> ?kwargs:Object.t -> t list -> Object.t
    val import : string -> Object.t

    val (!$) : t -> Object.t
    val ($) : Object.t -> t list -> Object.t
    val append_path : string list -> unit
end
