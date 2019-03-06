open Py

let py_test_int t =
    Test.check t "Python int to OCaml int" (fun () -> !$(Int 99999) |> Object.to_int) 99999;
    Test.check t "Python int to OCaml string" (fun () -> !$(Int 123) |> Object.to_string) "123"

let py_test_string t =
    Test.check t "Python string to OCaml string" (fun () -> !$(String "testing abc 123") |> Object.to_string) "testing abc 123"

let py_test_list t =
    let l = !$(List [Int 1; Int 2; Int 3]) in
    let l' =  Object.to_list Object.to_int l in
    List.iteri (fun i x ->
        Test.check t "Python check list" (fun () -> x) (i + 1)) l'

let py_test_tuple t =
    let l = !$(Tuple [| Int 1; Int 2; Int 3 |]) in
    let l' = Object.to_list Object.to_int l in
    List.iteri (fun i x ->
        Test.check t "Python check tuple" (fun () -> x) (i + 1)) l'

let py_test_dict_data = [| "a"; "b"; "c" |]

let py_test_dict t =
    let d = !$(Dict [
        String "a", Int 1;
        String "b", Int 2;
        String "c", Int 3;
    ]) in
    let d' = PyDict.items Object.to_string Object.to_int d in
    let d' = List.sort (fun (_k, v) (_k', v') -> compare v v') d' in
    List.iteri (fun i (k, v) ->
        Test.check t
        "Python check dict"
        (fun () -> k, v)
        (py_test_dict_data.(i), i + 1)) d'

let py_test_getitem_dict t =
    let d = !$(Dict [
        String "a", Int 1;
        String "b", Int 2;
        String "b", Int 3; (* Notice b was set twice *)
    ]) in
    Test.check t "Getitem a" (fun () -> Object.get_item_s d "a" |> Object.to_int) 1;
    Test.check t "Getitem b" (fun () -> Object.get_item d (PyUnicode.create "b") |> Object.to_int) 3

let py_test_type t =
    List.iter
        (fun (name, py, expected_type) ->
            let pyobject = !$ py in
            let type_name =
              match PyType.type_name pyobject with
              | None -> assert false
              | Some type_name -> type_name
            in
            Test.check t ("Type " ^ name) (fun () -> type_name) name;
            Test.check t ("Type " ^ name) (fun () -> PyType.get pyobject) expected_type)
        [
            "str", String "foobar", [Unicode];
            "int", Int 42, [Long];
            "dict", Dict [String "key", Int 42], [Dict];
            "tuple", Tuple [|String "alpha"; Int 42|], [Tuple];
            "list", List [String "alpha"; Int 42], [List];
            "float", Float 3.14159265359, [Float];
            "NoneType", Nil, [None];
        ]

