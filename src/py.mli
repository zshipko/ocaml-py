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

module Make(V : Version) : sig
    type t

    val to_pyobject : t -> pyobject
    val from_pyobject : pyobject -> t

    module C : sig
        val from : Dl.library
    end

    module Dict : sig
        val create : unit -> t
    end

    val main : unit -> t
    val incref : t -> unit
    val decref : t -> unit

    val initialize : ?initsigs:bool -> unit -> unit
    val finalize : unit -> unit

    val eval : string -> bool
    val run : ?globals:t -> ?locals:t -> string -> t option

    val to_string : t -> string
    val from_string : string -> t

    val to_int : t -> int
    val from_int : int -> t
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
