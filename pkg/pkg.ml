#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
    Pkg.describe "py" @@ fun c ->
        Ok [
            Pkg.mllib ~api:["Py"] "src/py.mllib";
            Pkg.test ~dir:"test" "test/py_test";
        ]
