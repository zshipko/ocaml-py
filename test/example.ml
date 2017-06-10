module Python = Py.Make(struct
    let lib = "python3.5"
end)

open Python

let numpy = import "numpy"
let ndarray = Object.get_attr numpy !$(String "ndarray")

(* Create a numpy array *)
let make_array shape =
    ndarray $ [List (List.map (fun x -> Int x) shape)]

(* Get the shape of a numpy array *)
let shape arr =
    Object.get_attr arr !$(String "shape") |> Object.list Object.to_int


let _ =

    let arr = make_array [100; 100; 3] in
    let size = shape arr in
    print_string "Shape: ";
    List.iter (fun x -> Printf.printf "%d " x) size;
    print_newline ()

