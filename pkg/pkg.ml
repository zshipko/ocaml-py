#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  Pkg.describe "py" @@ fun c ->
  Ok [ Pkg.mllib "src/py.mllib";
       Pkg.test "test/test"; ]
