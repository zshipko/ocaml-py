module P = Py_base

module W = struct
  type 'a t =
    { wrap : 'a -> P.pyobject
    ; unwrap_exn : P.pyobject -> 'a
    ; name : string
    }
end
let un w = w.W.unwrap_exn

type 'a t =
  | Apply : 'a W.t * 'b t -> ('a -> 'b) t
  | Return : 'a W.t -> 'a t

let rec to_string : type a. a t -> string = function
  | Apply (w, t) -> w.W.name ^ " -> " ^ to_string t
  | Return w -> w.W.name

let length t =
  let rec loop : type a. a t -> int -> int = fun t acc ->
    match t with
    | Apply (_, t) -> loop t (acc + 1)
    | Return _ -> acc
  in
  loop t 0

let returning w = Return w
let (@->) w t = Apply (w, t)

let python_fn t pyobject =
  let rec loop : type a. a t -> P.t list -> a = fun t acc_args ->
    match t with
    | Apply (w, t) -> (fun x -> loop t (P.Ptr (w.W.wrap x) :: acc_args))
    | Return w -> un w (P.run pyobject acc_args ?kwargs:None)
  in
  loop t []

let id x = x

let ocaml_fn t fn args =
  (* We should check whether [args] is a tuple and if not the case, put it
     in a singleton array. *)
  let args = P.Object.to_array id args in
  if length t <> Array.length args
  then
    Printf.sprintf "expected %d arguments, got %d" (length t) (Array.length args)
    |> failwith;
  let rec loop : type a. a t -> a -> index:int -> P.pyobject = fun t fn ~index ->
    match t with
    | Apply (w, t) -> loop t (fn (un w args.(index))) ~index:(index + 1)
    | Return w -> w.W.wrap fn
  in
  loop t fn ~index:0

module W_impl = struct
  let none =
    let unwrap_exn pyobject =
      if P.Object.is_none pyobject
      then ()
      else failwith "not none"
    in
    { W.wrap = P.Object.none
    ; unwrap_exn
    ; name = "unit"
    }

  let bool =
    { W.wrap = P.Object.from_bool
    ; unwrap_exn = P.Object.to_bool
    ; name = "bool"
    }

  let int =
    { W.wrap = P.PyNumber.create_int
    ; unwrap_exn = P.Object.to_int
    ; name = "int"
    }

  let float =
    { W.wrap = P.PyNumber.create_float
    ; unwrap_exn = P.Object.to_float
    ; name = "float"
    }

  let string =
    { W.wrap = P.PyUnicode.create
    ; unwrap_exn = P.Object.to_string
    ; name = "float"
    }

  let pyobject = { W.wrap = id; unwrap_exn = id; name = "pyobject" }

  let list w =
    let wrap l = P.PyList.create (List.map w.W.wrap l) in
    let unwrap_exn = P.Object.to_list (un w) in
    { W.wrap; unwrap_exn; name = Printf.sprintf "list[%s]" w.W.name }

  let to_array = P.Object.to_array (fun x -> x)

  let tuple2 w1 w2 =
    let wrap (x1, x2) = P.PyTuple.create [| w1.W.wrap x1; w2.W.wrap x2 |] in
    let unwrap_exn o =
      match to_array o with
      | [| o1; o2 |] -> un w1 o1, un w2 o2
      | _ -> failwith "not a tuple2"
    in
    let name = Printf.sprintf "(%s, %s)" w1.W.name w2.W.name in
    { W.wrap; unwrap_exn; name }

  let tuple3 w1 w2 w3 =
    let wrap (x1, x2, x3) =
      P.PyTuple.create [| w1.W.wrap x1; w2.W.wrap x2; w3.W.wrap x3 |]
    in
    let unwrap_exn o =
      match to_array o with
      | [| o1; o2; o3 |] -> un w1 o1, un w2 o2, un w3 o3
      | _ -> failwith "not a tuple3"
    in
    let name = Printf.sprintf "(%s, %s, %s)" w1.W.name w2.W.name w3.W.name in
    { W.wrap; unwrap_exn; name }

  let tuple4 w1 w2 w3 w4 =
    let wrap (x1, x2, x3, x4) =
      P.PyTuple.create [| w1.W.wrap x1; w2.W.wrap x2; w3.W.wrap x3; w4.W.wrap x4 |]
    in
    let unwrap_exn o =
      match to_array o with
      | [| o1; o2; o3; o4 |] -> un w1 o1, un w2 o2, un w3 o3, un w4 o4
      | _ -> failwith "not a tuple4"
    in
    let name = Printf.sprintf "(%s, %s, %s, %s)" w1.W.name w2.W.name w3.W.name w4.W.name in
    { W.wrap; unwrap_exn; name }

  let tuple5 w1 w2 w3 w4 w5 =
    let wrap (x1, x2, x3, x4, x5) =
      P.PyTuple.create
        [| w1.W.wrap x1; w2.W.wrap x2; w3.W.wrap x3; w4.W.wrap x4; w5.W.wrap x5 |]
    in
    let unwrap_exn o =
      match to_array o with
      | [| o1; o2; o3; o4; o5 |] -> un w1 o1, un w2 o2, un w3 o3, un w4 o4, un w5 o5
      | _ -> failwith "not a tuple5"
    in
    let name =
      Printf.sprintf "(%s, %s, %s, %s %s)" w1.W.name w2.W.name w3.W.name w4.W.name w5.W.name
    in
    { W.wrap; unwrap_exn; name }

  let dict w_key w_value =
    let wrap l =
      List.map (fun (k, v) -> w_key.W.wrap k, w_value.W.wrap v) l |> P.PyDict.create
    in
    let unwrap_exn = P.PyDict.items (un w_key) (un w_value) in
    let name = Printf.sprintf "dict[%s: %s]" w_key.W.name w_value.W.name in
    { W.wrap; unwrap_exn; name }
end

include W_impl
