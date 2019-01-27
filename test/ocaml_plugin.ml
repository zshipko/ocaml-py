let () =
  let m = Py.PyModule.get "testmod" in
  Py.Object.incref m;
  Printf.printf "Created module %s\n%!" (Py.Object.to_string m);

  Py.PyModule.add_int m "foobar" 42;
  Py.PyModule.add_string m "pi" "3.14159265358979";
  let obj = Py.(!$ (List [String "e ="; Float 2.71828182846])) in
  Py.Object.incref obj;
  Py.PyModule.add_object m "e" obj;
  Printf.printf "Attributes set!\n%!";

  at_exit (fun () ->
    Printf.printf "at_exit called\n%!";
    ignore (Sys.opaque_identity m : Py.pyobject))
