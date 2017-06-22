(*---------------------------------------------------------------------------
   Copyright (c) 2017 Zach Shipko. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

(** OCaml interface to Python

    {e %%VERSION%% — {{:%%PKG_HOMEPAGE%% }homepage}} *)

(** {1 Py} *)

type pyobject = unit Ctypes.ptr
val pyobject : pyobject Ctypes.typ

module type VERSION = sig
    val lib : string
end

(** The op type is used specifically for calls to Python.compare *)
type op =
    | LT
    | LE
    | EQ
    | NE
    | GT
    | GE

exception Invalid_type
exception Invalid_object
exception Python_error of string
exception End_iteration

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

        val contains : t -> t -> bool
        val concat : t -> t -> t
        val add : t -> t -> t
        val sub : t -> t -> t
        val mul : t -> t -> t
        val div : t -> t -> t
        val floor_div : t -> t -> t
        val rem : t -> t -> t
        val divmod : t -> t -> t
        val neg : t -> t
        val pos : t -> t
        val abs : t -> t
        val invert : t -> t
    end

    val wrap : pyobject -> Object.t
    val wrap_status : int -> unit

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

    val get_module_dict : unit -> Object.t

    module PyModule : sig
        val set : string -> Object.t -> unit
        val get : string -> Object.t
        val get_dict : string -> Object.t
        val reload : Object.t -> Object.t
    end

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
            readonly : bool;
        }
        val from_object : ?readonly:bool -> Object.t -> t
        val get : t -> int -> char
        val set : t -> int -> char -> unit
        val length : t -> int
    end

    module PyByteArray : sig
        val from_list : char list -> Object.t
        val from_object : Object.t -> Object.t
        val get : Object.t -> int -> char
        val set : Object.t -> int -> char -> unit
        val length : Object.t -> int
        val from_object : Object.t -> Object.t
        val get_string : Object.t -> string
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

module Make(V : VERSION) : PYTHON

(*---------------------------------------------------------------------------
   Copyright (c) 2017 Zach Shipko

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
