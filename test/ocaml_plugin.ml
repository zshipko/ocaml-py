let () =
  let m = Py.PyModule.get "testmod" in
  Py.Object.incref m;
  Printf.printf "Created module %s\n%!" (Py.Object.to_string m);
  Py.(Object.set_attr_s m "foobar" (!$ Nil));
  Printf.printf "Attribute set!\n%!";
  at_exit (fun () ->
    Printf.printf "at_exit called\n%!";
    ignore (Sys.opaque_identity m : Py.pyobject))