let sort_keys = function
  | Dict l ->
      Dict (List.sort (fun (k, _) (k', _) ->
        match (k, k') with
        | String a, String b -> String.compare a b
        | Int a, String b -> String.compare (string_of_int a) b
        | String a, Int b -> String.compare a (string_of_int b)
        | _, _ -> -1) l)
  | x -> x

let py_test_of_object t =
    List.iteri
        (fun i py ->
            let py' = !$ py |> of_object in
            Test.check t ("of_object " ^ string_of_int i) (fun () -> sort_keys py) (sort_keys py'))
        [
            String "foobar";
            Int 42;
            Dict [Int 1337, Float 3.1415; String "key", Int 42];
            List [Tuple [|Int 2; Int 7; Int 1; Float 828.|]; String "test"; Nil];
        ]


let py_test_iter t =
    let l = !$(List [
        Int 1;
        Int 2;
        Int 3;
    ]) in
    let i = PyIter.get l in
    let o = PyIter.next i in
    let _ = Test.check t "Python check iter 1" (fun () -> Object.to_int o) 1 in
    let o = PyIter.next i in
    let _ = Test.check t "Python check iter 2" (fun () -> Object.to_int o) 2 in
    let o = PyIter.next i in
    let _ = Test.check t "Python check iter 3" (fun () -> Object.to_int o) 3 in
    Test.check_raise t "Python check iter end" (fun () -> PyIter.next i)

let py_test_call t =
    let python_list = PyList.create [] in
    let result =
        Object.call_method python_list "append" ~args:[| to_object (Int 42) |]
    in
    assert Object.(is_none result);
    let result =
        Object.call_method python_list "append" ~args:[| to_object (String "foo") |]
    in
    assert Object.(is_none result);
    let len =
        Object.(call (get_item_s (builtins ()) "len") ~args:[| python_list |])
        |> Object.to_int
    in
    Test.check t "Python check call" (fun () -> len) 2

let py_test_buffer t =
    let a = ['a'; 'b'; 'c'; 'd'; 'e'; 'f'; 'g'] in
    let b = PyByteArray.from_list a in
    let _ = PyByteArray.set b 0 'z' in
    let c = PyBuffer.create ~readonly:false b in
    let _ = PyBuffer.set c 1 'y' in
    Test.check t "Python check byte array" (fun () -> PyByteArray.get_string b) "zycdefg"

let py_test_wrap t =
    let sum_fn = Object.get_item_s (builtins ()) "sum" in
    let sum = PyWrap.(python_fn (list int @-> returning int) sum_fn) in
    let v = sum [1; 2; 3; 4], sum [1; 2; 3; 4; 5; 6] in
    Test.check t "Wrap python fn" (fun () -> v) (10, 21);

    (* Python runtime errors are converted to ocaml exceptions. *)
    let sum = PyWrap.(python_fn (list string @-> returning int) sum_fn) in
    let failed_at_runtime =
      try
        let _v = sum ["ab"; "cd"] in
        false
      with _ -> true
    in
    Test.check t "Wrap python fn exn 1" (fun () -> failed_at_runtime) true;

    (* Wrapping with an incorrect type will result in a runtime error. *)
    let sum = PyWrap.(python_fn (list int @-> returning (tuple2 int int)) sum_fn) in
    let failed_at_runtime =
      try
        let _v = sum [0; 1] in
        false
      with _ -> true
    in
    Test.check t "Wrap python fn exn 2" (fun () -> failed_at_runtime) true;

    let sum_pow l k =
      List.fold_left (fun acc x -> acc +. x ** (float k)) 0. l
    in
    let sum_pow = PyWrap.(ocaml_fn (list float @-> int @-> returning float) sum_pow) in
    (* For this test we call sum_pow from ocaml directly, it would be interesting
       to add this function to a module and call it python. *)
    let v =
      let rec loop acc v =
        if v = 0 then acc else loop (Int v :: acc) (v - 1)
      in
      let args = to_object (Tuple [| List (loop [] 100); Int (-2) |]) in
      sum_pow args
      |> Object.to_float
    in
    Test.check t "Wrap ocaml fn" (fun () -> int_of_float (1e6 *. v)) 1634983

let py_test_thread_state t =
    let a0 = PyThreadState.get () in
    let _ = exec "a = 10" in
    let a1 = new_interpreter () in
    let _ = PyThreadState.swap a1 in
    let _ = exec "a = 5" in
    let _ = Test.check t "New thread state" (fun () -> eval "a" |> Object.to_int) 5 in
    let _ = PyThreadState.swap a0 in
    Test.check t "Old thread state" (fun () -> eval "a" |> Object.to_int) 10;
    let a1 = new_interpreter () in
    end_interpreter a1;
    let _ = PyThreadState.swap a0 in
    ()

let py_test_gc t =
    List.iter (fun to_python_fn ->
        let array = Array.init 1000 (fun i -> i * i) in
        let tuple = !$(to_python_fn (Array.map (fun i -> Int i) array)) in
        Gc.full_major ();
        let array' = Object.to_array Object.to_int tuple in
        Test.check t "Python gc test" (fun () -> array) array')
        [(fun x -> Tuple x); (fun x -> List (Array.to_list x))]

let py_test_numpy t =
    if Numpy.is_available ()
    then (
        let np = PyModule.import "numpy" in
        (* This should be 0x01000009 for numpy 1.12.1. *)
        let version = Numpy.get_version () in
        Test.check t "numpy version test" (fun () -> version > 0) true;
        let zeros = np $. String "zeros" $ [ Int 5 ] in
        let bigarray = Numpy.to_bigarray zeros Float64 in
        (* The numpy array and the bigarray share memory so modifying the
           bigarray also changes the numpy array.
        *)
        Bigarray.Genarray.set bigarray [| 1 |] 0.25;
        Bigarray.Genarray.set bigarray [| 4 |] 0.5;
        let sum = zeros $. String "sum" $ [] in
        Test.check t "numpy to bigarray" (fun () -> Object.to_float sum) 0.75;
        let bigarray =
            Bigarray.Array2.of_array Float32 C_layout
                [| [| 3.; 1.; 4.; 1. |]; [| 1.; 5.; 9.; 2. |] |]
            |> Bigarray.genarray_of_array2
        in
        let na = Numpy.from_bigarray bigarray in
        Test.check t "bigarray to numpy" (fun () -> Numpy.shape na)
            (Bigarray.Genarray.dims bigarray |> Array.to_list);
        let sum = na $. String "sum" $ [] in
        Test.check t "bigarray to numpy 2" (fun () -> Object.to_float sum) 26.;
        let _ = na $. String "fill" $ [ Float 3.14 ] in
        Test.check t "bigarray to numpy 3"
            (fun () -> (Bigarray.Genarray.get bigarray [| 1; 1 |] -. 3.14) < 1e-6) true
    )

let py_test_errors t =
    let v = Py.to_object (Int (-1)) |> Py.Object.to_int in
    Test.check t "error can return -1" (fun () -> v) (-1);
    let ok =
        try
            let _ = Py.to_object (String "aa") |> Py.Object.to_int in
            false
        with _ -> true
    in
    Test.check t "error string to int" (fun () -> ok) true

let simple = [
    py_test_int;
    py_test_string;
    py_test_list;
    py_test_tuple;
    py_test_dict;
    py_test_getitem_dict;
    py_test_type;
    py_test_of_object;
    py_test_iter;
    py_test_call;
    py_test_buffer;
    py_test_wrap;
    py_test_thread_state;
    py_test_gc;
    py_test_numpy;
    py_test_errors;
]

let _ =
    let t = Test.start () in
    let () = Test.all t simple in
    Test.finish t

