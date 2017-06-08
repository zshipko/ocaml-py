module Python = Py.Make(struct
    let lib = "python3.5"
end)

open Python
open Ctypes

let _ =
    let x = !$(Tuple [| List [Int 1; Int 2; Int 3]; String "abc" |]) in
    let print = eval "print" in
    call ~args:x print

