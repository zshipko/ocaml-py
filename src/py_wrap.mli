(* This module provides a simple interface to wrap python function calls in
   ocaml and vice-versa.

   [python_fn] wraps a python function and gives it a proper ocaml interface.
   E.g. using the sum function from python can be done via:
     ```
     let sum_fn =
       let sum = Py.Object.get_item_s (builtins ()) "sum" in
       PyWrap.(python_fn (list int @-> returning int) sum)
     ```
   The signature of [sum_fn] will be as expected [int list -> int].

   Conversely ocaml functions can be conveniently wrapped as python functions.
*)

module W : sig
  type 'a t =
    { wrap : 'a -> Py_base.pyobject
    ; unwrap_exn : Py_base.pyobject -> 'a
    ; name : string
    }
end

type 'a t

val returning : 'a W.t -> 'a t
val (@->) : 'a W.t -> 'b t -> ('a -> 'b) t

val none : unit W.t
val bool : bool W.t
val int : int W.t
val float : float W.t
val string : string W.t
val list : 'a W.t -> 'a list W.t
val dict : 'a W.t -> 'b W.t -> ('a * 'b) list W.t

val tuple2 : 'a1 W.t -> 'a2 W.t -> ('a1 * 'a2) W.t
val tuple3 : 'a1 W.t -> 'a2 W.t -> 'a3 W.t -> ('a1 * 'a2 * 'a3) W.t
val tuple4 : 'a1 W.t -> 'a2 W.t -> 'a3 W.t -> 'a4 W.t -> ('a1 * 'a2 * 'a3 * 'a4) W.t
val tuple5 : 'a1 W.t -> 'a2 W.t -> 'a3 W.t -> 'a4 W.t -> 'a5 W.t -> ('a1 * 'a2 * 'a3 * 'a4 * 'a5) W.t

val pyobject : Py_base.pyobject W.t

(** [python_fn t pyobject] wraps a python function [pyobject] so that it can be used
    in a type-safe way.
*)
val python_fn : 'a t -> Py_base.pyobject -> 'a

(** [ocaml_fn t f] wraps an ocaml function [f] so that it can be used from python.
    E.g. it could get registered via [CamlModule.add_fn].
    Note that even if some argument conversion fails, [f] will have been partially
    applied up to this point.
*)
val ocaml_fn : 'a t -> 'a -> Py_base.pyobject -> Py_base.pyobject


val to_string : 'a t -> string
