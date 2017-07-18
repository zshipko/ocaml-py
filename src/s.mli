type pyobject = unit Ctypes.ptr
val pyobject : pyobject Ctypes.typ

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
        type t = pyobject
        val to_pyobject : t -> pyobject
        val from_pyobject : pyobject -> t
        val is_null : t -> bool
        val is_none : t -> bool
        val incref : t -> unit
        val decref : t -> unit
        val length : t -> int64

        val get_item : t -> t -> t
        val get_item_s : t -> string -> t
        val get_item_i : t -> int -> t
        val del_item : t -> t -> unit
        val del_item_s : t -> string -> unit
        val del_item_i : t -> int -> unit
        val set_item : t -> t -> t -> unit
        val set_item_s : t -> string -> t -> unit
        val set_item_i : t -> int -> t -> unit
        val get_attr : t -> t -> t
        val get_attr_s : t -> string -> t
        val del_attr : t -> t -> unit
        val del_attr_s : t -> string -> unit
        val set_attr : t -> t -> t -> unit
        val set_attr_s : t -> string -> t -> unit
        val has_attr : t -> t -> bool
        val has_attr_s : t -> string -> bool

        val to_string : t -> string
        val to_bytes : t -> bytes
        val to_int : t -> int

        val to_int64 : t -> int64
        val to_float : t -> float
        val to_bool : t -> bool
        val from_bool : bool -> t
        val none : t
        val incref_none : unit -> t
        val compare : t -> t -> op -> bool

        val to_array : (t -> 'a) -> t -> 'a array
        val to_list : (t -> 'a) -> t -> 'a list

        val contains : t -> t -> bool
        val concat : t -> t -> t
    end

    val wrap : pyobject -> Object.t
    val wrap_status : int -> unit

    module PyNumber : sig
        val create_float : float -> Object.t
        val create_int : int -> Object.t
        val create_int64 : int64 -> Object.t
        val add : Object.t -> Object.t -> Object.t
        val sub : Object.t -> Object.t -> Object.t
        val mul : Object.t -> Object.t -> Object.t
        val matmul : Object.t -> Object.t -> Object.t
        val div : Object.t -> Object.t -> Object.t
        val floor_div : Object.t -> Object.t -> Object.t
        val rem : Object.t -> Object.t -> Object.t
        val divmod : Object.t -> Object.t -> Object.t
        val neg : Object.t -> Object.t
        val pos : Object.t -> Object.t
        val abs : Object.t -> Object.t
        val invert : Object.t -> Object.t
        val power : Object.t -> Object.t -> Object.t
        val lshift : Object.t -> Object.t -> Object.t
        val rshift : Object.t -> Object.t -> Object.t
        val band : Object.t -> Object.t -> Object.t
        val bor : Object.t -> Object.t -> Object.t
        val bxor : Object.t -> Object.t -> Object.t
        val add_inplace : Object.t -> Object.t -> Object.t
        val sub_inplace : Object.t -> Object.t -> Object.t
        val mul_inplace : Object.t -> Object.t -> Object.t
        val matmul_inplace : Object.t -> Object.t -> Object.t
        val div_inplace : Object.t -> Object.t -> Object.t
        val floor_div_inplace : Object.t -> Object.t -> Object.t
        val rem_inplace : Object.t -> Object.t -> Object.t
        val power_inplace : Object.t -> Object.t -> Object.t
        val lshift_inplace : Object.t -> Object.t -> Object.t
        val rshift_inplace : Object.t -> Object.t -> Object.t
        val band_inplace : Object.t -> Object.t -> Object.t
        val bor_inplace : Object.t -> Object.t -> Object.t
        val bxor_inplace : Object.t -> Object.t -> Object.t
    end

    module PyIter : sig
        type t
        val get : Object.t -> t
        val next : t -> Object.t
        val map : (Object.t -> 'a) -> t -> 'a list
    end

    module PyDict : sig
        val create : (Object.t * Object.t) list -> Object.t
        val dict_items : Object.t -> Object.t
        val dict_keys : Object.t -> Object.t
        val dict_values : Object.t -> Object.t
        val items : (Object.t -> 'a) -> (Object.t -> 'b) -> Object.t -> ('a * 'b) list
        val keys : (Object.t -> 'a) -> Object.t -> 'a list
        val contains : Object.t -> Object.t -> bool
        val copy : Object.t -> Object.t
        val merge : Object.t -> Object.t -> bool -> unit
    end

    module PyList : sig
        val create : Object.t list -> Object.t
        val insert : Object.t -> int64 -> Object.t -> unit
        val append : Object.t -> Object.t -> unit
        val get_slice : Object.t -> int64 -> int64 -> Object.t
        val set_slice : Object.t -> int64 -> int64 -> Object.t -> unit
        val sort : Object.t -> unit
        val rev : Object.t -> unit
        val tuple : Object.t -> Object.t
    end

    module PySet : sig
        val create : Object.t -> Object.t
    end

    module PyTuple : sig
        val create : Object.t array -> Object.t
    end

    module PySlice : sig
        val create : Object.t -> Object.t -> Object.t -> Object.t
    end

    val get_module_dict : unit -> Object.t

    module PyModule : sig
        val import : string -> Object.t
        val set : string -> Object.t -> unit
        val get : string -> Object.t
        val get_dict : string -> Object.t
        val reload : Object.t -> Object.t
        val main : unit -> Object.t
    end

    module PyCell : sig
        val create : Object.t -> Object.t
        val get : Object.t -> Object.t
        val set : Object.t -> Object.t -> unit
    end

    module PyWeakref : sig
        val new_ref : ?callback:Object.t -> Object.t -> Object.t
        val new_proxy : ?callback:Object.t -> Object.t -> Object.t
        val get_object : Object.t -> Object.t
    end

    module PyThreadState : sig
        type t
        val save : unit -> t
        val restore : t -> unit
        val get : unit -> t
        val swap : t -> t
        val clear : t -> unit
        val delete : t -> unit
        val get_dict : t -> Object.t
    end

    val new_interpreter : unit -> PyThreadState.t
    val end_interpreter : PyThreadState.t -> unit


    module PyBytes : sig
        val create : Bytes.t -> Object.t
    end

    module PyUnicode : sig
        val create : string -> Object.t
    end

    module PyBuffer : sig
        type b
        type t = {
            buf : b;
            data : char Ctypes.CArray.t;
        }
        val create : ?readonly:bool -> Object.t -> t
        val get : t -> int -> char
        val set : t -> int -> char -> unit
        val length : t -> int
        val shape : t -> int64 array
        val strides : t -> int64 array
        val ndim : t -> int
    end

    module PyByteArray : sig
        val from_list : char list -> Object.t
        val create : Object.t -> Object.t
        val get : Object.t -> int -> char
        val set : Object.t -> int -> char -> unit
        val length : Object.t -> int
        val get_string : Object.t -> string
    end

    type t =
        | Py of Object.t
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

    val to_object : t -> Object.t

    val initialize : ?initsigs:bool -> unit -> unit
    val finalize : unit -> unit

    (** Execute a string for side-effects only *)
    val exec : string -> bool

    val locals : unit -> Object.t option
    val globals : unit -> Object.t option
    val builtins : unit -> Object.t

    (** Evaluate a string and return the response *)
    val eval : ?globals:t -> ?locals:t -> string -> Object.t

    val none : unit -> Object.t

    (** Call a Python Object *)
    val call : ?args:Object.t -> ?kwargs:Object.t -> Object.t -> Object.t

    val run : Object.t -> ?kwargs:(t * t) list -> t list -> Object.t

    val ( !$ ) : t -> Object.t
    val ( $ ) : Object.t -> t list -> Object.t
    val ( $. ) : Object.t -> t -> Object.t
    val ( <-$. ) : (Object.t * t) -> t -> unit
    val ( $-> ) : Object.t -> t -> Object.t
    val ( <-$ ) : (Object.t * t) -> t -> unit
    val append_path : string list -> unit
    val pickle : Object.t -> bytes
    val unpickle : bytes -> Object.t
    val print : ?kwargs:(t * t) list -> t list -> unit
end


