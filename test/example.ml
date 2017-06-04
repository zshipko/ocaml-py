module Python = Py.Make(struct
    let lib = "python3.5"
end)

let _ =
    ignore (Python.eval "import numpy");
    ignore (Python.eval "a = numpy.ndarray([10, 10, 3])");
    let (Some x) = Python.run "a.fill(0); a + 2" in
    print_endline (Python.to_string x)

