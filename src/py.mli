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

module type Version = sig
    val lib : string
end

exception Invalid_type
exception Invalid_object

module Make(V : Version) : sig
    module C : sig
        val from : Dl.library
    end

    module Object : sig
        type t
        val to_pyobject : t -> pyobject
        val from_pyobject : pyobject -> t
        val incref : t -> unit
        val decref : t -> unit
        val length : t -> int64
        val unwrap : t option -> t

        val call : ?args:t -> ?kwargs:t -> t -> t
        val get_item : t -> t -> t
        val del_item : t -> t -> unit
        val set_item : t -> t -> t -> unit

        val to_string : t -> string
        val from_string : string -> t
        val to_int : t -> int
        val from_int : int -> t
    end

    module Dict : sig
        val create : unit -> Object.t
    end

    module Tuple : sig
        val create : int -> Object.t
    end

    module Module : sig
        val get : string -> Object.t
        val main : unit -> Object.t
        val main_dict : unit -> Object.t
    end

    val initialize : ?initsigs:bool -> unit -> unit
    val finalize : unit -> unit

    val eval : string -> bool
    val run : ?globals:Object.t -> ?locals:Object.t -> string -> Object.t
end

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
