let fn args =
  let v =
      match Py.Object.to_list Py.Object.to_int args with
      | [v] -> v
      | _ -> failwith "not the expected format"
  in
  if v = 0
  then failwith "ocaml issue";
  Py.List [ Int (v + 1337); String "hello from ocaml!" ]

type t =
  { mutable value : int }

let () =
  let m = Py.CamlModule.create "testmod" in
  Py.CamlModule.add_int m "foobar" 42;
  Py.CamlModule.add_string m "pi" "3.14159265358979";
  Py.CamlModule.add_object m "e" (List [String "e ="; Float 2.71828182846]);
  Py.CamlModule.add_fn m "fn" fn;

  (* Wrap a simple caml data-structure in a capsule. *)
  let encapsulate, decapsulate = Py.CamlModule.capsule_wrapper () in
  let build _args = Py.Ptr (encapsulate { value = 0 }) in
  let increment args =
      let t = decapsulate (Py.Object.get_item_i args 0) in
      t.value <- t.value + 1;
      Py.Nil
  in
  let get args =
      let t = decapsulate (Py.Object.get_item_i args 0) in
      Py.Int t.value
  in
  Py.CamlModule.add_fn m "build" build;
  Py.CamlModule.add_fn m "increment" increment;
  Py.CamlModule.add_fn m "get" get
