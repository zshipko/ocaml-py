let fn args =
  let v = match Py.Object.to_list Py.Object.to_int args with
  | [v] -> v
  | _ -> assert false in
  Py.List [ Int (v + 1337); String "hello from ocaml!" ]

let () =
  let m = Py.CamlModule.create "testmod" in
  Py.CamlModule.add_int m "foobar" 42;
  Py.CamlModule.add_string m "pi" "3.14159265358979";
  Py.CamlModule.add_object m "e" (List [String "e ="; Float 2.71828182846]);
  Py.CamlModule.add_fn m "fn" fn
