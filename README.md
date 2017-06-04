py — OCaml interface to Python
-------------------------------------------------------------------------------
%%VERSION%%

py is a lightweight interface for executing Python3 in OCaml using ctypes

py is distributed under the ISC license.

Homepage: https://github.com/zshipko/py

## Installation

py can be installed with `opam`:

    opam install py

If you don't use `opam` consult the [`opam`](opam) file for build
instructions.

## Documentation

The documentation and API reference is generated from the source
interfaces. It can be consulted [online][doc] or via `odig doc
py`.

[doc]: https://github.com/zshipko/py/doc

## Sample programs

If you installed py with `opam` sample programs are located in
the directory `opam var py:doc`.

In the distribution sample programs and tests are located in the
[`test`](test) directory. They can be built and run
with:

    topkg build --tests true && topkg test
