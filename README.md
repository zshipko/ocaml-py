py — OCaml interface to Python
-------------------------------------------------------------------------------
%%VERSION%%

py is a ctypes interface to Python 3.5+ for OCaml

py is distributed under the ISC license.

Homepage: https://github.com/zshipko/ocaml-py

## Installation

py can be installed with `opam`:

    opam install py

If you don't use `opam` consult the [`opam`](opam) file for build
instructions.

## Introduction

Simple conversion from OCaml to Python:

    open Py
    let s = !$(String "a string")
    let f = !$(Float 12.3)
    let i = !$(Int 123)

See `src/py.mli` for a full list of types.

Call a function defined in a module and return the result:

    let np = PyModule.import "numpy" in
    let np_array = np $. (String "array") in
    let arr = np_array $ [List [Int 1; Int 2; Int 3]] in
    ...

Which is shorthand for

    let np = PyModule.import "numpy" in
    let np_array = Object.get_attr_s np "array" in
    let arr = run np_array [List [Int 1; Int 2; Int 3]] in
    ...

Evaluate a string and return the result:

    let arr = eval "[1, 2, 3]" in
    ...

Get object index:

    let a = arr $| Int 0 in
    let b = arr $| Int 1 in
    let c = arr $| Int 2 in
    ...

Set object index:

    let _ = (a_list, Int 0) <-$| Int 123 in
    let _ = (a_dict, String "key") <-$| String "value" in
    ...

Execute a string and return true/false depending on the status returned by Python:

    if exec "import tensorflow" then
        let tf = PyModule.get "tensorflow" in  (* Load an existing module *)
        ...

## Sample programs

If you installed py with `opam` sample programs are located in
the directory `opam var py:doc`.

In the distribution sample programs and tests are located in the
[`test`](test) directory. They can be built and run
with:

    topkg build --tests true && topkg test

